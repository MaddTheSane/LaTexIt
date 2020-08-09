//
//  ComposedTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "ComposedTransformer.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

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

+(instancetype) transformerWithValueTransformer:(NSValueTransformer*)valueTransformer
           additionalValueTransformer:(NSValueTransformer*)additionalValueTransformer additionalKeyPath:(NSString*)additionalKeyPath
{
  id result = [[[self class] alloc] initWithValueTransformer:valueTransformer
    additionalValueTransformer:additionalValueTransformer additionalKeyPath:additionalKeyPath];
  return result;
}
//end transformerWithValueTransformer:

-(instancetype) initWithValueTransformer:(NSValueTransformer*)aValueTransformer
    additionalValueTransformer:(NSValueTransformer*)anAdditionalValueTransformer additionalKeyPath:(NSString*)anAdditionalKeyPath
{
  if ((!(self = [super init])))
    return nil;
  self->valueTransformer           = aValueTransformer;
  self->additionalValueTransformer = anAdditionalValueTransformer;
  self->additionalKeyPath          = anAdditionalKeyPath;
  return self;
}
//end initWithValueTransformer:additionalKeyPath:

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
