//  LibraryCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The LibraryCell is the kind of cell displayed in the NSOutlineView of the Library drawer
//It contains an image and a text. It is a copy of the ImageAndTextCell provided by Apple
//in the developer documentation

#import "LibraryCell.h"

@implementation LibraryCell

-(void) dealloc
{
  [image release];
  image = nil;
  [super dealloc];
}

-(id) copyWithZone:(NSZone *)zone
{
  LibraryCell* cell = (LibraryCell*) [super copyWithZone:zone];
  if (cell)
    cell->image = [image retain];
  return cell;
}

-(void) setImage:(NSImage*)anImage
{
  [anImage retain];
  [image release];
  image = anImage;
}

-(NSImage*) image
{
  return image;
}

-(NSRect) imageFrameForCellFrame:(NSRect)cellFrame
{
  NSRect rect = NSZeroRect;
  if (image)
  {
    rect.size = [image size];
    rect.origin = cellFrame.origin;
    rect.origin.x += 3;
    rect.origin.y += ceil((cellFrame.size.height - rect.size.height) / 2);
  }
  return rect;
}

-(void) editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
  NSRect textFrame, imageFrame;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
  [super editWithFrame: textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}

-(void) selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
  NSRect textFrame, imageFrame;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
  [super selectWithFrame: textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  if (image)
  {
    NSSize	imageSize;
    NSRect	imageFrame;
    
    imageSize = [image size];
    NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
    if ([self drawsBackground])
    {
      [[self backgroundColor] set];
      NSRectFill(imageFrame);
    }
    imageFrame.origin.x += 3;
    imageFrame.size = imageSize;
    
    if ([controlView isFlipped])
      imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
    else
      imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
    
    [image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
  }
  [super drawWithFrame:cellFrame inView:controlView];
}

-(NSSize) cellSize
{
  NSSize cellSize = [super cellSize];
  cellSize.width += (image ? [image size].width : 0) + 3;
  return cellSize;
}

-(void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  cellFrame.origin.x += 8;
  [super drawInteriorWithFrame:cellFrame inView:controlView];
}

@end
