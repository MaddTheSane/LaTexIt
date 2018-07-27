//  LibraryGroupItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//The LibraryGroupItem is a libraryItem (that can appear in the library outlineview)
//But it represents a "folder", that is to say a parent for other library items
//It contains nothing more than a LibraryItem, which is already similar to an XMLNode

#import <Cocoa/Cocoa.h>

#import "LibraryItem.h"

@interface LibraryGroupItem : LibraryItem <NSCopying, NSCoding> {
  //NSArray* children;
  //BOOL     expanded;
  NSArray*   childrenSortDescriptors;
}

+(NSEntityDescription*) entity;

-(id) initWithParent:(LibraryItem*)parent insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;

-(BOOL)     isExpanded;
-(void)     setExpanded:(BOOL)value;
-(NSSet*)   children;
-(NSArray*) childrenOrdered;
-(void)     fixChildrenSortIndexesRecursively:(BOOL)recursively;

//for readable export
-(id) plistDescription;

@end
