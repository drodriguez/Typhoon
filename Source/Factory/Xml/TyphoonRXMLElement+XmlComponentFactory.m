////////////////////////////////////////////////////////////////////////////////
//
//  TYPHOON FRAMEWORK
//  Copyright 2013, Jasper Blues & Contributors
//  All Rights Reserved.
//
//  NOTICE: The authors permit you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////



#import "TyphoonLinkerCategoryBugFix.h"

TYPHOON_LINK_CATEGORY(TyphoonRXMLElement_XmlComponentFactory)

#import "TyphoonRXMLElement+XmlComponentFactory.h"
#import "TyphoonMethod.h"
#import "TyphoonDefinition+InstanceBuilder.h"
#import "TyphoonDefinition+Infrastructure.h"
#import "TyphoonBundleResource.h"
#import "TyphoonReferenceDefinition.h"
#import "TyphoonInjections.h"
#import "TyphoonInjectionByCollection.h"

@interface TyphoonMethod (Private)
- (void)injectParameterAtIndex:(NSUInteger)index with:(id)injection;
@end

@implementation TyphoonRXMLElement (XmlComponentFactory)

- (BOOL)isComponent
{
    return [[self tag] isEqualToString:@"component"] || [self isShorthandComponentTag];
}

- (TyphoonDefinition *)asComponentDefinition
{
    if ([self isShorthandComponentTag]) {
        return [self definitionByEvaluatingShorthandComponentTag];
    }
    else {
        [self assertTagName:@"component"];
        Class clazz = NSClassFromString([self attribute:@"class"]);
        if (clazz == nil) {
            [NSException raise:NSInvalidArgumentException format:@"Class '%@' can't be resolved.", [self attribute:@"class"]];
        }

        NSString *key = [self attribute:@"key"];
        NSString *factory = [self attributeOrNilIfEmpty:@"factory-component"];
        TyphoonScope scope = [self scopeForStringValue:[[self attribute:@"scope"] lowercaseString]];
        BOOL isLazy = (scope == TyphoonScopeSingleton) && [self attributeAsBool:@"lazy-init"];


        TyphoonDefinition *definition = [[TyphoonDefinition alloc] initWithClass:clazz key:key factoryComponent:factory];
        [definition setBeforePropertyInjection:NSSelectorFromString([self attribute:@"before-property-injection"])];
        [definition setAfterPropertyInjection:NSSelectorFromString([self attribute:@"after-property-injection"])];
        [definition setLazy:isLazy];
        [definition setScope:scope];
        NSString *parentRef = [self attributeOrNilIfEmpty:@"parent"];
        if (parentRef) {
            [definition setParent:[TyphoonReferenceDefinition definitionReferringToComponent:parentRef]];
        }
        [self parseComponentDefinitionChildren:definition];
        return definition;
    }
}

//TODO: Method too long, clean it up.
- (id <TyphoonPropertyInjection>)asInjectedProperty
{
    [self assertTagName:@"property"];

    NSString *propertyName = [self attribute:@"name"];
    NSString *referenceName = [self attribute:@"ref"];
    NSString *value = [self attribute:@"value"];

    TyphoonRXMLElement *collection = [self child:@"collection"];
    if ((referenceName || value) && collection) {
        [NSException raise:NSInvalidArgumentException format:@"'ref' and 'value' attributes cannot be used with 'collection'"];
    }

    TyphoonAbstractInjection *injectedProperty = nil;
    if (referenceName && value) {
        [NSException raise:NSInvalidArgumentException format:@"Ambigous - both reference and value attributes are set. Can only be one."];
    }
    else if (referenceName && [referenceName length] == 0) {
        [NSException raise:NSInvalidArgumentException format:@"Reference cannot be empty."];
    }

    else if ([referenceName length] > 0) {
        injectedProperty = TyphoonInjectionWithReference(referenceName);
    }
    else if (value) {
        injectedProperty = TyphoonInjectionWithObjectFromString(value);
    }
    else if (collection) {

        NSMutableArray *collectionArray = [[NSMutableArray alloc] init];

        [collection iterate:@"*" usingBlock:^(TyphoonRXMLElement *child) {
            if ([[child tag] isEqualToString:@"ref"]) {
                [collectionArray addObject:TyphoonInjectionWithReference([child text])];
            }
            else if ([[child tag] isEqualToString:@"value"]) {
                [collectionArray addObject:TyphoonInjectionWithObjectFromString([child text])];
            }
        }];

        injectedProperty = TyphoonInjectionWithCollectionAndType(collectionArray, nil);
    }
    else {
        injectedProperty = TyphoonInjectionMatchedByType();
    }

    [injectedProperty setPropertyName:propertyName];

    return injectedProperty;
}


- (TyphoonMethod *)asInitializer
{
    [self assertTagName:@"initializer"];
    SEL selector = NSSelectorFromString([self attribute:@"selector"]);
    TyphoonMethod *initializer = [[TyphoonMethod alloc] initWithSelector:selector];

    [self iterate:@"*" usingBlock:^(TyphoonRXMLElement *child) {
        if ([[child tag] isEqualToString:@"argument"]) {
            [self setArgumentOnInitializer:initializer withChildTag:child];
        }
        else if ([[child tag] isEqualToString:@"description"]) {
            //do nothing.
        }
        else {
            [NSException raise:NSInvalidArgumentException format:@"The tag '%@' can't be used as part of an initializer.", [child tag]];
        }
    }];
    return initializer;
}

/* ====================================================================================================================================== */
#pragma mark - Private Methods

- (BOOL)isShorthandComponentTag
{
    return [[self tag] isEqualToString:@"property-placeholder"];
}

