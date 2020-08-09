//
//  DictionaryToArrayTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "DictionaryToArrayTransformer.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

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

+(instancetype) transformerWithDescriptors:(NSArray*)descriptors
{
  id result = [[[self class] alloc] initWithDescriptors:descriptors];
  return result;
}
//end transformerWithValueTransformer:

-(instancetype) initWithDescriptors:(NSArray*)theDescriptors
{
  if ((!(self = [super init])))
    return nil;
  self->descriptors = theDescriptors ? [theDescriptors copy] :
    @[[[NSSortDescriptor alloc] initWithKey:@"self" ascending:YES selector:nil]];
  return self;
}
//end initWithDescriptors:

-(id) transformedValue:(id)value
{
  NSMutableArray* result = [NSMutableArray arrayWithCapacity:[value count]];
  NSArray* sortedKeys = [[value allKeys] sortedArrayUsingDescriptors:self->descriptors];
  NSEnumerator* enumerator = [sortedKeys objectEnumerator];
  id key = nil;
  while((key = [enumerator nextObject]))
  {
    id valueForKey = value[key];
    [result addObject:@{@"key": key, @"value": valueForKey}];
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
    result[entry[@"key"]] = entry[@"value"];
  return result;
}
//end reverseTransformedValue:

@end
