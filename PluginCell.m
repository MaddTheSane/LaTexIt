//
//  PluginCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 17/10/10.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import "PluginCell.h"


@implementation PluginCell

-(NSRect) imageFrameForCellFrame:(NSRect)cellFrame
{
  NSRect imageFrame = NSMakeRect(0, 0, cellFrame.size.height, cellFrame.size.height);
  return imageFrame;
}
//end imageFrameForCellFrame:

//NSCopying protocol
-(id) copyWithZone:(NSZone*)zone
{
  PluginCell* clone = (PluginCell*)[super copyWithZone:zone];
  return clone;
}
//end copyWithZone:

@end