- (TyphoonDefinition *)definitionByEvaluatingShorthandComponentTag
{
    TyphoonDefinition *definition = nil;

    if ([[self tag] isEqualToString:@"property-placeholder"]) {
        NSString *location = [self attribute:@"location"];
        if (location == nil) {
            [NSException raise:NSInvalidArgumentException format:@"%@ is missing 'location' attribute.", [self tag]];
        }

        NSArray *locations = [location componentsSeparatedByString:@","];
        NSMutableArray *resources = [[NSMutableArray alloc] initWithCapacity:[locations count]];
        for (NSString *location in locations) {
            NSString *trimmedLocation = [location stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            [resources addObject:[TyphoonBundleResource withName:trimmedLocation]];
        }

        definition = [TyphoonDefinition propertyPlaceholderWithResources:resources];
    }

    return definition;
}

- (void)assertTagName:(NSString *)tagName
{
    if (![self.tag isEqualToString:tagName]) {
        [NSException raise:NSInvalidArgumentException format:@"Element is not a '%@'.", tagName];
    }
}

- (TyphoonScope)scopeForStringValue:(NSString *)scope
{
    NSArray *acceptedScopes = @[
        @"default",
        @"prototype",
        @"singleton",
        @"weakSingleton"
    ];
    if (([scope length] > 0) && (![acceptedScopes containsObject:scope])) {
        [NSException raise:NSInvalidArgumentException format:@"Scope was '%@', but can only be one of ['default', 'prototype', 'singleton'",
                                                             scope];
    }

    // Here, we don't follow the Spring's implementation : the "default" scope is the TyphoonScopeObjectGraph.
    TyphoonScope result = TyphoonScopeObjectGraph;
    if ([scope isEqualToString:@"singleton"]) {
        result = TyphoonScopeSingleton;
    }
    else if ([scope isEqualToString:@"prototype"]) {
        result = TyphoonScopePrototype;
    }
    else if ([scope isEqualToString:@"weakSingleton"]) {
        result = TyphoonScopeWeakSingleton;
    }

    return result;
}


- (void)parseComponentDefinitionChildren:(TyphoonDefinition *)componentDefinition
{
    [self iterate:@"*" usingBlock:^(TyphoonRXMLElement *child) {
        if ([[child tag] isEqualToString:@"property"]) {
            [componentDefinition addInjectedProperty:[child asInjectedProperty]];
        }
        else if ([[child tag] isEqualToString:@"initializer"]) {
            [componentDefinition setInitializer:[child asInitializer]];
        }
        else if ([[child tag] isEqualToString:@"description"]) {
            // do nothing
        }
        else {
            [NSException raise:NSInvalidArgumentException format:@"The tag '%@' can't be used as part of a component definition.",
                                                                 [child tag]];
        }
    }];
}

- (void)setArgumentOnInitializer:(TyphoonMethod *)initializer withChildTag:(TyphoonRXMLElement *)child
{
    NSString *name = [child attribute:@"parameterName"];
    NSString *index = [child attribute:@"index"];

    if (name && index) {
        [NSException raise:NSInvalidArgumentException format:@"'parameterName' and 'index' cannot be used together"];
    }

    NSString *reference = [child attribute:@"ref"];
    NSString *value = [child attribute:@"value"];
    TyphoonRXMLElement *collection = [child child:@"collection"];

    if (collection && (reference || value)) {
        [NSException raise:NSInvalidArgumentException format:@"'ref' or 'value' cannot be used on collections."];
    }

    if (reference) {
        if (name) {
            [initializer injectParameter:name with:TyphoonInjectionWithReference(reference)];
        }
        else if (index) {
            [initializer injectParameterAtIndex:[index integerValue] with:TyphoonInjectionWithReference(reference)];
        }

        // TODO: should raise an exception if no name or index specified. is NOT implicit with XML. but it should be - you should not need to specify.

    }
    else if (value) {

        if (name) {
            [initializer injectParameter:name with:TyphoonInjectionWithObjectFromString(value)];
        }
        else if (index) {
            [initializer injectParameterAtIndex:[index integerValue] with:TyphoonInjectionWithObjectFromString(value)];
        }

        // TODO: should raise exception instead of silently failing

    }
    else if (collection) {

        NSString *classAsString = [collection attribute:@"requiredType"];
        Class clazz;
        if (classAsString) {
            clazz = NSClassFromString(classAsString);
            if (clazz == nil) {
                [NSException raise:NSInvalidArgumentException format:@"Class '%@' could not be resolved.", classAsString];
            }
        }
        else {
            [NSException raise:NSInvalidArgumentException format:@"'requiredType' is missing for collection initializer argument."];
        }

        NSMutableArray *collectionArray = [[NSMutableArray alloc] init];

        [collection iterate:@"*" usingBlock:^(TyphoonRXMLElement *child) {
            if ([[child tag] isEqualToString:@"ref"]) {
                [collectionArray addObject:TyphoonInjectionWithReference([child text])];
            }
            else if ([[child tag] isEqualToString:@"value"]) {
                [collectionArray addObject:TyphoonInjectionWithObjectFromString([child text])];
            }
        }];

        id <TyphoonParameterInjection> collectionInjection = TyphoonInjectionWithCollectionAndType(collectionArray, clazz);

        if (name) {
            [initializer injectParameter:name with:collectionInjection];
        }
        else if (index) {
            [initializer injectParameterAtIndex:[index integerValue] with:collectionInjection];
        }
    }
}

- (NSString *)attributeOrNilIfEmpty:(NSString *)attributeName
{
    NSString *attribute = [self attribute:attributeName];
    if ([attribute length] > 0) {
        return attribute;
    }
    return nil;
}

@end
