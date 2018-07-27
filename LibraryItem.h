//  LibraryItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//A LibraryItem is similar to an XMLNode, in the way that it has parent (weak link to prevent cycling)
//and children (strong link)
//It is an abstract class, its derivations aim at presenting information in the Library outlineview of the library drawer
//Each libraryItem has a name and an icon

//This class is heavily inspired by the TreeData and TreeNode classes of the DragDropOutlineView provided
//by apple in the developer documentation

#import <Cocoa/Cocoa.h>

@interface LibraryItem : NSObject <NSCoding, NSCopying> {
  LibraryItem*     parent;   //structuring data
  NSMutableArray*  children; //structuring data
  NSString*        title; //the title under which the item is displayed
}

//the title under which the item is displayed
-(void) setTitle:(NSString*)title;
-(NSString*) title;

-(NSImage*) image; //the icon used to display the item. Should be pure virtual

//Structuring methods
-(void) setParent:(LibraryItem*)parent; //thge aprent is a weak link (not retained) to prevent cycling
-(LibraryItem*) parent;

-(void) insertChild:(LibraryItem*)child;//inserts at the end
-(void) insertChild:(LibraryItem*)child   atIndex:(int)index;
-(void) insertChildren:(NSArray*)children atIndex:(int)index;
-(void) removeChild:(LibraryItem*)child;
-(void) removeChildren:(NSArray*)children;
-(void) removeFromParent;

-(int) indexOfChild:(LibraryItem*)child;
-(int) numberOfChildren;

-(NSArray*) children;
-(LibraryItem*) childAtIndex:(int)index;

-(BOOL) isDescendantOfItem:(LibraryItem*)item;
-(BOOL) isDescendantOfItemInArray:(NSArray*)items;

-(LibraryItem*) nextSibling;

//Difficult method : returns a simplified array, to be sure that no item of the array has an ancestor
//in this array. This is useful, when several items are selected, to factorize the work in a common
//ancestor. It solves many problems.
+(NSArray*) minimumNodeCoverFromItemsInArray:(NSArray*)allItems;

@end
