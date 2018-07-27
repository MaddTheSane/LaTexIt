//
//  HistoryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BorderlessPanel;
@class HistoryTableView;
@class LibraryPreviewPanelImageView;

@interface HistoryController : NSWindowController {
  IBOutlet HistoryTableView* historyTableView;
  IBOutlet NSButton* clearHistoryButton;
  
  IBOutlet BorderlessPanel*              historyPreviewPanel;
  IBOutlet LibraryPreviewPanelImageView* historyPreviewPanelImageView;
  IBOutlet NSSegmentedControl*           historyPreviewPanelSegmentedControl;
  BOOL     enablePreviewImage;
}

-(IBAction) removeHistoryEntries:(id)sender;
-(IBAction) clearHistory:(id)sender;

-(BOOL) canRemoveEntries;
-(void) deselectAll:(id)sender;

-(void) setEnablePreviewImage:(BOOL)status;
-(IBAction) changeHistoryPreviewPanelSegmentedControl:(id)sender;
-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;

@end
