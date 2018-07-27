//
//  LibraryWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BorderlessPanel;
@class ImagePopupButton;
@class LibraryView;
@class LibraryPreviewPanelImageView;

@interface LibraryWindowController : NSWindowController {
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

  BOOL              enablePreviewImage;  
  NSSavePanel*      savePanel;
}

-(IBAction) changeLibraryDisplayPreviewPanelState:(id)sender;

-(IBAction) importCurrent:(id)sender;       //creates a library item with the current document state
-(IBAction) newFolder:(id)sender;           //creates a folder
-(IBAction) removeSelectedItems:(id)sender; //removes some items
-(IBAction) refreshItems:(id)sender;        //refresh an item
-(IBAction) renameItem:(id)sender;          //refresh an item

-(IBAction) open:(id)sender;
-(IBAction) saveAs:(id)sender;
-(IBAction) openDefaultLibraryPath:(id)sender;

-(IBAction) changeLibraryExportFormat:(id)sender;

-(BOOL) canRemoveSelectedItems;
-(BOOL) canRenameSelectedItems;
-(BOOL) canRefreshItems;

-(NSMenu*) actionMenu;
-(BOOL)    validateMenuItem:(NSMenuItem*)menuItem;

-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;

@end
