//  LibraryItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//A LibraryItem is similar to an XMLNode, in the way that it has parent (weak link to prevent cycling)
//and children (strong link)
//It is an abstract class, its derivations aim at presenting information in the Library outlineview of the library drawer
//Each libraryItem has a name and an icon

//This class is heavily inspired by the TreeData and TreeNode classes of the DragDropOutlineView provided
//by apple in the developer documentation

#import <Cocoa/Cocoa.h>

@class LibraryGroupItem;

@interface LibraryItem : NSManagedObject <NSCopying, NSCoding> {
  /*
  LibraryItem* parent;//seems to be needed on Tiger
  NSSet* children;//seems to be needed on Tiger
  NSString* title;//seems to be needed on Tiger
  NSString* comment;//seems to be needed on Tiger
  NSUInteger sortIndex;//seems to be needed on Tiger
  */
  NSUInteger cachedSortIndex;
}

+(NSEntityDescription*) entity;

-(instancetype) initWithParent:(LibraryItem*)parent insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithCoder:(NSCoder*)coder NS_DESIGNATED_INITIALIZER;
-(void) dispose;

@property (readonly) BOOL dummyPropertyToForceUIRefresh;

@property (copy) NSString *title;
-(void)         setBestTitle;//computes best title in current context
@property (weak) LibraryItem *parent;
@property NSUInteger sortIndex;
@property (copy) NSString *comment;

-(NSArray*) brothersIncludingMe:(BOOL)includingMe;
@property (readonly, copy) NSArray *titlePath;

//for readable export
@property (readonly, strong) id plistDescription;
+(LibraryItem*) libraryItemWithDescription:(id)description;
-(instancetype) initWithDescription:(id)description NS_DESIGNATED_INITIALIZER;
-(NSManagedObject *)initWithEntity:(NSEntityDescription *)entity insertIntoManagedObjectContext:(NSManagedObjectContext *)context NS_DESIGNATED_INITIALIZER;
@end
