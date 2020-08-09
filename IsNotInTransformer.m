//
//  IsNotInTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "IsNotInTransformer.h"

@implementation IsNotInTransformer

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

+(instancetype) transformerWithReferences:(id)references
{
  id result = [[[self class] alloc] initWithReferences:references];
  return result;
}
//end transformerWithReference:

-(instancetype) initWithReferences:(id)theReferences
{
  if ((!(self = [super init])))
    return nil;
  self->references = theReferences;
  return self;
}
//end initWithFalseValue:

-(id) transformedValue:(id)value
{
  id result = @(![self->references containsObject:value]);
  return result;
}
//end transformedValue:

@end
