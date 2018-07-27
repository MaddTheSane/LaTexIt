//  LibraryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This file is the library manager, data source of every libraryView.
//It is a singleton, holding a single copy of the library items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

//Note that the library will be @synchronized

#import <Cocoa/Cocoa.h>

extern NSString* LibraryDidChangeNotification;
extern NSString* LibraryItemsPboardType;

@class HistoryItem;
@class LibraryFile;
@class LibraryFolder;
@class LibraryItem;

@interface LibraryManager : NSObject {
  LibraryFolder* library; //the root of the library; note that it will be @syncronized
  NSArray*       draggedItems; //a very volatile variable used during drag'n drop
  BOOL libraryShouldBeSaved; //becomes YES is a modification occurs, returns to NO after saving
}

+(LibraryManager*) sharedManager; //the library manager singleton

-(NSArray*) allValues;//returns all the values contained in LibraryFile items
-(void) setNeedsSaving:(BOOL)status;//marks if library needs being saved

//undo-aware methods to manage the library.

-(LibraryItem*) newFolder:(NSOutlineView*)outlineView;//creates a new folder
-(LibraryItem*) addItem:(LibraryItem*)libraryItem outlineView:(NSOutlineView*)outlineView;//adds a new item at the end
//The <historyItem>, as a parameter, will be the value of the LibraryFile that will be created
-(LibraryItem*) newFile:(HistoryItem*)historyItem outlineView:(NSOutlineView*)outlineView;
-(void) removeItems:(NSArray*)items;
-(void) refreshFileItem:(LibraryFile*)item withValue:(HistoryItem*)value;

-(BOOL) saveAs:(NSString*)path;
-(BOOL) loadFrom:(NSString*)path;

@end
