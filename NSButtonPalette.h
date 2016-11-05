//
//  NSButtonPalette.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/10.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSButtonPalette : NSObject {
  NSMutableArray* buttons;
  BOOL isExclusive;
  id delegate;
}

@property (getter=isExclusive) BOOL exclusive;
-(void) add:(NSButton*)button;
-(void) remove:(NSButton*)button;
-(NSButton*) buttonWithTag:(NSInteger)tag;
-(NSButton*) buttonWithState:(NSInteger)state;

@property (assign) id delegate;
-(void) buttonPalette:(NSButtonPalette*)buttonPalette buttonStateChanged:(NSButton*)button;

@end
