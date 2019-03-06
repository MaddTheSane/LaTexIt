//
//  FilePathLocalizedTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "FilePathLocalizedTransformer.h"

#import "NSFileManagerExtended.h"

@implementation FilePathLocalizedTransformer

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
  return NO;
}
//end allowsReverseTransformation

+(instancetype) transformer
{
  id result = [[[self class] alloc] init];
  return result;
}
//end transformer

-(instancetype) init
{
  if ((!(self = [super init])))
    return nil;
  return self;
}
//end init

-(id) transformedValue:(id)value
{
  id result = [[NSFileManager defaultManager] localizedPath:value];
  return result;
}
//end transformedValue:

@end
