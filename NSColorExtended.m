//  NSColorExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/05/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSColor class

#import "NSColorExtended.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSColor (Extended)

//creates a color from data
+(NSColor*) colorWithData:(NSData*)data
{
  NSColor* result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  return result;
}
//end colorWithData:

//returns the color as data
-(NSData*) colorAsData
{
  NSData* result = [NSKeyedArchiver archivedDataWithRootObject:self];
  return result;
}
//end colorAsData

//creates a color from an rgba string
+(NSColor*) colorWithRgbaString:(NSString*)string
{
  NSColor* result = nil;
  if (string)
  {
    NSScanner* scanner = [NSScanner scannerWithString:string];
    double r = 0, g = 0, b = 0, a = 0;
    BOOL ok = YES;
    ok &= [scanner scanDouble:&r];
    ok &= [scanner scanDouble:&g];
    ok &= [scanner scanDouble:&b];
    ok &= [scanner scanDouble:&a];
    result = !ok ? nil : [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
  }//end if (string)
  return result;
}
//end colorWithRgbaString:

-(NSString*) rgbaString
{
  NSColor* colorRGB = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace]; //the color must be RGB
  return [NSString stringWithFormat:@"%f %f %f %f", colorRGB.redComponent , colorRGB.greenComponent,
                                                    colorRGB.blueComponent, colorRGB.alphaComponent];
}
//end rgbaString

-(CGFloat) grayLevel
{
  return [self colorUsingColorSpaceName:NSCalibratedWhiteColorSpace].whiteComponent;
}
//end grayLevel

-(BOOL) isRGBEqualTo:(NSColor*)other
{
  return [[self rgbaString] isEqualToString:[other rgbaString]];
}
//end isRGBEqualTo:

@end
