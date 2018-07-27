//
//  BoolTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.
//

#import "BoolTransformer.h"

@implementation BoolTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithFalseValue:nil trueValue:nil] forName:[self name]];
}
//end initialize

+(NSString*) name
{
  NSString* result = [self className];
  return result;
}
//end name

+(Class) transformedValueClass
{
  return [NSObject class];
}
//end transformedValueClass

+(BOOL) allowsReverseTransformation
{
  return YES;
}
//end allowsReverseTransformation

+(id) transformerWithFalseValue:(id)falseValue trueValue:(id)trueValue
{
  id result = [[[[self class] alloc] initWithFalseValue:falseValue trueValue:trueValue] autorelease];
  return result;
}
//end transformerWithReference:

-(id) initWithFalseValue:(id)aFalseValue trueValue:(id)aTrueValue
{
  if ((!(self = [super init])))
    return nil;
  self->falseValue = [aFalseValue retain];
  self->trueValue  = [aTrueValue  retain];
  return self;
}
//end initWithFalseValue:

-(void) dealloc
{
  [self->falseValue release];
  [self->trueValue  release];
  [super dealloc];
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = [value boolValue] ? self->trueValue : self->falseValue;
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = [NSNumber numberWithBool:[value isEqualTo:self->trueValue]];
  return result;
}
//end reverseTransformedValue:

@end
