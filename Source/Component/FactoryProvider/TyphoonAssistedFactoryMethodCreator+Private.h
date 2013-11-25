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

#import "TyphoonAssistedFactoryMethodCreator.h"

#include <objc/runtime.h>

@interface TyphoonAssistedFactoryMethodCreator ()

- (struct objc_method_description)methodDescriptionFor:(SEL)methodName inProtocol:(Protocol *)protocol;

@end
