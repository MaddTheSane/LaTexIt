//
//  NSUndoManagerDebug.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/04/09.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "NSUndoManagerDebug.h"

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
