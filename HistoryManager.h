//  HistoryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//This file is the history manager, data source of every historyView.
//It is a singleton, holding a single copy of the history items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

typedef NS_ENUM(NSInteger, history_import_option_t) {
  HISTORY_IMPORT_OVERWRITE,
  HISTORY_IMPORT_MERGE
};
typedef NS_ENUM(NSInteger, history_export_format_t) {
  HISTORY_EXPORT_FORMAT_INTERNAL,
  HISTORY_EXPORT_FORMAT_PLIST
};

@class HistoryItem;
@interface HistoryManager : NSObject {
  NSObjectController* bindController;
  NSManagedObjectContext* managedObjectContext;
  BOOL locked;
}

+(HistoryManager*) sharedManager; //getting the history manager singleton

-(NSManagedObjectContext*) managedObjectContext;
-(NSUndoManager*)          undoManager;

-(NSObjectController*) bindController;
@property (getter=isLocked) BOOL locked;

@property (readonly) NSUInteger numberOfItems;
-(void) deleteOldEntries;

-(void) saveHistory;
-(BOOL) saveAs:(NSString*)path onlySelection:(BOOL)onlySelection selection:(NSArray*)selectedItems format:(history_export_format_t)format;
-(BOOL) loadFrom:(NSString*)path option:(history_import_option_t)option;

@end
