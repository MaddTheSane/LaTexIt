//
//  TextShortcutsManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//the TextShortcutsManager is dataSource and delegate of the TextShortcutsView
//textShortcuts are customizable exports of library items, when drag'n dropping to destinations that are text-only
//you may export the item title, latex source code, with some decorations...

#import <Cocoa/Cocoa.h>

extern NSString* TextShortcutsPboardType;

@interface TextShortcutsManager : NSObject {
  NSMutableArray* textShortcuts; //the different custom exports (encaspulations)
  NSIndexSet*     draggedRowIndexes; //very volatile, used for drag'n drop of textShortcutsTableView rows
  NSUndoManager*  undoManager;
}

+(TextShortcutsManager*) sharedManager;
-(NSUndoManager*)        undoManager;

-(void) newTextShortcut;
-(void) removeTextShortcutsIndexes:(NSIndexSet*)indexes;//remove selected ones

@end
