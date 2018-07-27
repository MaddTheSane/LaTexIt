//  HistoryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

//This file is the history manager, data source of every historyView.
//It is a singleton, holding a single copy of the history items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

extern NSString* HistoryDidChangeNotification;
extern NSString* HistoryItemsPboardType;

@class HistoryItem;
@interface HistoryManager : NSObject {
  //Note that access to historyItem will be @synchronized
  NSMutableArray* historyItems;
  BOOL historyShouldBeSaved; //becomes YES is a modification occurs, returns to NO after saving
  NSUndoManager* undoManager;
  
  NSThread* mainThread;
  
  NSManagedObjectContext* managedObjectContext;
  NSArrayController*      latexitEquationsController;
}

+(HistoryManager*) sharedManager; //getting the history manager singleton

-(NSArrayController*)      latexitEquationsController;
-(NSUndoManager*) undoManager;

-(BOOL) historyShouldBeSaved;
-(void) setHistoryShouldBeSaved:(BOOL)state;

//getting the history items
-(NSArray*) historyItems;

//inserting, removing, undo-aware
-(void) addItem:(HistoryItem*)item;
-(void) clearAll;
-(NSArray*) itemsAtIndexes:(NSIndexSet*)indexSet tableView:(NSTableView*)tableView;
-(HistoryItem*) itemAtIndex:(unsigned int)index tableView:(NSTableView*)tableView;
-(void) removeItemsAtIndexes:(NSIndexSet*)indexSet tableView:(NSTableView*)tableView;
-(void) insertItems:(NSArray*)items atIndexes:(NSArray*)indexes tableView:(NSTableView*)tableView;

//migrating to Core-Data
-(void) addItemWithPDFData:(NSData*)pdfData preamble:(NSAttributedString*)preamble sourceText:(NSAttributedString*)sourceText
                     color:(NSColor*)color pointSize:(double)pointSize date:(NSDate*)date mode:(latex_mode_t)mode
                     backgroundColor:(NSColor*)backgroundColor;
@end
