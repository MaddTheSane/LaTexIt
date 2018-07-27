//
//  PalettePanel.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/11/09.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.
//

#import "PalettePanel.h"


@implementation PalettePanel

-(void) awakeFromNib
{
  self->defaultMinSize = [self minSize];
  self->defaultMaxSize = [self maxSize];  
}
//end awakeFromNib

-(void) becomeKeyWindow
{
  [super becomeKeyWindow];
  [self setMinSize:self->defaultMinSize];
  [self setMaxSize:self->defaultMaxSize];
}
//end becomeKeyWindow

-(void) resignKeyWindow
{
  [super resignKeyWindow];
  NSSize currentSize = [self frame].size;
  [self setMinSize:currentSize];
  [self setMaxSize:currentSize];
}
//end resignKeyWindow

@end
