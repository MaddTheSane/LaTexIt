//
//  ImageAndTextCell.h
//  MozoDojo
//
//  Created by Pierre Chatelier on 12/10/06.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ImageAndTextCell : NSTextFieldCell <NSCopying> {
  NSImage* image;
}

-(NSImage*) image;
-(void)     setImage:(NSImage*)image;

-(void) drawWithFrame:(NSRect)cellFrame inView:(NSView*)controlView;
-(NSSize) cellSize;

//protocol NSCopying
-(id) copyWithZone:(NSZone*)zone;

@end
