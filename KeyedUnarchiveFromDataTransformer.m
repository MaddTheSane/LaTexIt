//
//  KeyedUnarchiveFromDataTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "KeyedUnarchiveFromDataTransformer.h"

@implementation KeyedUnarchiveFromDataTransformer

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
  return [NSObject class];
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
  id result = [NSKeyedUnarchiver unarchiveObjectWithData:value];
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = [NSKeyedArchiver archivedDataWithRootObject:value];
  return result;
}
//end reverseTransformedValue:

@end
