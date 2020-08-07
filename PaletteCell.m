//
//  PaletteCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.


//this sub-class of NSImageCell draws the image in the half of the frame

#import "PaletteCell.h"

#import "NSObjectExtended.h"

@implementation PaletteCell

-(void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView*)controlView
{
  NSPoint origin = cellFrame.origin;
  NSSize size = cellFrame.size;
  NSSize imageSize = [[self image] size];
  CGFloat ratio = imageSize.width/imageSize.height;
  NSRect insideRect = NSMakeRect(origin.x, origin.y, size.width/2, size.height/2);
  if (ratio <= 1) //width <= height
    insideRect.size.width *= ratio;
  else //width > height
    insideRect.size.height /= ratio;
  insideRect.origin = NSMakePoint(origin.x+(cellFrame.size.width-insideRect.size.width)/2,
                                  origin.y+(cellFrame.size.height-insideRect.size.height)/2);
  if ([self isHighlighted])
  {
    [[NSColor  selectedTextBackgroundColor] set];
    //[[NSColor colorWithCalibratedRed:181./255. green:213./255. blue:255./255. alpha:1] set];
    NSRectFill(cellFrame);
  }//end if ([self isHighlighted])
  else if ([controlView isDarkMode])
  {
    static const CGFloat gray1 = .45f;
    static const CGFloat rgba1[4] = {gray1, gray1, gray1, 1.f};
    [[NSColor colorWithCalibratedRed:rgba1[0] green:rgba1[1] blue:rgba1[2] alpha:rgba1[3]] set];
    NSRectFill(cellFrame);
  }//end if ([controlView isDarkMode])

  [super drawInteriorWithFrame:insideRect inView:controlView];
}
//end drawInteriorWithFrame:inView:

@end
