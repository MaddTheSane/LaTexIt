//  LibraryItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.

//A LibraryItem is similar to an XMLNode, in the way that it has parent (weak link to prevent cycling)
//and children (strong link)
//It is an abstract class, its derivations aim at presenting information in the Library outlineview of the library drawer
//Each libraryItem has a name and an icon

//This class is heavily inspired by the TreeData and TreeNode classes of the DragDropOutlineView provided
//by apple in the developer documentation

#import <Cocoa/Cocoa.h>

@class LibraryGroupItem;

@interface LibraryItem : NSManagedObject <NSCopying, NSCoding> {
  LibraryItem* parent;//seems to be needed on Tiger
  NSSet*   children;//seems to be needed on Tiger
  NSString*    title;//seems to be needed on Tiger
  unsigned int sortIndex;//seems to be needed on Tiger
}

+(NSEntityDescription*) entity;

-(id) initWithParent:(LibraryItem*)parent insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;
-(void) dispose;

-(BOOL) dummyPropertyToForceUIRefresh;

-(NSString*)    title;
-(void)         setTitle:(NSString*)value;
-(void)         setBestTitle;//computes best title in current context
-(LibraryItem*) parent;
-(void)         setParent:(LibraryItem*)parent;
-(unsigned int) sortIndex;
-(void)         setSortIndex:(unsigned int)value;

-(NSArray*) brothersIncludingMe:(BOOL)includingMe;

//for readable export
-(id) plistDescription;
+(LibraryItem*) libraryItemWithDescription:(id)description;
-(id) initWithDescription:(id)description;

@end
