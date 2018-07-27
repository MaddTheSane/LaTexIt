//
//  LibraryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/05/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LibraryGroupItem;

@interface LibraryController : NSObject {
  NSFetchRequest* rootFetchRequest;
  NSArray*        currentlyDraggedItems;
}

-(NSManagedObjectContext*) managedObjectContext;
-(NSUndoManager*) undoManager;

-(NSArray*) rootItems;
-(void) fixChildrenSortIndexesForParent:(LibraryGroupItem*)parent recursively:(BOOL)recursively;
-(void) removeItem:(id)item;
-(void) removeItems:(NSArray*)items;

@end
