//
//  KeyedUnarchiveFromDataTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "KeyedUnarchiveFromDataTransformer.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

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

+(instancetype) transformer
{
  id result = [[[self class] alloc] init];
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
