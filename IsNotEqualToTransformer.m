//
//  IsNotEqualToTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "IsNotEqualToTransformer.h"

@implementation IsNotEqualToTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithReference:nil] forName:[self name]];
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
  return [NSNumber class];
}
//end transformedValueClass

+(BOOL) allowsReverseTransformation
{
  return NO;
}
//end allowsReverseTransformation

+(instancetype) transformerWithReference:(id)reference
{
  id result = [[[self class] alloc] initWithReference:reference];
  return result;
}
//end transformerWithReference:

-(instancetype) initWithReference:(id)aReference
{
  if ((!(self = [super init])))
    return nil;
  self->reference = aReference;
  return self;
}
//end initWithFalseValue:

-(id) transformedValue:(id)value
{
  id result = @(![value isEqualTo:self->reference]);
  return result;
}
//end transformedValue:

@end
