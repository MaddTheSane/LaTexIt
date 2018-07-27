//
//  MySplitView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 12/06/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "MySplitView.h"


@implementation MySplitView

-(CGFloat) dividerThickness
{
  CGFloat result = self->isCustomThickness ? self->thickness : [super dividerThickness];
  return result;
}
//end dividerThickness

-(void) setDividerThickness:(CGFloat)value
{
  self->thickness = value;
  self->isCustomThickness = (value >= 0);
  if ((value <=0) && [self respondsToSelector:@selector(setPosition:ofDividerAtIndex:)])
    [self setPosition:0 ofDividerAtIndex:0];
  [self setNeedsDisplay:YES];
}
//end setDividerThickness:

@end
