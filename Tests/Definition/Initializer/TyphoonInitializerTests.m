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


#import <Typhoon/TyphoonMethod.h>
#import <SenTestingKit/SenTestingKit.h>
#import "MiddleAgesAssembly.h"
#import "Typhoon.h"
#import "Knight.h"

@interface TyphoonInitializerTests : SenTestCase
@end


@implementation TyphoonInitializerTests
{
    TyphoonMethod *_initializer;
    TyphoonComponentFactory *_factory;
}

- (void)setUp
{
    [super setUp];
    _factory = [TyphoonBlockComponentFactory factoryWithAssembly:[MiddleAgesAssembly assembly]];
}


- (void)test_single_parameter_method_incorrect_parameter_name_warns
{
    @try {
        _initializer = [self newInitializerWithSelector:@selector(initWithString:)];
        [_initializer injectParameter:@"strnig" with:@"a string"];
        STFail(@"Should've thrown exception");
    }
    @catch (NSException *e) {
        assertThat([e description], equalTo(@"Unrecognized parameter name: 'strnig' for method 'initWithString:'. Did you mean 'string'?"));
    }

}

- (void)test_two_parameter_method_incorrect_parameter_name_warns
{
    @try {
        _initializer = [self newInitializerWithSelector:@selector(initWithClass:key:)];
        [_initializer injectParameter:@"keyy" with:@"a key"];
        STFail(@"Should've thrown exception");
    }
    @catch (NSException *e) {
        assertThat([e description], equalTo(@"Unrecognized parameter name: 'keyy' for method 'initWithClass:key:'. Valid parameter names are 'class' or 'key'."));
    }

}

- (void)test_multiple_parameter_method_incorrect_parameter_name_warns
{
    @try {
        _initializer = [self newInitializerWithSelector:@selector(initWithContentsOfURL:options:error:)];
        [_initializer injectParameter:@"path" with:@"a parameter that isn't there"];
        STFail(@"Should've thrown exception");
    }
    @catch (NSException *e) {
        assertThat([e description], equalTo(@"Unrecognized parameter name: 'path' for method 'initWithContentsOfURL:options:error:'. Valid parameter names are 'contentsOfURL', 'options', or 'error'."));
    }


}

- (void)test_no_parameter_method_parameter_name_specified
{
    @try {
        _initializer = [self newInitializerWithSelector:@selector(init)];
        [_initializer injectParameter:@"aParameter" with:@"anObject"];
        STFail(@"Should've thrown exception");
    }
    @catch (NSException *e) {
        assertThat([e description], equalTo(@"Specified a parameter named 'aParameter', but method 'init' takes no parameters."));
    }

}

- (void)test_knight_init_by_class_method
{
    Knight *knight = [_factory componentForKey:@"knightClassMethodInit"];
    STAssertTrue(knight.damselsRescued == 13, @"");
}

/* ====================================================================================================================================== */
#pragma mark - Utility Methods

- (TyphoonMethod *)newInitializerWithSelector:(SEL)aSelector
{
    TyphoonMethod *anInitializer = [[TyphoonMethod alloc] initWithSelector:aSelector];
    return anInitializer;
}

@end