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

#import <Foundation/Foundation.h>

@interface NSValue (TCFInstanceBuilder)

- (void)typhoon_setAsArgumentWithType:(const char *)argumentType forInvocation:(NSInvocation *)invocation atIndex:(NSUInteger)index;

@end


/* Since NSNumber is subclass of NSValue, this category lives in same file */
@interface NSNumber (TCFInstanceBuilder)

- (void)typhoon_setAsArgumentWithType:(const char *)argumentType forInvocation:(NSInvocation *)invocation atIndex:(NSUInteger)index;

@end
