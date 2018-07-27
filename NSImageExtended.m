//
//  NSImageExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/07/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSImageExtended.h"

#import "NSObjectExtended.h"

#import "Utils.h"

@interface NSBitmapImageRep (UnimplementedOn10_4)
-(CGImageRef) CGImage;
-(id) initWithCGImage:(CGImageRef)cgImage;
@end

@interface NSImage (Bridge10_6)
-(NSImageRep*) bestRepresentationForRect:(NSRect)rect context:(NSGraphicsContext*)referenceContext hints:(NSDictionary*)hints;
@end


@implementation NSImage (Extended)

-(void) removeRepresentationsOfClass:(Class)representationClass
{
  BOOL stop = !representationClass;
  while(!stop)
  {
    NSArray* representations = [self representations];
    NSEnumerator* enumerator = [representations objectEnumerator];
    NSImageRep* representation = nil;
    NSImageRep* representationToRemove = nil;
    while(!representationToRemove && ((representation = [enumerator nextObject])))
      representationToRemove = [representation dynamicCastToClass:representationClass];
    stop |= !representationToRemove;
    if (representationToRemove)
      [self removeRepresentation:representationToRemove];
  }//end while(!stop)
}
//end removeRepresentationsOfClass:

-(NSBitmapImageRep*) bitmapImageRepresentation
{
  NSBitmapImageRep* result = nil;
  NSImageRep* imageRep = [self bestImageRepresentationInContext:nil];
  if ([imageRep isKindOfClass:[NSBitmapImageRep class]])
    result = (NSBitmapImageRep*)imageRep;
  else//if (![imageRep isKindOfClass:[NSBitmapImageRep class]])
  {
    NSEnumerator* enumerator = [[self representations] objectEnumerator];
    NSImageRep* imageRep = nil;
    while(!result && (imageRep = [enumerator nextObject]))
    {
      if ([imageRep isKindOfClass:[NSBitmapImageRep class]])
        result = (NSBitmapImageRep*)imageRep;
    }//enf fore each image representation
  }//end if (![imageRep isKindOfClass:[NSBitmapImageRep class]])
  if (!result)
  {
    result = [[self newBitmapImageRepresentation] autorelease];
    if (result)
      [self addRepresentation:result];
  }//end if (!result)
  return result;
}
//end bitmapImageRepresentation

-(NSBitmapImageRep*) newBitmapImageRepresentation
{
  NSBitmapImageRep* result = nil;
  if (!isMacOS10_5OrAbove())
    result = [[NSBitmapImageRep alloc] initWithData:[self TIFFRepresentation]];
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
      if (img)   CFRelease(img);
      if (ctx)   CGContextRelease(ctx);
    }//end if (ctx)
    if (space) CFRelease(space);
  }//end if (isMacOS10_5OrAbove())
  return result;
}
//end newBitmapImageRepresentation

-(NSBitmapImageRep*) bitmapImageRepresentationWithMaxSize:(NSSize)maxSize
{
  NSBitmapImageRep* result = nil;
  NSImageRep* imageRep = [self bestImageRepresentationInContext:nil];
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

-(NSPDFImageRep*) pdfImageRepresentation
{
  NSPDFImageRep* result = nil;
  NSImageRep* imageRep = [self bestImageRepresentationInContext:nil];
  if ([imageRep isKindOfClass:[NSPDFImageRep class]])
    result = (NSPDFImageRep*)imageRep;
  else//if (![imageRep isKindOfClass:[NSPDFImageRep class]])
  {
    NSEnumerator* enumerator = [[self representations] objectEnumerator];
    NSImageRep* imageRep = nil;
    while(!result && (imageRep = [enumerator nextObject]))
    {
      if([imageRep isKindOfClass:[NSPDFImageRep class]])
        result = (NSPDFImageRep*)imageRep;
    }//end for each imageRep
  }//end if (![imageRep isKindOfClass:[NSPDFImageRep class]])
  return result;
}
//end pdfImageRepresentation

-(NSImageRep*) bestImageRepresentationInContext:(NSGraphicsContext*)context
{
  NSImageRep* result = nil;
  if (!isMacOS10_6OrAbove())
    result = [self bestRepresentationForDevice:nil];
  else//if (isMacOS10_6OrAbove())
  {
    NSEnumerator* enumerator = [[self representations] objectEnumerator];
    NSImageRep* imageRep = nil;
    while (!result && (imageRep = [enumerator nextObject]))
    {
      if([imageRep isKindOfClass:[NSPDFImageRep class]])
        result = (NSPDFImageRep*)imageRep;
    }//end for each imageRep
    if (!result)
    {
      NSSize size = [self size];
      result = [self bestRepresentationForRect:NSMakeRect(0, 0, size.width, size.height) 
                                       context:context hints:nil];
      if (!result)
        result = [[self newBitmapImageRepresentation] autorelease];
    }//end if (!result)
  }//end if (isMacOS10_6OrAbove())
  return result;
}
//end bestImageRepresentation

@end
