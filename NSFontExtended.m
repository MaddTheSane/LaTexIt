//
//  NSFontExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/07/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSFont class

#import "NSFontExtended.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSFont (Extended)

+(NSFont*) fontWithData:(NSData*)data
{
  NSFont* result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  return result;
}
//end fontWithData:

-(NSData*) data
{
  NSData* result = [NSKeyedArchiver archivedDataWithRootObject:self];
  return result;
}
//end data

-(NSString*) displayNameWithPointSize
{
  NSString* result = [NSString stringWithFormat:@"%@ %.1f", [self displayName], [self pointSize]];
  return result;
}
//end displayNameWithPointSize

@end
