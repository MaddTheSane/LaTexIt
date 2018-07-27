//
//  NSFontExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/07/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSFont class

#import "NSFontExtended.h"

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
