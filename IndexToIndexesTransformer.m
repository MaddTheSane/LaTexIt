//
//  IndexToIndexesTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
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
  id result = [[[[self class] alloc] init] autorelease];
  return result;
}
//end transformer

-(id) transformedValue:(id)value
{
  id result = nil;
  NSUInteger index = [value unsignedIntValue];
  result = (index == NSNotFound) ? [NSIndexSet indexSet] : [NSIndexSet indexSetWithIndex:index];
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = nil;
  unsigned int lastIndex = ![value count] ? NSNotFound : [value lastIndex];
  result = [NSNumber numberWithUnsignedInt:lastIndex];
  return result;
}
//end reverseTransformedValue:

@end
