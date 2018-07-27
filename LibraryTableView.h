//  LibraryTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This the library outline view, with some added methods to manage the selection

#import <Cocoa/Cocoa.h>

@interface LibraryTableView : NSOutlineView {
}

-(IBAction) copy:(id)sender;
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

-(void) edit:(id)sender;
-(NSArray*) selectedFileItems;
-(NSArray*) selectedItems;
-(void) removeSelectedItems;

@end
