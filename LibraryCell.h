//  LibraryCell.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The LibraryCell is the kind of cell displayed in the NSOutlineView of the Library drawer
//It contains an image and a text. It is a copy of the ImageAndTextCell provided by Apple
//in the developer documentation

#import <Cocoa/Cocoa.h>

@interface LibraryCell : NSTextFieldCell <NSCopying> {
  NSImage	*image;
}

- (void)setImage:(NSImage *)anImage;
- (NSImage *)image;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

@end
