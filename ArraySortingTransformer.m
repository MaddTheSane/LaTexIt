//
//  ArraySortingTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "ArraySortingTransformer.h"

@implementation ArraySortingTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithDescriptors:nil] forName:[self name]];
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
  return [NSArray class];
}
//end transformedValueClass

+(BOOL) allowsReverseTransformation
{
  return NO;
}
//end allowsReverseTransformation

+(id) transformerWithDescriptors:(NSArray*)descriptors
{
  id result = [[[[self class] alloc] initWithDescriptors:descriptors] autorelease];
  return result;
}
//end transformerWithValueTransformer:

-(id) initWithDescriptors:(NSArray*)theDescriptors
{
  if ((!(self = [super init])))
    return nil;
  self->descriptors = theDescriptors ? [theDescriptors copy] : 
    [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"self" ascending:YES selector:nil] autorelease], nil];
  return self;
}
//end initWithDescriptors:

-(void) dealloc
{
  [self->descriptors release];
  [super dealloc];
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = [value sortedArrayUsingDescriptors:self->descriptors];
  return result;
}
//end transformedValue:

@end
