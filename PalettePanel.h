//
//  PalettePanel.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/11/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PalettePanel : NSPanel {
  NSSize defaultMinSize;
  NSSize defaultMaxSize;
}

-(void) becomeKeyWindow;
-(void) resignKeyWindow;

@end
