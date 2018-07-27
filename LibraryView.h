//  LibraryView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//This the library outline view, with some added methods to manage the selection

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class LibraryController;

@interface LibraryView : NSOutlineView {
  LibraryController* libraryController;
  library_row_t      libraryRowType;
  BOOL               willEdit;
}

-(LibraryController*) libraryController;

-(library_row_t) libraryRowType;
-(void) setLibraryRowType:(library_row_t)type;

-(void) expandOutlineItems;

-(IBAction) removeSelection:(id)sender;
-(IBAction) copy:(id)sender;
-(IBAction) cut:(id)sender;
-(IBAction) paste:(id)sender;
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

-(void) edit:(id)sender;

-(BOOL) pasteContentOfPasteboard:(NSPasteboard*)pasteboard onItem:(id)item childIndex:(int)index;

@end
