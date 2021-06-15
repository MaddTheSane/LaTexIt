//  HistoryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.

//This file is the history manager, data source of every historyView.
//It is a singleton, holding a single copy of the history items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

typedef enum {HISTORY_IMPORT_OVERWRITE, HISTORY_IMPORT_MERGE} history_import_option_t;
typedef enum {HISTORY_EXPORT_FORMAT_INTERNAL, HISTORY_EXPORT_FORMAT_PLIST} history_export_format_t;

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
-(BOOL) isLocked;
-(void) setLocked:(BOOL)value;

-(NSUInteger) numberOfItems;
-(void) deleteOldEntries;

-(void) saveHistory;
-(BOOL) saveAs:(NSString*)path onlySelection:(BOOL)onlySelection selection:(NSArray*)selectedItems format:(history_export_format_t)format;
-(BOOL) loadFrom:(NSString*)path option:(history_import_option_t)option;

-(void) vacuum;

@end
