//  HistoryView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This is the table view displaying the history in the history drawer
//Its delegate and datasource are the HistoryManager, the history being shared by all documents

#import <Cocoa/Cocoa.h>

@class HistoryItem;

@class MyDocument;
@interface HistoryView : NSTableView {
  IBOutlet MyDocument* document;
}

-(MyDocument*) document;

//occurs when Command-C is pressed
-(IBAction) copy:(id)sender;

//gets an array of the selected items
-(NSArray*) selectedItems;

@end
