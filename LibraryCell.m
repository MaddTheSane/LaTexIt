//  LibraryCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//The LibraryCell is the kind of cell displayed in the NSOutlineView of the Library drawer
//It contains an image and a text. It is a copy of the ImageAndTextCell provided by Apple
//in the developer documentation

#import "LibraryCell.h"

#import "LibraryView.h"
#import "NSImageExtended.h"
#import "NSObjectExtended.h"

#import "CGExtras.h"
#import "Utils.h"

@implementation LibraryCell

-(instancetype) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  self->textBackgroundColor = nil;//there may be no color
  return self;
}
//end initWithCoder:

-(id) copyWithZone:(NSZone*)zone
{
  LibraryCell* cell = (LibraryCell*) [super copyWithZone:zone];
  if (cell)
    cell->textBackgroundColor = [self->textBackgroundColor copy];
  return cell;
}
//end copyWithZone:

-(void) setTextBackgroundColor:(NSColor*)color
{
  self->textBackgroundColor = color;
}
//end setTextBackgroundColor:

-(NSColor*) textBackgroundColor
{
  return self->textBackgroundColor;
}
//end textBackgroundColor

-(void) editWithFrame:(NSRect)aRect inView:(NSView*)controlView editor:(NSText*)textObj delegate:(id)anObject event:(NSEvent*)theEvent
{
  LibraryView* libraryTableView = [controlView dynamicCastToClass:[LibraryView class]];
  if (libraryTableView)
  {
    library_row_t libraryRowType = libraryTableView.libraryRowType;
    if ((libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT) || (aRect.size.height < 30))
      [super editWithFrame:aRect inView:controlView editor:textObj delegate:anObject event: theEvent];
  }//end if (libraryTableView)
}
//end editWithFrame:inView:editor:delegate:event:

-(void) selectWithFrame:(NSRect)aRect inView:(NSView*)controlView editor:(NSText*)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
  LibraryView* libraryTableView = [controlView dynamicCastToClass:[LibraryView class]];
  if (libraryTableView)
  {
    library_row_t libraryRowType = libraryTableView.libraryRowType;
    if ((libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT) || (aRect.size.height < 30))
      [super selectWithFrame:aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
  }//end if (libraryTableView)
}
//end selectWithFrame:inView:editor:delegate:start:length

-(void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  LibraryView* libraryTableView = [controlView dynamicCastToClass:[LibraryView class]];
  if (libraryTableView)
  {
    library_row_t libraryRowType = libraryTableView.libraryRowType;
    if ((libraryRowType == LIBRARY_ROW_IMAGE_LARGE) || (libraryRowType == LIBRARY_ROW_IMAGE_ADJUST))
    {
      BOOL saveDrawsBackground = self.drawsBackground;
      [self setDrawsBackground:NO];
      [super drawInteriorWithFrame:cellFrame inView:controlView]; //the image is displayed in a subrect of the cell
      self.drawsBackground = saveDrawsBackground;
    }//end if ((libraryRowType == LIBRARY_ROW_IMAGE_LARGE) || (libraryRowType == LIBRARY_ROW_IMAGE_ADJUST))
    else if (libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT)
    {
      CGFloat pillCorner = cellFrame.size.height/2;
      CGRect pillRect = CGRectZero;
      /*if (![self isHighlighted])
        pillRect = CGRectMake(cellFrame.origin.x, cellFrame.origin.y, cellFrame.size.width-pillCorner, cellFrame.size.height);
      else*/
        pillRect = CGRectMake(NSMaxX(cellFrame)-2*pillCorner, cellFrame.origin.y, 2*pillCorner, cellFrame.size.height);

      //if ([self isHighlighted])
      {
        BOOL saveDrawsBackground = self.drawsBackground;
        [self setDrawsBackground:NO];
        [super drawInteriorWithFrame:cellFrame inView:controlView];
        self.drawsBackground = saveDrawsBackground;
      }//end if (![self isHighlighted])

      if (self->textBackgroundColor)
      {
        CGContextRef cgContext = [NSGraphicsContext currentContext].graphicsPort;

        NSColor* rgbaColor = [self->textBackgroundColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
        CGFloat hsba[4] = {rgbaColor.hueComponent, rgbaColor.saturationComponent, rgbaColor.brightnessComponent, rgbaColor.alphaComponent};
        hsba[1] = MIN(1., 0.5*hsba[1]);
        hsba[2] = MIN(1., 1.5*hsba[2]);
        NSColor* lighterColor = [NSColor colorWithCalibratedHue:hsba[0] saturation:hsba[1] brightness:hsba[2] alpha:hsba[3]];
        
        CGFloat rgba[4] = {0};
        CGFloat lighterRgba[4] = {0};
        [rgbaColor    getRed:&rgba[0]        green:&rgba[1]        blue:&rgba[2]        alpha:&rgba[3]];
        [lighterColor getRed:&lighterRgba[0] green:&lighterRgba[1] blue:&lighterRgba[2] alpha:&lighterRgba[3]];
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGColorRef color1 = CGColorCreate(colorSpace, lighterRgba);
        CGColorRef color2 = CGColorCreate(colorSpace, rgba);
        CGColorRef colors[2] = {color1, color2};
        CGBlendColorsRef blendColors = CGBlendColorsCreate(colors, 2, &CGBlendLinear, 0);
        const CGFloat domainAndRange[8] = {0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0};
        CGFunctionRef blendFunction = CGFunctionCreate(blendColors, 1, domainAndRange, 4, domainAndRange, &CGBlendColorsFunctionCallBacks);
        
        CGContextSaveGState(cgContext);

        CGContextBeginPath(cgContext);
        /*if (![self isHighlighted])
          CGContextAddRoundedRect(cgContext, pillRect, pillCorner, pillCorner);
        else*/
          CGContextAddEllipseInRect(cgContext, pillRect);
        
        CGContextClip(cgContext);
        CGShadingRef cgShading = CGShadingCreateAxial(colorSpace,
          pillRect.origin, CGPointMake(pillRect.origin.x, pillRect.origin.y+pillRect.size.height),
          blendFunction, NO, NO);
        CGContextDrawShading(cgContext, cgShading);
        CGContextRestoreGState(cgContext);      
        CGShadingRelease(cgShading);
        CGFunctionRelease(blendFunction);
        CGColorSpaceRelease(colorSpace);
      }//end if (self->textBackgroundColor)
      
      /*if (![self isHighlighted])
      {
        BOOL saveDrawsBackground = [self drawsBackground];
        [self setDrawsBackground:NO];
        [super drawInteriorWithFrame:cellFrame inView:controlView];
        [self setDrawsBackground:saveDrawsBackground];
      }//end if ([self isHighlighted])*/
    }//end if (libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT)
  }//end if (libraryView)
}
//end drawInteriorWithFrame:inView:

@end
