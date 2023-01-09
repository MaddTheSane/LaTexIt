//  LibraryItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.

//A LibraryItem is similar to an XMLNode, in the way that it has parent (weak link to prevent cycling)
//and children (strong link)
//It is an abstract class, its derivations aim at presenting information in the Library outlineview of the library drawer
//Each libraryItem has a name and an icon

//This class is heavily inspired by the TreeData and TreeNode classes of the DragDropOutlineView provided
//by apple in the developer documentation

#import <Cocoa/Cocoa.h>

@class LibraryGroupItem;

@interface LibraryItem : NSManagedObject <NSCopying, NSCoding, NSSecureCoding> {
  /*
  LibraryItem* parent;//seems to be needed on Tiger
  NSSet* children;//seems to be needed on Tiger
  NSString* title;//seems to be needed on Tiger
  NSString* comment;//seems to be needed on Tiger
  unsigned int sortIndex;//seems to be needed on Tiger
  */
  NSUInteger cachedSortIndex;
}

+(NSEntityDescription*) entity;

+(NSSet<Class>*) allowedSecureDecodedClasses;

-(id) initWithParent:(LibraryItem*)parent insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;
-(void) dispose;

-(BOOL) dummyPropertyToForceUIRefresh;

@property (nonatomic, copy) NSString *title;
//! computes best title in current context
-(void)         setBestTitle;

@property (nonatomic, assign) LibraryItem *parent;
@property (nonatomic) NSUInteger sortIndex;
@property (nonatomic, copy) NSString *comment;

-(NSArray*) brothersIncludingMe:(BOOL)includingMe;
@property (readonly, copy) NSArray<NSString*> *titlePath;

//for readable export
-(id) plistDescription;
+(LibraryItem*) libraryItemWithDescription:(id)description;
-(instancetype) initWithDescription:(id)description;

@end
