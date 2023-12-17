//
//  FolderExistsTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import "FolderExistsTransformer.h"

@implementation FolderExistsTransformer

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

+(id) transformer
{
  id result = [[[[self class] alloc] init] autorelease];
  return result;
}
//end transformer

-(id) init
{
  if ((!(self = [super init])))
    return nil;
  return self;
}
//end init

-(id) transformedValue:(id)value
{
  id result = nil;
  BOOL isDirectory = NO;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:value isDirectory:&isDirectory];
  result = @(exists && isDirectory);
  return result;
}
//end transformedValue:


@end
