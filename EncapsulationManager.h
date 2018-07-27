//
//  EncapsulationManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/07/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

//the EncapsulationManager is dataSource and delegate of the EncapsulationView
//encapsulations are customizable exports of library items, when drag'n dropping to destinations that are text-only
//you may export the item title, latex source code, with some decorations...

#import <Cocoa/Cocoa.h>

extern NSString* EncapsulationPboardType;

@interface EncapsulationManager : NSObject {
  NSMutableArray* encapsulations; //the different custom exports (encaspulations)
  NSIndexSet*     draggedRowIndexes; //very volatile, used for drag'n drop of encapsulationTableView rows
  NSUndoManager*  undoManager;
}

+(EncapsulationManager*) sharedManager;
-(NSUndoManager*)        undoManager;

-(void) newEncapsulation;
-(void) removeEncapsulationIndexes:(NSIndexSet*)indexes;//remove selected ones

@end
