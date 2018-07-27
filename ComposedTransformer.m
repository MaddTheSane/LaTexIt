//
//  ComposedTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/04/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "ComposedTransformer.h"

@implementation ComposedTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithValueTransformer:nil additionalValueTransformer:nil additionalKeyPath:nil] forName:[self name]];
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

+(id) transformerWithValueTransformer:(NSValueTransformer*)valueTransformer
           additionalValueTransformer:(NSValueTransformer*)additionalValueTransformer additionalKeyPath:(NSString*)additionalKeyPath
{
  id result = [[[[self class] alloc] initWithValueTransformer:valueTransformer
    additionalValueTransformer:additionalValueTransformer additionalKeyPath:additionalKeyPath] autorelease];
  return result;
}
//end transformerWithValueTransformer:

-(id) initWithValueTransformer:(NSValueTransformer*)aValueTransformer
    additionalValueTransformer:(NSValueTransformer*)anAdditionalValueTransformer additionalKeyPath:(NSString*)anAdditionalKeyPath
{
  if ((!(self = [super init])))
    return nil;
  self->valueTransformer           = [aValueTransformer retain];
  self->additionalValueTransformer = [anAdditionalValueTransformer retain];
  self->additionalKeyPath          = [anAdditionalKeyPath copy];
  return self;
}
//end initWithValueTransformer:additionalKeyPath:

-(void) dealloc
{
  [self->valueTransformer           release];
  [self->additionalValueTransformer release];
  [self->additionalKeyPath          release];
  [super dealloc];
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = value;
  result = !self->valueTransformer           ? result : [self->valueTransformer           transformedValue:result];
  result = !self->additionalValueTransformer ? result : [self->additionalValueTransformer transformedValue:result];
  result = !self->additionalKeyPath          ? result : [result valueForKeyPath:self->additionalKeyPath];
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = value;
  result = !self->additionalKeyPath          ? result : [result valueForKeyPath:self->additionalKeyPath];
  result = !self->additionalValueTransformer ? result : [self->additionalValueTransformer reverseTransformedValue:result];
  result = !self->valueTransformer           ? result : [self->valueTransformer           reverseTransformedValue:result];
  return result;
}
//end transformedValue:

@end
