//
//  DragFilterWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/10.
//  Copyright 2010 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class DragFilterView;
@class NSButtonPalette;

@interface DragFilterWindowController : NSWindowController {
  IBOutlet DragFilterView* dragFilterView;
  IBOutlet NSTextField* dragFilterViewLabel;
  IBOutlet NSView* dragFilterButtonsView;
  NSButtonPalette* buttonPalette;
  NSTimeInterval animationDurationIn;
  NSTimeInterval animationDurationOut;
  NSDate* animationStartDate;
  NSTimer* animationTimer;
  NSPoint fromFrameOrigin;
  NSPoint toFrameOrigin;
  id delegate;
}

-(void) setWindowVisible:(BOOL)visible withAnimation:(BOOL)animate;
-(void) setWindowVisible:(BOOL)visible withAnimation:(BOOL)animate atPoint:(NSPoint)point;

-(id) delegate;
-(void) setDelegate:(id)value;

-(void) dragFilterWindowController:(DragFilterWindowController*)dragFilterWindowController exportFormatDidChange:(export_format_t)exportFormat;

@end
