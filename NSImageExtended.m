//
//  NSImageExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/07/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "NSImageExtended.h"

#import "NSObjectExtended.h"

#import "CGExtras.h"
#import "Utils.h"

@implementation NSImage (Extended)

-(void) removeRepresentationsOfClass:(Class)representationClass
{
  BOOL stop = !representationClass;
  while(!stop)
  {
    NSArray* representations = self.representations;
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
    NSEnumerator* enumerator = [self.representations objectEnumerator];
    NSImageRep* imageRep = nil;
    while(!result && (imageRep = [enumerator nextObject]))
    {
      if ([imageRep isKindOfClass:[NSBitmapImageRep class]])
        result = (NSBitmapImageRep*)imageRep;
    }//enf fore each image representation
  }//end if (![imageRep isKindOfClass:[NSBitmapImageRep class]])
  if (!result)
  {
    result = [self newBitmapImageRepresentation];
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
    result = [[NSBitmapImageRep alloc] initWithData:self.TIFFRepresentation];
  else//if (isMacOS10_5OrAbove())
  {
    NSSize size          = self.size;
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
    CGContextRef ctx = !data ? 0 : CGBitmapContextCreate(data.mutableBytes, width, height, bitsPerComp, bytesPerRow, space, kCGBitmapFloatComponents | kCGImageAlphaPremultipliedLast);
    if (ctx)
    {
      [NSGraphicsContext saveGraphicsState];
      [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:ctx flipped:NO]];
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
    NSEnumerator* enumerator = [self.representations objectEnumerator];
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
    NSSize naturalSize = imageRep.size;
    NSRect adaptedRectangle = NSMakeRect(0, 0, naturalSize.width, naturalSize.height);
    if ((maxSize.width && (naturalSize.width > maxSize.width)) ||
        (maxSize.height && (naturalSize.height > maxSize.height)))
    {
      adaptedRectangle = adaptRectangle(
        NSMakeRect(0, 0, naturalSize.width, naturalSize.height), 
        NSMakeRect(0, 0, !maxSize.width  ? naturalSize.width : maxSize.width,
                         !maxSize.height ? naturalSize.height : maxSize.height),
        YES, NO, NO);
      adaptedRectangle.size.width  = (NSInteger)round(adaptedRectangle.size.width);
      adaptedRectangle.size.height = (NSInteger)round(adaptedRectangle.size.height);
    }
    result = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:0 pixelsWide:adaptedRectangle.size.width pixelsHigh:adaptedRectangle.size.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSCalibratedRGBColorSpace bitmapFormat:0 bytesPerRow:0 bitsPerPixel:0];
   NSImage* image = !result ? nil : [[NSImage alloc] initWithSize:adaptedRectangle.size];
   [image addRepresentation:result];
   @try{
     [image lockFocus];
     [imageRep drawInRect:adaptedRectangle];
     [image unlockFocus];
    }
    @catch(NSException* e){
      DebugLog(0, @"exception : %@", e);
    }
    if (result)
    {
      [self addRepresentation:result];
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
    NSEnumerator* enumerator = [self.representations objectEnumerator];
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
    NSEnumerator* enumerator = [self.representations objectEnumerator];
    NSImageRep* imageRep = nil;
    while (!result && (imageRep = [enumerator nextObject]))
    {
      if([imageRep isKindOfClass:[NSPDFImageRep class]])
        result = (NSPDFImageRep*)imageRep;
    }//end for each imageRep
    if (!result)
    {
      NSSize size = self.size;
      result = [self bestRepresentationForRect:NSMakeRect(0, 0, size.width, size.height) 
                                       context:context hints:nil];
      if (!result)
        result = [self newBitmapImageRepresentation];
    }//end if (!result)
  return result;
}
//end bestImageRepresentation

-(NSImage*) imageWithBackground:(NSColor*)color rounded:(CGFloat)rounded
{
  NSImage* result = self;
  if (color || rounded)
  {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGRect bounds = CGRectMake(0, 0, [self size].width, [self size].height);
    NSUInteger width = [self size].width;
    NSUInteger height = [self size].height;
    NSUInteger bytesPerRow = 16*((4*width+15)/16);
    NSUInteger bitmapBytesLength = bytesPerRow*height;
    void* bytes = isMacOS10_6OrAbove() ? 0 : calloc(bitmapBytesLength, sizeof(unsigned char));
    CGContextRef cgContext = !colorSpace || !bytesPerRow || (!bytes && !isMacOS10_6OrAbove()) ? 0 :
      CGBitmapContextCreate(bytes, width, height, 8, !bytes ? 0 : bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
    if (cgContext)
    {
      CGContextAddRoundedRect(cgContext, bounds, rounded, rounded);
      CGContextClip(cgContext);
      if (color)
      {
        NSColor* colorRGB = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
        CGFloat rgba[4] = {0};
        [colorRGB getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
        CGContextSetRGBFillColor(cgContext, rgba[0], rgba[1], rgba[2], rgba[3]);
        CGContextFillRect(cgContext, bounds);
      }//end if (color)
      
      NSGraphicsContext* oldContext = [NSGraphicsContext currentContext];
      NSGraphicsContext* newContext = [NSGraphicsContext graphicsContextWithGraphicsPort:cgContext flipped:NO];
      [NSGraphicsContext setCurrentContext:newContext];
      [self drawInRect:NSRectFromCGRect(bounds) fromRect:NSMakeRect(0, 0, [self size].width, [self size].height) operation:NSCompositeSourceOver fraction:1.0];
      [NSGraphicsContext setCurrentContext:oldContext];
    }//end if (cgContext)
    
    CGContextFlush(cgContext);
    CGImageRef cgImage = CGBitmapContextCreateImage(cgContext);
    CGContextRelease(cgContext);
    if (bytes)
      free(bytes);
    if (!cgImage){
    }
    else if (isMacOS10_6OrAbove())
      result = [[NSImage alloc] initWithCGImage:cgImage size:NSSizeFromCGSize(bounds.size)];
    else//if (!isMacOS10_6OrAbove())
    {
      NSMutableData* data = [[NSMutableData alloc] init];
      CGImageDestinationRef cgImageDestination = !data ? 0 :
        CGImageDestinationCreateWithData((CHBRIDGE CFMutableDataRef)data, CFSTR("public.png"), 1, 0);
      if (cgImageDestination && cgImage)
      {
        CGImageDestinationAddImage(cgImageDestination, cgImage, 0);
        CGImageDestinationFinalize(cgImageDestination);
        result = [[NSImage alloc] initWithData:data];
      }//end if (cgImageDestination && cgImage)
      if (cgImageDestination)
        CFRelease(cgImageDestination);
    }//end if (!isMacOS10_6OrAbove())
    CGImageRelease(cgImage);
  }//end if (color || rounded)
  return result;
}
//end imageWithBackground:rounded:

@end
