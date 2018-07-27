//  HistoryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//This file is the history manager, data source of every historyView.
//It is a singleton, holding a single copy of the history items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class HistoryItem;
@interface HistoryManager : NSObject {
  NSManagedObjectContext* managedObjectContext;
}

+(HistoryManager*) sharedManager; //getting the history manager singleton

-(NSManagedObjectContext*) managedObjectContext;
-(NSUndoManager*)          undoManager;

@end
