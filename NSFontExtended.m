//
//  NSFontExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/07/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.

//This file is an extension of the NSFont class

#import "NSFontExtended.h"

@implementation NSFont (Extended)

//creates a font from data
+(NSFont*) fontWithData:(NSData*)data
{
  return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

//returns the font as data
-(NSData*) data
{
  return [NSKeyedArchiver archivedDataWithRootObject:self];
}

@end
