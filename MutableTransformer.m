//
//  MutableTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
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
  id result = [[[[self class] alloc] init] autorelease];
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
  [super dealloc];
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = value;
  if ([result respondsToSelector:@selector(deepMutableCopy)])
    result = [[result deepMutableCopy] autorelease];
  else if ([result respondsToSelector:@selector(mutableCopy)])    
    result = [[result mutableCopy] autorelease];
  else if ([result respondsToSelector:@selector(copy)])    
    result = [[result copy] autorelease];
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = value;
  if ([result respondsToSelector:@selector(copy)])
    result = [[result copy] autorelease];
  return result;
}
//end reverseTransformedValue:

@end
