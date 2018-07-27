//  NSColorExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSColor class

#import "NSColorExtended.h"

@implementation NSColor (Extended)

//creates a color from data
+(NSColor*) colorWithData:(NSData*)data
{
  return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

//returns the color as data
-(NSData*) data
{
  return [NSKeyedArchiver archivedDataWithRootObject:self];
}

@end
