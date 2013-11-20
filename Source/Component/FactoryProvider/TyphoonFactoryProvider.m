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

#import "TyphoonFactoryProvider.h"

#import <objc/runtime.h>

#import "TyphoonAssistedFactoryBase.h"
#import "TyphoonAssistedFactoryMethodCreator.h"

@implementation TyphoonFactoryProvider

static dispatch_queue_t sQueue;

static NSString *GetFactoryClassName(Protocol *protocol)
{
    return [NSString stringWithFormat:@"%s__TyphoonAssistedFactoryImpl",
            protocol_getName(protocol)];
}

static void AssertValidProtocolForFactory(Protocol *protocol, TyphoonAssistedFactoryDefinition *factoryDefinition)
{
    unsigned int methodCount = 0;
    unsigned int propertiesCount = 0;

    struct objc_method_description *methodDescriptions = protocol_copyMethodDescriptionList(protocol, YES, YES, &methodCount);
    objc_property_t *properties = protocol_copyPropertyList(protocol, &propertiesCount);
    free(methodDescriptions);
    free(properties);

    // The readonly properties are returned also as their getter methods, so we
    // need to remove those to check that there are only n factory methods left.
    NSUInteger factoryMethodCount = [factoryDefinition countOfFactoryMethods];
    NSCAssert(methodCount - propertiesCount == factoryMethodCount,
              @"protocol factory method count (%u) differs from factory defintion method count (%lu)",
              methodCount - propertiesCount, (unsigned long)factoryMethodCount);
}

static void AddPropertyGetter(Class factoryClass, objc_property_t property)
{
    // This dummy will give us the type encodings of the properties.
    // Only object properties are supported.
    Method getter = class_getInstanceMethod([TyphoonAssistedFactoryBase class], @selector(_dummyGetter));

    const char *cName = property_getName(property);
    NSString *name = [NSString stringWithCString:cName encoding:NSASCIIStringEncoding];
    SEL getterSEL = sel_registerName(cName);

    IMP getterIMP = imp_implementationWithBlock(^id (TyphoonAssistedFactoryBase *_self) {
        return [_self injectionValueForProperty:name];
    });
    class_addMethod(factoryClass, getterSEL, getterIMP, method_getTypeEncoding(getter));
}

static void AddPropertySetter(Class factoryClass, objc_property_t property)
{
    // This dummy will give us the type encodings of the properties.
    // Only object properties are supported.
    Method setter = class_getInstanceMethod([TyphoonAssistedFactoryBase class], @selector(_setDummySetter:));

    const char *cName = property_getName(property);
    NSString *name = [NSString stringWithCString:cName encoding:NSASCIIStringEncoding];
    NSString *setterName = [NSString stringWithFormat:@"set%@%@:",
                            [[name substringToIndex:1] uppercaseString],
                            [name substringFromIndex:1]];
    SEL setterSEL = sel_registerName([setterName cStringUsingEncoding:NSASCIIStringEncoding]);

    IMP setterIMP = imp_implementationWithBlock(^(TyphoonAssistedFactoryBase *_self, id value) {
        [_self setInjectionValue:value forProperty:name];
    });
    class_addMethod(factoryClass, setterSEL, setterIMP, method_getTypeEncoding(setter));
}

static void AddProperty(Class factoryClass, objc_property_t property)
{
    unsigned int propertyAttributesCount = 0;
    const char *cName = property_getName(property);
    objc_property_attribute_t *propertyAttributes = property_copyAttributeList(property, &propertyAttributesCount);
    class_addProperty(factoryClass, cName, propertyAttributes, propertyAttributesCount);
}

static void AddPropertiesToFactory(Class factoryClass, Protocol *protocol)
{
    unsigned int propertiesCount = 0;
    objc_property_t *properties = protocol_copyPropertyList(protocol, &propertiesCount);
    for (unsigned int idx = 0; idx < propertiesCount; idx++)
    {
        objc_property_t property = properties[idx];
        AddPropertyGetter(factoryClass, property);
        AddPropertySetter(factoryClass, property);
        AddProperty(factoryClass, property);
    }
    free(properties);
}

static void AddFactoryMethodsToFactory(Class factoryClass, Protocol *protocol, TyphoonAssistedFactoryDefinition *definition)
{
    [definition enumerateFactoryMethods:^(id<TyphoonAssistedFactoryMethod> factoryMethod) {
        [[TyphoonAssistedFactoryMethodCreator creatorFor:factoryMethod]
         createFromProtocol:protocol inClass:factoryClass];
    }];
}

