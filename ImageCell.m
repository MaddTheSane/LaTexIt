//
//  ImageCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/2019.
//
//

#import "ImageCell.h"

#import "NSObjectExtended.h"
#import "CGExtras.h"
#import "Utils.h"

@implementation ImageCell

-(id) init
{
  if (!((self = [super init])))
    return nil;
  self->backgroundColor = [[NSColor whiteColor] copy];
  return self;
}
//end init

-(void) dealloc
{
  [self->backgroundColor release];
  [super dealloc];
}
//end dealloc

-(NSColor*) backgroundColor
{
  return [[self->backgroundColor copy] autorelease];
}
//end backgroundColor

-(void) setBackgroundColor:(NSColor*)value
{
  if (value != self->backgroundColor)
  {
    [self->backgroundColor release];
    self->backgroundColor = [value copy];
  }//end if (value != self->backgroundColor)
}
//end setBackgroundColor:

-(void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
  CGContextRef cgContext = [[NSGraphicsContext currentContext] graphicsPort];
  NSRect bounds = cellFrame;

  static const CGFloat rgba1_light[4] = {0.95f, 0.95f, 0.95f, 1.0f};
  static const CGFloat rgba1_dark[4] = {0.5f, 0.5f, 0.5f, 1.0f};
  static const CGFloat rgba2_light[4] = {0.68f, 0.68f, 0.68f, 1.f};
  static const CGFloat rgba2_dark[4] = {0.15f, 0.15f, 0.15f, 1.0f};
  BOOL isDark = [controlView isDarkMode];
  const CGFloat* rgba1 = isDark ? rgba1_dark : rgba1_light;
  const CGFloat* rgba2 = isDark ? rgba2_dark : rgba2_light;

  NSRect inRoundedRect1 = NSInsetRect(bounds, 1, 1);
  NSRect inRoundedRect2 = NSInsetRect(bounds, 2, 2);
  NSRect inRoundedRect3 = NSInsetRect(bounds, 3, 3);
  NSRect inRect = NSInsetRect(bounds, 7, 7);

  NSImage* currentImage = [self image];
  NSSize naturalImageSize = currentImage ? [currentImage size] : NSZeroSize;
  NSSize newSize = naturalImageSize;

  NSRect destRect = NSMakeRect(0, 0, newSize.width, newSize.height);
  destRect = adaptRectangle(destRect, inRect, YES, NO, NO);
  if (self->backgroundColor)
  {
    CGFloat backgroundRGBcomponents[4] = {rgba1[0], rgba1[1], rgba1[2], rgba1[3]};
    [[self->backgroundColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
     getRed:&backgroundRGBcomponents[0] green:&backgroundRGBcomponents[1] blue:&backgroundRGBcomponents[2] alpha:&backgroundRGBcomponents[3]];
    CGContextSetRGBFillColor(cgContext, backgroundRGBcomponents[0], backgroundRGBcomponents[1], backgroundRGBcomponents[2], backgroundRGBcomponents[3]);
    CGContextBeginPath(cgContext);
    CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect2), 4.f, 4.f);
    CGContextFillPath(cgContext);
  }//end if (self->backgroundColor)

  CGContextSaveGState(cgContext);
  CGContextBeginPath(cgContext);
  CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect3), 4.f, 4.f);
  CGContextClip(cgContext);
  
  CGFloat backgroundRGBcomponents[4] = {rgba1[0], rgba1[1], rgba1[2], rgba1[3]};
  if (self->backgroundColor)
  {
    [[self->backgroundColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]]
     getRed:&backgroundRGBcomponents[0] green:&backgroundRGBcomponents[1] blue:&backgroundRGBcomponents[2] alpha:&backgroundRGBcomponents[3]];
  }//end if (self->backgroundColor)
  CGContextSetRGBFillColor(cgContext, backgroundRGBcomponents[0], backgroundRGBcomponents[1], backgroundRGBcomponents[2], backgroundRGBcomponents[3]);
  CGContextBeginPath(cgContext);
  CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect2), 4.f, 4.f);
  CGContextFillPath(cgContext);

  [[self image] drawInRect:destRect fromRect:NSMakeRect(0, 0, naturalImageSize.width, naturalImageSize.height)
          operation:NSCompositeSourceOver fraction:1.];
  CGContextRestoreGState(cgContext);
  
  CGContextSetRGBFillColor(cgContext, 0, 0, 0, 0);
  CGContextFillRect(cgContext, CGRectFromNSRect(bounds));
  CGContextBeginPath(cgContext);
  CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect3), 4.f, 4.f);
  CGContextClip(cgContext);
  CGContextSetRGBStrokeColor(cgContext, rgba2[0], rgba2[1], rgba2[2], rgba2[3]);
  CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect3), 4.f, 4.f);
  CGContextStrokePath(cgContext);
  CGContextSetRGBStrokeColor(cgContext, rgba1[0], rgba1[1], rgba1[2], rgba1[3]);
  CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect1), 4.f, 4.f);
  CGContextStrokePath(cgContext);
  CGContextSetRGBStrokeColor(cgContext, rgba1[0], rgba1[1], rgba1[2], rgba1[3]);
  CGContextAddRoundedRect(cgContext, CGRectFromNSRect(inRoundedRect2), 4.f, 4.f);
  CGContextStrokePath(cgContext);
}
//end drawWithFrame:inView:

@end
