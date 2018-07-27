//
//  IsEqualToTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "IsEqualToTransformer.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation IsEqualToTransformer

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

+(id) transformerWithReference:(id)reference
{
  id result = [[[self class] alloc] initWithReference:reference];
  return result;
}
//end transformerWithReference:

-(id) initWithReference:(id)aReference
{
  if ((!(self = [super init])))
    return nil;
  self->reference = aReference;
  return self;
}
//end initWithFalseValue:

-(id) transformedValue:(id)value
{
  id result = [NSNumber numberWithBool:[value isEqualTo:self->reference]];
  return result;
}
//end transformedValue:

@end
