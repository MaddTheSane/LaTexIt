//  HistoryView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/03/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//This is the table view displaying the history in the history drawer
//Its delegate and datasource are the HistoryManager, the history being shared by all documents

#import <Cocoa/Cocoa.h>

@class HistoryController;
@class HistoryItem;
@class MyDocument;

@interface HistoryView : NSTableView <NSTableViewDataSource, NSTableViewDelegate> {
  HistoryController*  historyItemsController;
  NSPoint             lastDragStartPointSelfBased;
  BOOL                shouldRedrag;
}

@property (readonly, strong) HistoryController *historyItemsController;
-(NSArray*) selectedItems;

-(IBAction) removeSelection:(id)sender;

//sent through first responder chain
-(IBAction) copy:(id)sender;
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

//NSTableViewDelegate
//-(BOOL) tableView:(NSTableView*)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation;
//NSTableViewDataSource
//-(BOOL) tableView:(NSTableView*)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;

@end
