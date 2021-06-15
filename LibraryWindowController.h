//
//  LibraryWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BorderlessPanel;
@class ImagePopupButton;
@class LibraryEquation;
@class LibraryView;
@class LibraryPreviewPanelImageView;

@interface LibraryWindowController : NSWindowController <NSTableViewDelegate, NSTextViewDelegate> {
  IBOutlet NSSearchField*                librarySearchField;
  IBOutlet NSButton*                     importCurrentButton;
  IBOutlet ImagePopupButton*             actionButton;
  IBOutlet LibraryView*                  libraryView;
  IBOutlet NSSegmentedControl*           libraryRowTypeSegmentedControl;
  IBOutlet BorderlessPanel*              libraryPreviewPanel;
  IBOutlet LibraryPreviewPanelImageView* libraryPreviewPanelImageView;
  IBOutlet NSSegmentedControl*           libraryPreviewPanelSegmentedControl;
  
  IBOutlet NSView*             importAccessoryView;
  IBOutlet NSButton*           importHomeButton;
  IBOutlet NSPopUpButton*      importOptionPopUpButton;
  IBOutlet NSView*             exportAccessoryView;
  IBOutlet NSButton*           exportOnlySelectedButton;
  IBOutlet NSTextField*        exportFormatLabel;
  IBOutlet NSPopUpButton*      exportFormatPopUpButton;
  
  IBOutlet NSButton* exportOptionCommentedPreamblesButton;
  IBOutlet NSButton* exportOptionUserCommentsButton;
  IBOutlet NSButton* exportOptionIgnoreTitleHierarchyButton;
  
  IBOutlet NSDrawer* commentDrawer;
  IBOutlet NSView* commentView;
  IBOutlet NSTextField* commentTextField;
  IBOutlet NSTextView* commentTextView;
  IBOutlet NSNumberFormatter* commentSizeFormatter;

  IBOutlet NSPanel*     importTeXPanel;
  IBOutlet NSButton*    importTeXPanelInlineCheckBox;
  IBOutlet NSButton*    importTeXPanelDisplayCheckBox;
  IBOutlet NSButton*    importTeXPanelAlignCheckBox;
  IBOutlet NSButton*    importTeXPanelEqnarrayCheckBox;
  IBOutlet NSTableView* importTeXPanelTableView;
  IBOutlet NSButton*    importTeXImportButton;
  IBOutlet NSButton*    importTeXCancelButton;
  IBOutlet NSWindow*    relatexizeWindow;
  IBOutlet NSTextField* relatexizeProgressTextField;
  IBOutlet NSProgressIndicator* relatexizeProgressIndicator;
  IBOutlet NSButton* relatexizeAbortButton;
  
  BOOL              enablePreviewImage;  
  NSSavePanel*      savePanel;
  
  NSArrayController* importTeXArrayController;
  NSDictionary*      importTeXOptions;
  NSInteger updateLevel;
  NSTimer* relatexizeTimer;
  NSConditionLock* relatexizeMonitor;
  volatile BOOL relatexizeAbortMonitor;
  volatile NSUInteger relatexizeCurrentIndex;
  volatile NSUInteger relatexizeCurrentCount;
}

-(IBAction) changeLibraryDisplayPreviewPanelState:(id)sender;

-(IBAction) openEquation:(id)sender;
-(IBAction) openLinkedEquation:(id)sender;
-(IBAction) importCurrent:(id)sender;//creates a library item with the current document state
-(IBAction) newFolder:(id)sender;
-(IBAction) removeSelectedItems:(id)sender;
-(IBAction) refreshItems:(id)sender;
-(IBAction) relatexizeSelectedItems:(id)sender;
-(IBAction) renameItem:(id)sender;

-(IBAction) toggleCommentsPane:(id)sender;

-(IBAction) open:(id)sender;
-(IBAction) saveAs:(id)sender;
-(IBAction) openDefaultLibraryPath:(id)sender;

-(IBAction) changeLibraryExportFormat:(id)sender;

-(IBAction) librarySearchFieldChanged:(id)sender;

-(LibraryView*) libraryView;

-(BOOL) canRemoveSelectedItems;
-(BOOL) canRenameSelectedItems;
-(BOOL) canRefreshItems;

-(BOOL) isCommentsPaneOpen;

-(NSMenu*) actionMenu;
-(BOOL)    validateMenuItem:(NSMenuItem*)menuItem;

-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;

-(void) blink:(LibraryEquation*)libraryEquation;

-(void) importTeXItemsWithOptions:(NSDictionary*)options;
-(IBAction) changeImportTeXItems:(id)sender;
-(IBAction) closeImportTeXItems:(id)sender;
-(IBAction) performImportTeXItems:(id)sender;

@end
