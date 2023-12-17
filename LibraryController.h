//
//  LibraryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/05/09.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LibraryGroupItem;

@interface LibraryController : NSObject <NSOutlineViewDataSource> {
  NSFetchRequest* rootFetchRequest;
  NSArray*        currentlyDraggedItems;
  NSPredicate*    filterPredicate;
  NSArray*        rootItemsCache;
}

-(NSManagedObjectContext*) managedObjectContext;
-(NSUndoManager*) undoManager;

@property (nonatomic, retain) NSPredicate *filterPredicate;

-(NSArray*) rootItems:(NSPredicate*)predicate;
-(void) invalidateRootItemsCache;

-(void) fixChildrenSortIndexesForParent:(LibraryGroupItem*)parent recursively:(BOOL)recursively;
-(void) removeItem:(id)item;
-(void) removeItems:(NSArray*)items;

@end
