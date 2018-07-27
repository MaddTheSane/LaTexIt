//
//  FileExistsTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "FileExistsTransformer.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation FileExistsTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithDirectoryAllowed:NO] forName:[self name]];
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

+(id) transformerWithDirectoryAllowed:(BOOL)directoryAllowed
{
  id result = [[[self class] alloc] initWithDirectoryAllowed:directoryAllowed];
  return result;
}
//end transformerWithDirectoryAllowed:

-(id) initWithDirectoryAllowed:(BOOL)isDirectoryAllowed
{
  if ((!(self = [super init])))
    return nil;
  self->directoryAllowed = isDirectoryAllowed;
  return self;
}
//end initWithDirectoryAllowed:

-(id) transformedValue:(id)value
{
  id result = nil;
  BOOL isDirectory = NO;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:value isDirectory:&isDirectory];
  result = [NSNumber numberWithBool:exists && (!isDirectory || self->directoryAllowed)];
  return result;
}
//end transformedValue:


@end
