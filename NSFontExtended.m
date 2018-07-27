//
//  NSFontExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/07/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

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
