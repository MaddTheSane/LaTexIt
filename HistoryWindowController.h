//
//  HistoryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BorderlessPanel;
@class HistoryView;
@class LibraryPreviewPanelImageView;

@interface HistoryWindowController : NSWindowController {
  IBOutlet HistoryView* historyView;
  IBOutlet NSButton*    clearHistoryButton;
  
  IBOutlet BorderlessPanel*              historyPreviewPanel;
  IBOutlet LibraryPreviewPanelImageView* historyPreviewPanelImageView;
  IBOutlet NSSegmentedControl*           historyPreviewPanelSegmentedControl;

  BOOL enablePreviewImage;
}

-(HistoryView*) historyView;

-(IBAction) changeHistoryDisplayPreviewPanelState:(id)sender;

-(IBAction) clearHistory:(id)sender;

-(BOOL) canRemoveEntries;
-(void) deselectAll:(id)sender;

-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;

@end
