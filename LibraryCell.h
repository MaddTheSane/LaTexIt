//  LibraryCell.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.

//The LibraryCell is the kind of cell displayed in the NSOutlineView of the Library drawer
//It contains an image and a text. It is a copy of the ImageAndTextCell provided by Apple
//in the developer documentation

#import <Cocoa/Cocoa.h>

#import "ImageAndTextCell.h"

@interface LibraryCell : ImageAndTextCell <NSCopying> {
  NSColor* textBackgroundColor;
}

-(NSColor*) textBackgroundColor;
-(void) setTextBackgroundColor:(NSColor*)color;

-(void) editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent;
-(void) selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength;
-(void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;

@end
