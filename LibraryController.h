//
//  LibraryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BorderlessPanel;
@class ImagePopupButton;
@class LibraryTableView;

@interface LibraryController : NSWindowController {
  IBOutlet NSButton*           importCurrentButton;
  IBOutlet ImagePopupButton*   actionButton;
  IBOutlet LibraryTableView*   libraryTableView;
  IBOutlet NSSegmentedControl* libraryRowTypeSegmentedControl;
  IBOutlet BorderlessPanel*    libraryPreviewPanel;
  IBOutlet NSImageView*        libraryPreviewPanelImageView;
  IBOutlet NSSegmentedControl* libraryPreviewPanelSegmentedControl;
  BOOL enablePreviewImage;
}

-(IBAction) importCurrent:(id)sender; //creates a library item with the current document state
-(IBAction) newFolder:(id)sender;     //creates a folder
-(IBAction) removeSelectedItems:(id)sender;    //removes some items
-(IBAction) refreshItems:(id)sender;   //refresh an item

-(IBAction) changeLibraryRowType:(id)sender;

-(IBAction) open:(id)sender;
-(IBAction) saveAs:(id)sender;

-(IBAction) changeLibraryPreviewPanelSegmentedControl:(id)sender;

-(BOOL) canRemoveSelectedItems;
-(BOOL) canRefreshItems;

-(NSMenu*)  actionMenu;
-(BOOL)     validateMenuItem:(NSMenuItem*)menuItem;
-(NSArray*) selectedItems;

-(void) displayPreviewImage:(NSImage*)image;
-(void) setEnablePreviewImage:(BOOL)status;

@end
