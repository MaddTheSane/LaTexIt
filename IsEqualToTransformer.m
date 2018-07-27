//
//  IsEqualToTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2009 LAIC. All rights reserved.
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
  id result = [[[[self class] alloc] initWithReference:reference] autorelease];
  return result;
}
//end transformerWithReference:

-(id) initWithReference:(id)aReference
{
  if ((!(self = [super init])))
    return nil;
  self->reference = [aReference retain];
  return self;
}
//end initWithFalseValue:

-(void) dealloc
{
  [self->reference release];
  [super dealloc];
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = [NSNumber numberWithBool:[value isEqualTo:self->reference]];
  return result;
}
//end transformedValue:

@end
