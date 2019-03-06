//
//  LatexitEquationWrapper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/10/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "LatexitEquationWrapper.h"

#import "LaTeXProcessor.h"
#import "Utils.h"

@implementation LatexitEquationWrapper

-(LatexitEquation*) equation
{
  LatexitEquation* result = nil;
  [self willAccessValueForKey:@"equation"];
  result = [self primitiveValueForKey:@"equation"];
  [self didAccessValueForKey:@"equation"];
  return result;
}
//end equation

-(void) setEquation:(LatexitEquation*)value
{
  [self willChangeValueForKey:@"equation"];
  [self setPrimitiveValue:value forKey:@"equation"];
  [self didChangeValueForKey:@"equation"];
}
//end setEquation:

@end


