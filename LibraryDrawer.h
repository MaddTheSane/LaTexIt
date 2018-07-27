//  LibraryDrawer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The libraryDrawer contains the library outline view (hierarchical) and
//the buttons <add folder>, <import current>, <remove>, <refresh>

#import <Cocoa/Cocoa.h>

@class LibraryView;
@interface LibraryDrawer : NSDrawer {
  IBOutlet NSButton* importCurrentButton;
  IBOutlet NSButton* addFolderButton;
  IBOutlet NSButton* removeItemButton;
  IBOutlet NSButton* refreshItemButton;
  IBOutlet LibraryView* libraryView;
}

-(IBAction) importCurrent:(id)sender; //creates a library item with the current document state
-(IBAction) newFolder:(id)sender;     //creates a folder
-(IBAction) removeItem:(id)sender;    //removes some items
-(IBAction) refreshItem:(id)sender;   //refresh an item

@end
