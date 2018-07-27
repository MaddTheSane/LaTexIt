//
//  NSUndoManagerDebug.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSUndoManagerDebug.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSUndoManagerDebug

-(void) forwardInvocation:(NSInvocation *)anInvocation
{
  [super forwardInvocation:anInvocation];
}
//end forwardInvocation:

-(id) prepareWithInvocationTarget:(id)target
{
  id result = [super prepareWithInvocationTarget:target];
  return result;
}
//end prepareWithInvocationTarget:

-(void) registerUndoWithTarget:(id)target selector:(SEL)aSelector object:(id)anObject
{
  [super registerUndoWithTarget:target selector:aSelector object:anObject];
}
//end registerUndoWithTarget:selector:object:

@end
