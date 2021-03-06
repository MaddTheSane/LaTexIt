//
//  ObjectTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "ObjectTransformer.h"

@implementation ObjectTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithDictionary:nil] forName:[self name]];
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
  return NO;
}
//end allowsReverseTransformation

+(instancetype) transformerWithDictionary:(NSDictionary*)dictionary
{
  id result = [[[self class] alloc] initWithDictionary:dictionary];
  return result;
}
//end transformerWithDictionary:

-(instancetype) initWithDictionary:(NSDictionary*)aDictionary
{
  if ((!(self = [super init])))
    return nil;
  self->dictionary = [aDictionary copy];
  return self;
}
//end initWithDescriptors:

-(id) transformedValue:(id)value
{
  id result = self->dictionary[value];
  return result;
}
//end transformedValue:

@end
