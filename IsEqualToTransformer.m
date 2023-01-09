//
//  IsEqualToTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import "IsEqualToTransformer.h"

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
  #ifdef ARC_ENABLED
  id result = [[[self class] alloc] initWithReference:reference];
  #else
  id result = [[[[self class] alloc] initWithReference:reference] autorelease];
  #endif
  return result;
}
//end transformerWithReference:

-(id) initWithReference:(id)aReference
{
  if ((!(self = [super init])))
    return nil;
  #ifdef ARC_ENABLED
  self->reference = aReference;
  #else
  self->reference = [aReference retain];
  #endif
  return self;
}
//end initWithFalseValue:

-(void) dealloc
{
  #ifdef ARC_ENABLED
  #else
  [self->reference release];
  [super dealloc];
  #endif
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = @([value isEqualTo:self->reference]);
  return result;
}
//end transformedValue:

@end
