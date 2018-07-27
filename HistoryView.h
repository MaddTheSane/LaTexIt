//  HistoryView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.

//This is the table view displaying the history in the history drawer
//Its delegate and datasource are the HistoryManager, the history being shared by all documents

#import <Cocoa/Cocoa.h>

@class HistoryController;
@class HistoryItem;
@class MyDocument;

@interface HistoryView : NSTableView {
  HistoryController* historyItemsController;
}

-(HistoryController*) historyItemsController;

-(IBAction) removeSelection:(id)sender;

//sent through first responder chain
-(IBAction) copy:(id)sender;
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

@end
