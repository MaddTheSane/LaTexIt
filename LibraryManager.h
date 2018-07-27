//  LibraryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//This file is the library manager, data source of every libraryTableView.
//It is a singleton, holding a single copy of the library items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

//Note that the library will be @synchronized

#import <Cocoa/Cocoa.h>

extern NSString* LibraryDidChangeNotification;
extern NSString* LibraryItemsPboardType;

typedef enum {LIBRARY_IMPORT_OVERWRITE, LIBRARY_IMPORT_MERGE, LIBRARY_IMPORT_OPEN} library_import_option_t;
typedef enum {LIBRARY_EXPORT_FORMAT_INTERNAL, LIBRARY_EXPORT_FORMAT_PLIST} library_export_format_t;

@class HistoryItem;
@class LibraryFile;
@class LibraryFolder;
@class LibraryItem;

@interface LibraryManager : NSObject {
  LibraryFolder* library; //the root of the library; note that it will be @syncronized
  NSArray*       draggedItems; //a very volatile variable used during drag'n drop
  BOOL libraryShouldBeSaved; //becomes YES is a modification occurs, returns to NO after saving
  
  NSUndoManager* undoManager;
  
  NSThread* mainThread;
  
  NSString* libraryPath;
}

+(LibraryManager*) sharedManager; //the library manager singleton

-(NSUndoManager*) undoManager;

-(BOOL) libraryShouldBeSaved;
-(void) setLibraryShouldBeSaved:(BOOL)state;//marks if library needs being saved

-(NSArray*) allItems;
-(NSArray*) allValues;//returns all the values contained in LibraryFile items

//undo-aware methods to manage the library.

-(LibraryItem*) newFolder:(NSOutlineView*)outlineView;//creates a new folder
-(LibraryItem*) addItem:(LibraryItem*)libraryItem outlineView:(NSOutlineView*)outlineView;//adds a new item at the end
//The <historyItem>, as a parameter, will be the value of the LibraryFile that will be created
-(LibraryItem*) newFile:(HistoryItem*)historyItem outlineView:(NSOutlineView*)outlineView;
-(void) removeItems:(NSArray*)items;
-(void) refreshFileItem:(LibraryFile*)item withValue:(HistoryItem*)value;

-(BOOL) saveAs:(NSString*)path onlySelection:(BOOL)selection selection:(NSArray*)selectedItems format:(library_export_format_t)format;
-(BOOL) loadFrom:(NSString*)path option:(library_import_option_t)option;

-(NSString*) defaultLibraryPath;

@end
