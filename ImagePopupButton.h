//
//  ImagePopupButton.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ImagePopupButton : NSPopUpButton {
  NSImage* image;
  BOOL isDown;
}

-(void) setImage:(NSImage*)image;
-(NSImage*) image;

@end