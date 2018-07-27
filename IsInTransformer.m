//
//  IsInTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.
//

#import "IsInTransformer.h"

@implementation IsInTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithReferences:nil] forName:[self name]];
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

+(id) transformerWithReferences:(id)references
{
  #ifdef ARC_ENABLED
  id result = [[[self class] alloc] initWithReferences:references];
  #else
  id result = [[[[self class] alloc] initWithReferences:references] autorelease];
  #endif
  return result;
}
//end transformerWithReference:

-(id) initWithReferences:(id)theReferences
{
  if ((!(self = [super init])))
    return nil;
  #ifdef ARC_ENABLED
  self->references = theReferences;
  #else
  self->references = [theReferences retain];
  #endif
  return self;
}
//end initWithFalseValue:

-(void) dealloc
{
  #ifdef ARC_ENABLED
  #else
  [self->references release];
  [super dealloc];
  #endif
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = [NSNumber numberWithBool:[self->references containsObject:value]];
  return result;
}
//end transformedValue:

@end
