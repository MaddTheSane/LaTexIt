//
//  ImagePopupButton.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ImagePopupButton : NSPopUpButton {
  NSImage* image;
  BOOL isDown;
}

@property (retain) NSImage *image;

@end
