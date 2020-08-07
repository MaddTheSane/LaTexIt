//
//  IndexToIndexesTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "IndexToIndexesTransformer.h"

@implementation IndexToIndexesTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformer] forName:[self name]];
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
  return YES;
}
//end allowsReverseTransformation

+(id) transformer
{
  #ifdef ARC_ENABLED
  id result = [[[self class] alloc] init];
  #else
  id result = [[[[self class] alloc] init] autorelease];
  #endif
  return result;
}
//end transformer

-(id) transformedValue:(id)value
{
  id result = nil;
  NSUInteger index = [value unsignedIntegerValue];
  result = (index == NSNotFound) ? [NSIndexSet indexSet] : [NSIndexSet indexSetWithIndex:index];
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = nil;
  NSUInteger lastIndex = ![value count] ? NSNotFound : [value lastIndex];
  result = @(lastIndex);
  return result;
}
//end reverseTransformedValue:

@end
