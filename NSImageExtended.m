//
//  NSImageExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/07/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "NSImageExtended.h"

#import "Utils.h"

@interface NSBitmapImageRep (UnimplementedOn10_4)
-(CGImageRef) CGImage;
-(id) initWithCGImage:(CGImageRef)cgImage;
@end

@implementation NSImage (Extended)

-(NSBitmapImageRep*) bitmapImageRepresentation
{
  NSBitmapImageRep* result = nil;
  NSImageRep* imageRep = [self bestRepresentationForDevice:nil];
  if([imageRep isKindOfClass:[NSBitmapImageRep class]])
    result = (NSBitmapImageRep*)imageRep;
  else
  {
    NSEnumerator* enumerator = [[self representations] objectEnumerator];
    NSImageRep* imageRep = nil;
    while(!result && (imageRep = [enumerator nextObject]))
    {
      if([imageRep isKindOfClass:[NSBitmapImageRep class]])
        result = (NSBitmapImageRep*)imageRep;
    }
  }
    
  // if result is nil we create a new representation
  if (!result)
  {
    if (!isMacOS10_5OrAbove())
    {
      result = [NSBitmapImageRep imageRepWithData:[self TIFFRepresentation]];
      if (result)
        [self addRepresentation:result];
    }
    else//if (isMacOS10_5OrAbove())
    {
      NSSize size          = [self size];
      size_t width         = size.width;
      size_t height        = size.height;
      size_t bitsPerComp   = 32;
      size_t bytesPerPixel = (bitsPerComp / CHAR_BIT) * 4;
      size_t bytesPerRow   = bytesPerPixel * width;
      size_t totalBytes    = height * bytesPerRow;
      NSMutableData* data = nil;
      @try{
        data = [NSMutableData dataWithBytesNoCopy:calloc(totalBytes, 1) length:totalBytes freeWhenDone:YES];
      }
      @catch(NSException* e){
        DebugLog(0, @"exception : %@", e);
      }
      CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
      CGContextRef ctx = !data ? 0 : CGBitmapContextCreate([data mutableBytes], width, height, bitsPerComp, bytesPerRow, space, kCGBitmapFloatComponents | kCGImageAlphaPremultipliedLast);
      if (ctx)
      {
        [NSGraphicsContext saveGraphicsState];
        [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:ctx flipped:[self isFlipped]]];
        [self drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
        [NSGraphicsContext restoreGraphicsState];
        CGImageRef img = CGBitmapContextCreateImage(ctx);
        result = !img ? nil : [[NSBitmapImageRep alloc] initWithCGImage:img];
        if (result)
        {
          [self addRepresentation:result];
          [result release];
        }//end if (result)
        if (img)   CFRelease(img);
        if (ctx)   CGContextRelease(ctx);
      }//end if (ctx)
      if (space) CFRelease(space);
    }//end if (isMacOS10_5OrAbove())
  }//end if (!result)
  return result;
}
//end bitmapImageRepresentation

-(NSBitmapImageRep*) bitmapImageRepresentationWithMaxSize:(NSSize)maxSize
{
  NSBitmapImageRep* result = nil;
  NSImageRep* imageRep = [self bestRepresentationForDevice:nil];
  if([imageRep isKindOfClass:[NSBitmapImageRep class]])
    result = (NSBitmapImageRep*)imageRep;
  else
  {
    NSEnumerator* enumerator = [[self representations] objectEnumerator];
    NSImageRep* imageRep = nil;
    while(!result && (imageRep = [enumerator nextObject]))
    {
      if([imageRep isKindOfClass:[NSBitmapImageRep class]])
        result = (NSBitmapImageRep*)imageRep;
    }
  }
    
  // if result is nil we create a new representation
  if (!result && imageRep)
  {
    NSSize naturalSize = [imageRep size];
    NSRect adaptedRectangle = NSMakeRect(0, 0, naturalSize.width, naturalSize.height);
    if ((maxSize.width && (naturalSize.width > maxSize.width)) ||
        (maxSize.height && (naturalSize.height > maxSize.height)))
    {
      adaptedRectangle = adaptRectangle(
        NSMakeRect(0, 0, naturalSize.width, naturalSize.height), 
        NSMakeRect(0, 0, !maxSize.width  ? naturalSize.width : maxSize.width,
                         !maxSize.height ? naturalSize.height : maxSize.height),
        YES, NO, NO);
      adaptedRectangle.size.width  = (int)round(adaptedRectangle.size.width);
      adaptedRectangle.size.height = (int)round(adaptedRectangle.size.height);
    }
    result = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:0 pixelsWide:adaptedRectangle.size.width pixelsHigh:adaptedRectangle.size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
   NSImage* image = !result ? nil : [[NSImage alloc] initWithSize:adaptedRectangle.size];
   [image addRepresentation:result];
   @try{
     [image lockFocusOnRepresentation:result];
     [imageRep drawInRect:adaptedRectangle];
     [image unlockFocus];
    }
    @catch(NSException* e){
      DebugLog(0, @"exception : %@", e);
    }
    if (result)
    {
      [self addRepresentation:result];
      [result release];
    }//end if (result)
  }//end if (!result)
  return result;
}
//end bitmapImageRepresentationWithMaxSize:

@end
