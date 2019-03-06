//
//  ImageAndTextCell.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 12/10/06.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ImageAndTextCell : NSTextFieldCell <NSCopying> {
  NSImage* image;
  NSColor* imageBackgroundColor;
}

-(NSImage*) image;
-(void)     setImage:(NSImage*)image;

-(NSColor*) imageBackgroundColor;
-(void) setImageBackgroundColor:(NSColor*)color;

-(void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView;

//protocol NSCopying
-(id) copyWithZone:(NSZone*)zone;

@end
