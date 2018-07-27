//
//  LibraryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BorderlessPanel;
@class ImagePopupButton;
@class LibraryTableView;
@class LibraryPreviewPanelImageView;

@interface LibraryController : NSWindowController {
  IBOutlet NSButton*           importCurrentButton;
  IBOutlet ImagePopupButton*   actionButton;
  IBOutlet LibraryTableView*   libraryTableView;
  IBOutlet NSSegmentedControl* libraryRowTypeSegmentedControl;
  IBOutlet BorderlessPanel*    libraryPreviewPanel;
  IBOutlet LibraryPreviewPanelImageView* libraryPreviewPanelImageView;
  IBOutlet NSSegmentedControl* libraryPreviewPanelSegmentedControl;
  BOOL enablePreviewImage;
  
  IBOutlet NSView*             importAccessoryView;
  IBOutlet NSPopUpButton*      importOptionPopUpButton;
  IBOutlet NSView*             exportAccessoryView;
  IBOutlet NSButton*           exportOnlySelectedButton;
}

-(IBAction) importCurrent:(id)sender; //creates a library item with the current document state
-(IBAction) newFolder:(id)sender;     //creates a folder
-(IBAction) removeSelectedItems:(id)sender;    //removes some items
-(IBAction) refreshItems:(id)sender;   //refresh an item
-(IBAction) renameItem:(id)sender;   //refresh an item

-(IBAction) changeLibraryRowType:(id)sender;

-(IBAction) open:(id)sender;
-(IBAction) saveAs:(id)sender;
-(IBAction) openDefaultLibraryPath:(id)sender;

-(IBAction) changeLibraryPreviewPanelSegmentedControl:(id)sender;

-(BOOL) canRemoveSelectedItems;
-(BOOL) canRenameSelectedItems;
-(BOOL) canRefreshItems;

-(NSMenu*)  actionMenu;
-(BOOL)     validateMenuItem:(NSMenuItem*)menuItem;
-(NSArray*) selectedItems;

-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;
-(void) setEnablePreviewImage:(BOOL)status;

@end
