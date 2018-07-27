//
//  IsInTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
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
  id result = [[[[self class] alloc] initWithReferences:references] autorelease];
  return result;
}
//end transformerWithReference:

-(id) initWithReferences:(id)theReferences
{
  if ((!(self = [super init])))
    return nil;
  self->references = [theReferences retain];
  return self;
}
//end initWithFalseValue:

-(void) dealloc
{
  [self->references release];
  [super dealloc];
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = [NSNumber numberWithBool:[self->references containsObject:value]];
  return result;
}
//end transformedValue:

@end
