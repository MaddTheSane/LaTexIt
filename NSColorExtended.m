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

//creates a color from an rgba string
+(NSColor*) colorWithRgbaString:(NSString*)string
{
  NSScanner* scanner = [NSScanner scannerWithString:string];
  float r = 0, g = 0, b = 0, a = 0;
  BOOL ok = YES;
  ok &= [scanner scanFloat:&r];
  ok &= [scanner scanFloat:&g];
  ok &= [scanner scanFloat:&b];
  ok &= [scanner scanFloat:&a];
  return ok ? [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a] : nil;
}

-(NSString*) rgbaString
{
  NSColor* colorRGB = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace]; //the color must be RGB
  return [NSString stringWithFormat:@"%f %f %f %f", [colorRGB redComponent ], [colorRGB greenComponent],
                                                    [colorRGB blueComponent], [colorRGB alphaComponent]];
}

@end
