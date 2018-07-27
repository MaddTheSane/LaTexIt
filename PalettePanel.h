//
//  PalettePanel.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/11/09.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PalettePanel : NSPanel {
  NSSize defaultMinSize;
  NSSize defaultMaxSize;
}

-(void) becomeKeyWindow;
-(void) resignKeyWindow;

@end
