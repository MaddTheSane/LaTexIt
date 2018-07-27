//
//  ImageAndTextCell.h
//  MozoDojo
//
//  Created by Pierre Chatelier on 12/10/06.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "ImageAndTextCell.h"

#import "NSImageExtended.h"

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
    clone->image = [self->image retain];
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

-(void) setImageBackgroundColor:(NSColor*)anImageBackgroundColor
{
  [anImageBackgroundColor retain];
  [self->imageBackgroundColor release];
  self->imageBackgroundColor = anImageBackgroundColor;
}
//end setImage:

-(NSColor*) imageBackgroundColor
{
  return self->imageBackgroundColor;
}
//end imageBackgroundColor

-(NSRect) imageFrameForCellFrame:(NSRect)cellFrame
{
  NSRect imageFrame = NSZeroRect;
  if (self->image)
  {
    imageFrame.size = [self->image size];
    imageFrame.origin = cellFrame.origin;
    imageFrame.origin.x += 3;
    imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
  }
  return imageFrame;
}
//end imageFrameForCellFrame:

-(void) editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
  NSRect textFrame  = NSZeroRect;
  NSRect imageFrame = NSZeroRect;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [self->image size].width, NSMinXEdge);
  [super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event:theEvent];
}
//end editWithFrame:inView:editor:delegate:event:

-(void) selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
  NSRect textFrame  = NSZeroRect;
  NSRect imageFrame = NSZeroRect;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [self->image size].width, NSMinXEdge);
  [super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}
//end selectWithFrame:inView:editor:delegate:start:length:

-(void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
  NSRect imageFrame = NSZeroRect;
  NSRect textFrame  = NSZeroRect;
  NSSize imageSize = [self->image size];
  NSDivideRect(cellFrame, &imageFrame, &textFrame, 3 + imageSize.width, NSMinXEdge);
  if (self->image)
  {
    imageFrame.origin.x += 3;
    imageFrame.size = imageSize;
    
    if (imageFrame.size.height <= textFrame.size.height)
      imageFrame.origin.y += (textFrame.size.height-imageFrame.size.height)/2;
    else
    {
      CGFloat aspectRatio = !imageFrame.size.height ? 0 : imageFrame.size.width/imageFrame.size.height;
      imageFrame.size.height = textFrame.size.height;
      imageFrame.size.width = aspectRatio*imageFrame.size.height;
    }

    if (self->imageBackgroundColor)
    {
      [self->imageBackgroundColor set];
      NSRectFill(imageFrame);
    }
    [NSGraphicsContext saveGraphicsState];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    NSAffineTransform* transform = [NSAffineTransform transform];
    [transform translateXBy:imageFrame.origin.x yBy:imageFrame.origin.y];
    [transform translateXBy:0 yBy:imageFrame.size.height/2];
    [transform scaleXBy:1.f yBy:[self->image isFlipped] ^ [controlView isFlipped] ? -1.f : 1.f];
    [transform translateXBy:0 yBy:-imageFrame.size.height/2];
    [transform concat];
    NSImage* wrapImage = [[NSImage alloc] initWithSize:imageSize];
    [wrapImage addRepresentation:[self->image bestRepresentationForDevice:nil]];
    [wrapImage drawInRect:NSMakeRect(0.f, 0.f, imageFrame.size.width, imageFrame.size.height)
                   fromRect:NSMakeRect(0.f, 0.f, imageSize.width, imageSize.height)
                  operation:NSCompositeSourceOver fraction:1.0f];
    [wrapImage release];
    [NSGraphicsContext restoreGraphicsState];
  }//end if image
  
  [super drawWithFrame:textFrame inView:controlView];
}
//end drawWithFrame:inView:

-(NSSize) cellSize
{
  NSSize cellSize = [super cellSize];
  cellSize.width += (self->image ? [self->image size].width : 0) + 3;
  return cellSize;
}
//end cellSize

@end
