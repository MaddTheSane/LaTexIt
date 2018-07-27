//
//  HistoryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BorderlessPanel;
@class HistoryView;
@class LibraryPreviewPanelImageView;

@interface HistoryWindowController : NSWindowController {
  IBOutlet NSSearchField* historySearchField;
  IBOutlet HistoryView* historyView;
  IBOutlet NSButton*    clearHistoryButton;
  
  IBOutlet BorderlessPanel*              historyPreviewPanel;
  IBOutlet LibraryPreviewPanelImageView* historyPreviewPanelImageView;
  IBOutlet NSSegmentedControl*           historyPreviewPanelSegmentedControl;
  IBOutlet NSButton*                     historyLockButton;

  IBOutlet NSView*             importAccessoryView;
  IBOutlet NSPopUpButton*      importOptionPopUpButton;
  IBOutlet NSView*             exportAccessoryView;
  IBOutlet NSButton*           exportOnlySelectedButton;
  IBOutlet NSTextField*        exportFormatLabel;
  IBOutlet NSPopUpButton*      exportFormatPopUpButton;

  BOOL         enablePreviewImage;
  NSSavePanel* savePanel;
}

-(HistoryView*) historyView;

-(IBAction) historySearchFieldChanged:(id)sender;

-(IBAction) changeLockedState:(id)sender;
-(IBAction) changeHistoryDisplayPreviewPanelState:(id)sender;

-(IBAction) clearHistory:(id)sender;
-(IBAction) open:(id)sender;
-(IBAction) saveAs:(id)sender;

-(IBAction) changeHistoryExportFormat:(id)sender;

-(BOOL) canRemoveEntries;
-(void) deselectAll:(id)sender;

-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;

@end
