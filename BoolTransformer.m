//
//  BoolTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "BoolTransformer.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

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
  id result = [[[self class] alloc] initWithFalseValue:falseValue trueValue:trueValue];
  return result;
}
//end transformerWithReference:

-(id) initWithFalseValue:(id)aFalseValue trueValue:(id)aTrueValue
{
  if ((!(self = [super init])))
    return nil;
  self->falseValue = aFalseValue;
  self->trueValue  = aTrueValue;
  return self;
}
//end initWithFalseValue:

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