static SEL GuessFactoryMethodForProtocol(Protocol *protocol)
{
    // Lets create two sets: the property getters and all the methods (including
    // those getters). The difference must be only one, and must be our method.
    NSMutableSet *propertyNames = [NSMutableSet set];
    NSMutableSet *methodNames = [NSMutableSet set];

    unsigned int methodCount = 0;
    struct objc_method_description *methodDescriptions = protocol_copyMethodDescriptionList(protocol, YES, YES, &methodCount);
    for (unsigned int idx = 0; idx < methodCount; idx++)
    {
        struct objc_method_description methodDescription = methodDescriptions[idx];
        [methodNames addObject:NSStringFromSelector(methodDescription.name)];
    }
    free(methodDescriptions);

    unsigned int propertiesCount = 0;
    objc_property_t *properties = protocol_copyPropertyList(protocol, &propertiesCount);
    for (unsigned int idx = 0; idx < propertiesCount; idx++)
    {
        objc_property_t property = properties[idx];
        [propertyNames addObject:[NSString stringWithCString:property_getName(property) encoding:NSASCIIStringEncoding]];
    }
    free(properties);

    [methodNames minusSet:propertyNames];
    NSString *factoryMethod = [methodNames anyObject];

    return NSSelectorFromString(factoryMethod);
}

static Class GenerateFactoryClassWithDefinition(Protocol *protocol, id factoryBlock)
{
    NSString *className = GetFactoryClassName(protocol);
    const char *cClassName = [className cStringUsingEncoding:NSASCIIStringEncoding];

    TyphoonAssistedFactoryDefinition *factoryDefinition = [[TyphoonAssistedFactoryDefinition alloc] init];
    [factoryDefinition configure:factoryBlock];

    AssertValidProtocolForFactory(protocol, factoryDefinition);

    Class factoryClass = objc_allocateClassPair([TyphoonAssistedFactoryBase class], cClassName, 0);
    // Add the factory method first, that way, the setters from the properties
    // will not exist yet.
    AddFactoryMethodsToFactory(factoryClass, protocol, factoryDefinition);
    AddPropertiesToFactory(factoryClass, protocol);
    class_addProtocol(factoryClass, protocol);
    objc_registerClassPair(factoryClass);

    return factoryClass;
}

static Class GetExistingFactoryClass(Protocol *protocol)
{
    NSString *className = GetFactoryClassName(protocol);
    const char *cClassName = [className cStringUsingEncoding:NSASCIIStringEncoding];
    return objc_getClass(cClassName);
}

static Class EnsureFactoryClassWithOneFactory(Protocol *protocol, id factoryBlock)
{
    Class factoryClass = GetExistingFactoryClass(protocol);
    if (!factoryClass)
    {
        SEL factoryMethod = GuessFactoryMethodForProtocol(protocol);

        TyphoonAssistedFactoryDefinitionBlock definition = ^(TyphoonAssistedFactoryDefinition *definition) {
            [definition factoryMethod:factoryMethod body:factoryBlock];
        };

        factoryClass = GenerateFactoryClassWithDefinition(protocol, definition);
    }

    return factoryClass;
}

static Class EnsureFactoryClassWithDefinition(Protocol *protocol, TyphoonAssistedFactoryDefinitionBlock factoryBlock)
{
    Class factoryClass = GetExistingFactoryClass(protocol);
    if (!factoryClass)
    {
        factoryClass = GenerateFactoryClassWithDefinition(protocol, factoryBlock);
    }

    return factoryClass;
}


+ (void)initialize
{
    if (self == [TyphoonFactoryProvider class])
    {
        sQueue = dispatch_queue_create("org.typhoonframework.TyphoonFactoryProvider", DISPATCH_QUEUE_SERIAL);
    }
}

+ (TyphoonDefinition *)withProtocol:(Protocol *)protocol dependencies:(TyphoonDefinitionBlock)dependenciesBlock factory:(id)factoryBlock
{
    __block Class factoryClass = nil;
    dispatch_sync(sQueue, ^{
        factoryClass = EnsureFactoryClassWithOneFactory(protocol, factoryBlock);
    });

    return [TyphoonDefinition withClass:factoryClass properties:dependenciesBlock];
}

+ (TyphoonDefinition *)withProtocol:(Protocol *)protocol dependencies:(TyphoonDefinitionBlock)dependenciesBlock factories:(TyphoonAssistedFactoryDefinitionBlock)definitionBlock
{
    __block Class factoryClass = nil;
    dispatch_sync(sQueue, ^{
        factoryClass = EnsureFactoryClassWithDefinition(protocol, definitionBlock);
    });

    return [TyphoonDefinition withClass:factoryClass properties:dependenciesBlock];
}

@end
