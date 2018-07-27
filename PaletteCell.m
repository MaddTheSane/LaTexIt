//
//  PaletteCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.


//this sub-class of NSImageCell draws the image in the half of the frame

#import "PaletteCell.h"


@implementation PaletteCell

-(void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  NSPoint origin = cellFrame.origin;
  NSSize size = cellFrame.size;
  NSSize imageSize = [[self image] size];
  float ratio = imageSize.width/imageSize.height;
  NSRect insideRect = NSMakeRect(origin.x, origin.y, size.width/2, size.height/2);
  if (ratio <= 1) //width <= height
    insideRect.size.width *= ratio;
  else //width > height
    insideRect.size.height /= ratio;
  insideRect.origin = NSMakePoint(origin.x+(cellFrame.size.width-insideRect.size.width)/2,
                                  origin.y+(cellFrame.size.height-insideRect.size.height)/2);
  if ([self isHighlighted])
  {
    [[NSColor colorWithCalibratedRed:181./255. green:213./255. blue:255./255. alpha:1] set];
    NSRectFill(cellFrame);
  }
  return [super drawInteriorWithFrame:insideRect inView:controlView];
}

@end
