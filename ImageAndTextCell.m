//
//  ImageAndTextCell.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 12/10/06.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import "ImageAndTextCell.h"

#import "NSImageExtended.h"
#import "Utils.h"

@interface ImageAndTextCell ()
-(NSRect) imageFrameForCellFrame:(NSRect)cellFrame relativeToCellOrigin:(BOOL)relativeToCellOrigin;
@end

@implementation ImageAndTextCell

-(void) dealloc
{
  [self->image release];
  [self->imageBackgroundColor release];
  [super dealloc];
}
//end dealloc

//NSCopying protocol
-(id) copyWithZone:(NSZone*)zone
{
  ImageAndTextCell* clone = (ImageAndTextCell*) [super copyWithZone:zone];
  if (clone)
  {
    clone->image = [self->image retain];
    clone->imageBackgroundColor = [self->imageBackgroundColor copy];
  }//end if (clone)
  return clone;
}
//end copyWithZone:

-(void) setImage:(NSImage*)anImage
{
  [anImage retain];
  [self->image release];
  self->image = anImage;
}
//end setImage:

-(NSImage*) image
{
  return self->image;
}
//end image

-(void) setImageBackgroundColor:(NSColor*)value
{
  [value retain];
  [self->imageBackgroundColor release];
  self->imageBackgroundColor = value;
}
//end setImageBackgroundColor:

-(NSColor*) imageBackgroundColor
{
  return self->imageBackgroundColor;
}
//end imageBackgroundColor

-(NSRect) imageFrameForCellFrame:(NSRect)cellFrame relativeToCellOrigin:(BOOL)relativeToCellOrigin
{
  NSRect result = relativeToCellOrigin ?
                    NSMakeRect(0, 0, 0, cellFrame.size.height) :
                    NSMakeRect(cellFrame.origin.x, cellFrame.origin.y, 0, cellFrame.size.height);
  result.origin.x += 3;
  if (self->image)
  {
    NSSize imageSize = [self->image size];
    NSRect imageRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);
    imageRect = adaptRectangle(imageRect, cellFrame, YES, NO, NO);
    result.origin.y = imageRect.origin.y;
    result.size = imageRect.size;
  }//end if (self->image)
  return result;
}
//end imageFrameForCellFrame:relativeToCellOrigin:

-(void) editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
  NSRect textFrame  = NSZeroRect;
  NSRect imageFrame = NSZeroRect;
  NSDivideRect(aRect, &imageFrame, &textFrame, NSMaxX([self imageFrameForCellFrame:aRect relativeToCellOrigin:YES]), NSMinXEdge);
  CGFloat delta = (!self->image ? 0 : 3);
  textFrame.origin.x += delta;
  textFrame.size.width = MAX(0, textFrame.size.width-delta);
  NSAttributedString* attributedString = [self attributedStringValue];
  if (attributedString)
  {
    NSSize textSize = [attributedString size];
    NSRect verticallyCenteredTextFrame = adaptRectangle(NSMakeRect(0, 0, textSize.width, textSize.height), textFrame, YES, NO, NO);
    verticallyCenteredTextFrame.origin.x = textFrame.origin.x;
    verticallyCenteredTextFrame.size.width = textFrame.size.width;
    textFrame = verticallyCenteredTextFrame;
  }//end if (attributedString)
  [super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event:theEvent];
}
//end editWithFrame:inView:editor:delegate:event:

-(void) selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength
{
  NSRect textFrame  = NSZeroRect;
  NSRect imageFrame = NSZeroRect;
  NSDivideRect(aRect, &imageFrame, &textFrame, NSMaxX([self imageFrameForCellFrame:aRect relativeToCellOrigin:YES]), NSMinXEdge);
  CGFloat delta = (!self->image ? 0 : 3);
  textFrame.origin.x += delta;
  textFrame.size.width = MAX(0, textFrame.size.width-delta);
  NSAttributedString* attributedString = [self attributedStringValue];
  if (attributedString)
  {
    NSSize textSize = [attributedString size];
    NSRect verticallyCenteredTextFrame = adaptRectangle(NSMakeRect(0, 0, textSize.width, textSize.height), textFrame, YES, NO, NO);
    verticallyCenteredTextFrame.origin.x = textFrame.origin.x;
    verticallyCenteredTextFrame.size.width = textFrame.size.width;
    textFrame = verticallyCenteredTextFrame;
  }//end if (attributedString)
  [super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}
//end selectWithFrame:inView:editor:delegate:start:length:

-(void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
  NSRect imageFrame = NSZeroRect;
  NSRect textFrame  = NSZeroRect;
  NSSize imageSize = [self->image size];
  NSDivideRect(cellFrame, &imageFrame, &textFrame, NSMaxX([self imageFrameForCellFrame:cellFrame relativeToCellOrigin:YES]), NSMinXEdge);
  imageFrame = [self imageFrameForCellFrame:cellFrame relativeToCellOrigin:NO];
  CGFloat delta = (!self->image ? 0 : 3);
  textFrame.origin.x += delta;
  textFrame.size.width = MAX(0, textFrame.size.width-delta);
  if (self->image)
  {
    if (self->imageBackgroundColor)
    {
      [self->imageBackgroundColor set];
      NSRectFill(imageFrame);
    }//end if (self->imageBackgroundColor)
    [NSGraphicsContext saveGraphicsState];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    NSAffineTransform* transform = [NSAffineTransform transform];
    [transform translateXBy:imageFrame.origin.x yBy:imageFrame.origin.y];
    [transform translateXBy:0 yBy:imageFrame.size.height/2];
    //[transform scaleXBy:1.f yBy:[self->image isFlipped] ^ [controlView isFlipped] ? -1.f : 1.f];
    [transform scaleXBy:1.f yBy:[controlView isFlipped] ? -1.f : 1.f];
    [transform translateXBy:0 yBy:-imageFrame.size.height/2];
    [transform concat];
    NSImage* wrapImage = [[NSImage alloc] initWithSize:imageSize];
    [wrapImage addRepresentation:[self->image bestImageRepresentationInContext:[NSGraphicsContext currentContext]]];
    [wrapImage drawInRect:NSMakeRect(0.f, 0.f, imageFrame.size.width, imageFrame.size.height)
                   fromRect:NSMakeRect(0.f, 0.f, imageSize.width, imageSize.height)
                  operation:NSCompositeSourceOver fraction:1.0f];
    [wrapImage release];
    [NSGraphicsContext restoreGraphicsState];
  }//end if image
  
  NSAttributedString* attributedString = [self attributedStringValue];
  if (attributedString)
  {
    NSSize textSize = [attributedString size];
    NSRect verticallyCenteredTextFrame = adaptRectangle(NSMakeRect(0, 0, textSize.width, textSize.height), textFrame, YES, NO, NO);
    verticallyCenteredTextFrame.origin.x = textFrame.origin.x;
    verticallyCenteredTextFrame.size.width = textFrame.size.width;
    textFrame = verticallyCenteredTextFrame;
  }//end if (attributedString)
  [super drawWithFrame:textFrame inView:controlView];
}
//end drawWithFrame:inView:

@end
