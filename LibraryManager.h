//  LibraryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.

//This file is the library manager, data source of every libraryTableView.
//It is a singleton, holding a single copy of the library items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

//Note that the library will be @synchronized

#import <Cocoa/Cocoa.h>

extern NSPasteboardType const LibraryItemsArchivedPboardType;
extern NSPasteboardType const LibraryItemsWrappedPboardType;

typedef NS_ENUM(int, library_import_option_t) {LIBRARY_IMPORT_OVERWRITE, LIBRARY_IMPORT_MERGE, LIBRARY_IMPORT_OPEN};
typedef NS_ENUM(int, library_export_format_t) {LIBRARY_EXPORT_FORMAT_INTERNAL, LIBRARY_EXPORT_FORMAT_PLIST, LIBRARY_EXPORT_FORMAT_TEX_SOURCE};

@class LibraryItem;
@class LibraryGroupItem;

@interface LibraryManager : NSObject {
  NSManagedObjectContext* managedObjectContext;
  NSArray*                draggedItems; //!<a very volatile variable used during drag'n drop
}

+(LibraryManager*) sharedManager; //!<the library manager singleton
@property (class, readonly, retain) LibraryManager *sharedManager;

@property (readonly, nonatomic, copy) NSString *defaultLibraryPath;

@property (readonly, retain) NSManagedObjectContext *managedObjectContext;
-(NSUndoManager*) undoManager;

-(NSArray*) allItems;
-(void) removeAllItems;
-(void) removeItems:(NSArray*)items;

-(void) saveLibrary;
-(BOOL) saveAs:(NSString*)path onlySelection:(BOOL)selection selection:(NSArray*)selectedItems format:(library_export_format_t)format
       options:(NSDictionary*)options;
-(BOOL) loadFrom:(NSString*)path option:(library_import_option_t)option parent:(LibraryItem*)parent;

-(void) fixChildrenSortIndexesForParent:(LibraryGroupItem*)parent recursively:(BOOL)recursively;
-(NSArray*) libraryEquations;

-(NSArray*) createTeXItemsFromFile:(NSString*)filename proposedParentItem:(id)proposedParentItem proposedChildIndex:(NSInteger)proposedChildIndex;

-(void) vacuum;

@end
