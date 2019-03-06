//
//  NSButtonPalette.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/10.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol NSButtonPaletteDelegate;

@interface NSButtonPalette : NSObject {
  NSMutableArray<NSButton*>* buttons;
  BOOL isExclusive;
  id<NSButtonPaletteDelegate> __weak delegate;
}

@property (getter=isExclusive) BOOL exclusive;
-(void) add:(NSButton*)button;
-(void) remove:(NSButton*)button;
-(NSButton*) buttonWithTag:(NSInteger)tag;
-(NSButton*) buttonWithState:(NSInteger)state;
@property NSInteger selectedTag;

@property (weak) id<NSButtonPaletteDelegate> delegate;
-(void) buttonPalette:(NSButtonPalette*)buttonPalette buttonStateChanged:(NSButton*)button;

@end

@protocol NSButtonPaletteDelegate <NSObject>
@required
-(void) buttonPalette:(NSButtonPalette*)buttonPalette buttonStateChanged:(NSButton*)button;

@end

