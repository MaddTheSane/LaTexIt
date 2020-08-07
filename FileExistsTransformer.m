//
//  FileExistsTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "FileExistsTransformer.h"

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
  #ifdef ARC_ENABLED
  id result = [[[self class] alloc] initWithDirectoryAllowed:directoryAllowed];
  #else
  id result = [[[[self class] alloc] initWithDirectoryAllowed:directoryAllowed] autorelease];
  #endif
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
  result = @(exists && (!isDirectory || self->directoryAllowed));
  return result;
}
//end transformedValue:


@end
