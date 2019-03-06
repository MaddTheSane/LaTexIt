//
//  MutableTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "MutableTransformer.h"

#import "DeepCopying.h"

@implementation MutableTransformer

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
//end transformerWithDictionary:

-(id) init
{
  if ((!(self = [super init])))
    return nil;
  return self;
}
//end init

-(void) dealloc
{
  #ifdef ARC_ENABLED
  #else
  [super dealloc];
  #endif
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = value;
  if ([result respondsToSelector:@selector(deepMutableCopy)])
    #ifdef ARC_ENABLED
    result = [result deepMutableCopy];
    #else
    result = [[result deepMutableCopy] autorelease];
    #endif
  else if ([result respondsToSelector:@selector(mutableCopy)])    
    #ifdef ARC_ENABLED
    result = [result mutableCopy];
    #else
    result = [[result mutableCopy] autorelease];
    #endif
  else if ([result respondsToSelector:@selector(copy)])
    #ifdef ARC_ENABLED
    result = [result copy];
    #else
    result = [[result copy] autorelease];
    #endif
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = value;
  if ([result respondsToSelector:@selector(copy)])
    #ifdef ARC_ENABLED
    result = [result copy];
    #else
    result = [[result copy] autorelease];
    #endif
  return result;
}
//end reverseTransformedValue:

@end
