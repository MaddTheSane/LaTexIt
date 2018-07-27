//
//  ImageAndTextCell.h
//  MozoDojo
//
//  Created by Pierre Chatelier on 12/10/06.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "ImageAndTextCell.h"

#import <Quartz/Quartz.h>

@implementation ImageAndTextCell

-(void) dealloc
{
  [image release];
  [super dealloc];
}
//end dealloc

//NSCopying protocol
-(id) copyWithZone:(NSZone*)zone
{
  ImageAndTextCell* clone = (ImageAndTextCell*) [super copyWithZone:zone];
  clone->image = [image retain];
  return clone;
}
//end copyWithZone:

-(void) setImage:(NSImage*)anImage
{
  [anImage retain];
  [image release];
  image = anImage;
}
//end setImage:

-(NSImage*) image
{
  return image;
}
//end image

-(NSRect) imageFrameForCellFrame:(NSRect)cellFrame
{
  NSRect imageFrame = NSZeroRect;
  if (image)
  {
    imageFrame.size = [image size];
    imageFrame.origin = cellFrame.origin;
    imageFrame.origin.x += 3;
    imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
  }
  return imageFrame;
}
//end imageFrameForCellFrame:

-(void) editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
  NSRect textFrame, imageFrame;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
  [super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event:theEvent];
}
//end editWithFrame:inView:editor:delegate:event:

-(void) selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
  NSRect textFrame, imageFrame;
  NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
  [super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}
//end selectWithFrame:inView:editor:delegate:start:length:

-(void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
  if (image)
  {
    NSRect imageFrame = NSZeroRect;
    NSSize imageSize = [image size];
    NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
    if ([self drawsBackground])
    {
      [[self backgroundColor] set];
      NSRectFill(imageFrame);
    }
    imageFrame.origin.x += 3;
    imageFrame.size = imageSize;
    
    if (imageFrame.size.height > cellFrame.size.height)
    {
      float aspectRatio = imageFrame.size.height ? imageFrame.size.width/imageFrame.size.height : 0;
      imageFrame.size.height = cellFrame.size.height;
      imageFrame.size.width = aspectRatio*imageFrame.size.height;
    }
    [image setFlipped:[controlView isFlipped]];
    [image drawInRect:imageFrame fromRect:NSMakeRect(0, 0, imageSize.width, imageSize.height) operation:NSCompositeSourceOver fraction:1.0];
  }//end if image

  //modifies the cellFrame to center the text vertically
  float textHeight = [[self font] capHeight];
  cellFrame.origin.y += (cellFrame.size.height-textHeight)/4;
  cellFrame.size.height -= (cellFrame.size.height-textHeight)/4;

  [super drawWithFrame:cellFrame inView:controlView];
}
//end drawWithFrame:inView:

-(NSSize) cellSize
{
  NSSize cellSize = [super cellSize];
  cellSize.width += (image ? [image size].width : 0) + 3;
  return cellSize;
}
//end cellSize

@end
