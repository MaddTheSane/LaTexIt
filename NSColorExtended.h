//  NSColorExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/05/05.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSColor class

#import <Cocoa/Cocoa.h>

@interface NSColor (Extended)

//Unfortunately, so far, an NSColor does not know how to transform itself into data, or built itself with data
//We have to make that by hand
+(NSColor*) colorWithData:(NSData*)data;
-(NSData*) colorAsData;

//same thing for color as rgba string (%f %f %f %f)
+(NSColor*) colorWithRgbaString:(NSString*)string;
-(NSString*) rgbaString;

-(CGFloat) grayLevel;
-(BOOL) isRGBEqualTo:(NSColor*)other;

-(NSColor*) darker:(CGFloat)factor;
-(NSColor*) lighter:(CGFloat)factor;

-(BOOL) isConsideredWhite;

@end
