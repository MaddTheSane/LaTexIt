//  LibraryGroupItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//The LibraryGroupItem is a libraryItem (that can appear in the library outlineview)
//But it represents a "folder", that is to say a parent for other library items
//It contains nothing more than a LibraryItem, which is already similar to an XMLNode

#import <Cocoa/Cocoa.h>

#import "LibraryItem.h"

@interface LibraryGroupItem : LibraryItem <NSCopying, NSCoding> {
  /*
  BOOL     expanded;//seems to be needed on Tiger
  */
  NSArray<NSSortDescriptor*>* childrenSortDescriptors;
}

+(NSEntityDescription*) entity;

-(instancetype) initWithParent:(LibraryItem*)parent insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;

@property (getter=isExpanded) BOOL expanded;
-(NSSet*)     children:(NSPredicate*)predicate;
-(NSArray*)   childrenOrdered:(NSPredicate*)predicate;
-(NSUInteger) childrenCount:(NSPredicate*)predicate;
-(void)       fixChildrenSortIndexesRecursively:(BOOL)recursively;

//for readable export
@property (readonly, strong) id plistDescription;
-(instancetype) initWithDescription:(id)description NS_DESIGNATED_INITIALIZER;

@end
