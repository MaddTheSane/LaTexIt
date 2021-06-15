//
//  DragFilterWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/10.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class DragThroughButton;
@class DragFilterView;
@class NSButtonPalette;

@interface DragFilterWindowController : NSWindowController {
  IBOutlet DragThroughButton* closeButton;
  IBOutlet DragFilterView* dragFilterView;
  IBOutlet NSTextField* dragFilterViewLabel;
  IBOutlet NSView* dragFilterButtonsView;
  NSButtonPalette* buttonPalette;
  DragThroughButton* addTempFileButton;
  NSTimeInterval animationDurationIn;
  NSTimeInterval animationDurationOut;
  NSDate* animationStartDate;
  CGFloat animationStartAlphaValue;
  NSTimer* animationTimer;
  NSPoint fromFrameOrigin;
  NSPoint toFrameOrigin;
  id delegate;
}

-(void) setWindowVisible:(BOOL)visible withAnimation:(BOOL)animate;
-(void) setWindowVisible:(BOOL)visible withAnimation:(BOOL)animate atPoint:(NSPoint)point;
-(void) setWindowVisible:(BOOL)visible withAnimation:(BOOL)animate atPoint:(NSPoint)point isHintOnly:(BOOL)isHintOnly;

-(export_format_t) exportFormat;
-(void) setExportFormat:(export_format_t)value;

-(id) delegate;
-(void) setDelegate:(id)value;

-(void) dragFilterWindowController:(DragFilterWindowController*)dragFilterWindowController exportFormatDidChange:(export_format_t)exportFormat;

@end
