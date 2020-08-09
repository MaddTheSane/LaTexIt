//
//  MutableTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "MutableTransformer.h"

#import "DeepCopying.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

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

+(instancetype) transformer
{
  id result = [[[self class] alloc] init];
  return result;
}
//end transformerWithDictionary:

-(instancetype) init
{
  if ((!(self = [super init])))
    return nil;
  return self;
}
//end init

-(id) transformedValue:(id)value
{
  id result = value;
  if ([result respondsToSelector:@selector(mutableCopyDeep)])
    #ifdef ARC_ENABLED
    result = [result mutableCopyDeep];
    #else
    result = [[result mutableCopyDeep] autorelease];
    #endif
  else if ([result respondsToSelector:@selector(mutableCopy)])    
    #ifdef ARC_ENABLED
    result = [result mutableCopy];
    #else
    result = [[result mutableCopy] autorelease];
    #endif
  else if ([result respondsToSelector:@selector(copy)])
    result = [result copy];
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = value;
  if ([result respondsToSelector:@selector(copy)])
    result = [result copy];
  return result;
}
//end reverseTransformedValue:

@end
