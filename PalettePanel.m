//
//  PalettePanel.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/11/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "PalettePanel.h"


@implementation PalettePanel

-(void) awakeFromNib
{
  self->defaultMinSize = self.minSize;
  self->defaultMaxSize = self.maxSize;  
}
//end awakeFromNib

-(void) becomeKeyWindow
{
  [super becomeKeyWindow];
  self.minSize = self->defaultMinSize;
  self.maxSize = self->defaultMaxSize;
}
//end becomeKeyWindow

-(void) resignKeyWindow
{
  [super resignKeyWindow];
  NSSize currentSize = self.frame.size;
  self.minSize = currentSize;
  self.maxSize = currentSize;
}
//end resignKeyWindow

@end
