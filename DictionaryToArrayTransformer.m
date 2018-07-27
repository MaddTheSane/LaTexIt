//
//  DictionaryToArrayTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.
//

#import "DictionaryToArrayTransformer.h"

@implementation DictionaryToArrayTransformer

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
  return YES;
}
//end allowsReverseTransformation

+(id) transformerWithDescriptors:(NSArray*)descriptors
{
  #ifdef ARC_ENABLED
  id result = [[[self class] alloc] initWithDescriptors:descriptors];
  #else
  id result = [[[[self class] alloc] initWithDescriptors:descriptors] autorelease];
  #endif
  return result;
}
//end transformerWithValueTransformer:

-(id) initWithDescriptors:(NSArray*)theDescriptors
{
  if ((!(self = [super init])))
    return nil;
  #ifdef ARC_ENABLED
  self->descriptors = theDescriptors ? [theDescriptors copy] : 
    [[NSArray alloc] initWithObjects:[[NSSortDescriptor alloc] initWithKey:@"self" ascending:YES selector:nil], nil];
  #else
  self->descriptors = theDescriptors ? [theDescriptors copy] : 
    [[NSArray alloc] initWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"self" ascending:YES selector:nil] autorelease], nil];
  #endif
  return self;
}
//end initWithDescriptors:

-(void) dealloc
{
  #ifdef ARC_ENABLED
  #else
  [self->descriptors release];
  [super dealloc];
  #endif
}
//end dealloc

-(id) transformedValue:(id)value
{
  NSMutableArray* result = [NSMutableArray arrayWithCapacity:[value count]];
  NSArray* sortedKeys = [[value allKeys] sortedArrayUsingDescriptors:self->descriptors];
  NSEnumerator* enumerator = [sortedKeys objectEnumerator];
  id key = nil;
  while((key = [enumerator nextObject]))
  {
    id valueForKey = [value objectForKey:key];
    [result addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, @"key", valueForKey, @"value", nil]];
  }
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  NSMutableDictionary* result = [NSMutableDictionary dictionaryWithCapacity:[value count]];
  NSEnumerator* enumerator = [value objectEnumerator];
  NSDictionary* entry = nil;
  while((entry = [enumerator nextObject]))
    [result setObject:[entry objectForKey:@"value"] forKey:[entry objectForKey:@"key"]];
  return result;
}
//end reverseTransformedValue:

@end
