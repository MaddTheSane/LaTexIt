//  LibraryTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This the library outline view, with some added methods to manage the selection

#import <Cocoa/Cocoa.h>

typedef enum {LIBRARY_ROW_IMAGE_AND_TEXT, LIBRARY_ROW_IMAGE_LARGE} library_row_t;

@interface LibraryTableView : NSOutlineView {
  library_row_t  libraryRowType;
}

-(IBAction) copy:(id)sender;
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

-(void) edit:(id)sender;
-(NSArray*) selectedFileItems;
-(NSArray*) selectedItems;
-(void) removeSelectedItems;

-(library_row_t) libraryRowType;
-(void) setLibraryRowType:(library_row_t)type;

@end
