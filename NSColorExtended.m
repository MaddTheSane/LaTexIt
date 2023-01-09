//  NSColorExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/05/05.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSColor class

#import "NSColorExtended.h"

#import "NSObjectExtended.h"
#import "Utils.h"

@implementation NSColor (Extended)

//creates a color from data
+(NSColor*) colorWithData:(NSData*)data
{
  NSColor* result = nil;
  NSError* decodingError = nil;
  if (@available(macOS 10.13, *)) {
    result = !data ? nil :
    [NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:data error:&decodingError];
  } else {
    result = !data ? nil :
    [[NSKeyedUnarchiver unarchiveObjectWithData:data] dynamicCastToClass:[NSColor class]];
  }
  if (decodingError != nil)
    DebugLog(0, @"decoding error : %@", decodingError);
  return result;
}
//end colorWithData:

//returns the color as data
-(NSData*) colorAsData
{
  NSData* result;
  if (@available(macOS 10.13, *)) {
    result = [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:YES error:nil];
  } else {
    result = [NSKeyedArchiver archivedDataWithRootObject:self];
  }
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
    float r = 0, g = 0, b = 0, a = 0;
    BOOL ok = YES;
    ok &= [scanner scanFloat:&r];
    ok &= [scanner scanFloat:&g];
    ok &= [scanner scanFloat:&b];
    ok &= [scanner scanFloat:&a];
    result = !ok ? nil : [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
  }//end if (string)
  return result;
}
//end colorWithRgbaString:

-(NSString*) rgbaString
{
  NSString* result = nil;
  NSColor* colorRGB = [self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]; //the color must be RGB
  result = [NSString stringWithFormat:@"%f %f %f %f", [colorRGB redComponent ], [colorRGB greenComponent],
                                                      [colorRGB blueComponent], [colorRGB alphaComponent]];
  return result;
}
//end rgbaString

-(CGFloat) grayLevel
{
  return [[self colorUsingColorSpace:[NSColorSpace deviceGrayColorSpace]] whiteComponent];
}
//end grayLevel

-(BOOL) isRGBEqualTo:(NSColor*)other
{
  return [[self rgbaString] isEqualToString:[other rgbaString]];
}
//end isRGBEqualTo:

-(NSColor*) darker:(CGFloat)factor
{
  NSColor* result = self;
  CGFloat hsba[4] = {0};
  [[self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] getHue:&hsba[0] saturation:&hsba[1] brightness:&hsba[2] alpha:&hsba[3]];
  hsba[1] = MAX(0, MIN(1, hsba[1]*(1+factor)));
  hsba[2] = MAX(0, MIN(1, hsba[2]*(1-factor)));
  result = [NSColor colorWithCalibratedHue:hsba[0] saturation:hsba[1] brightness:hsba[2] alpha:hsba[3]];
  return result;
}
//end darker:

-(NSColor*) lighter:(CGFloat)factor
{
  NSColor* result = self;
  CGFloat hsba[4] = {0};
  [[self colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] getHue:&hsba[0] saturation:&hsba[1] brightness:&hsba[2] alpha:&hsba[3]];
  hsba[1] = MAX(0, MIN(1, hsba[1]*(1-factor)));
  hsba[2] = MAX(0, MIN(1, hsba[2]*(1+factor)));
  result = [NSColor colorWithCalibratedHue:hsba[0] saturation:hsba[1] brightness:hsba[2] alpha:hsba[3]];
  return result;
}
//end lighter:

-(BOOL) isConsideredWhite
{
  BOOL result = ([self grayLevel] >= 0.999);
  return result;
}
//end isConsideredWhite

@end
