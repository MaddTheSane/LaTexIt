//
//  EncapsulationManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//the EncapsulationManager is dataSource and delegate of the EncapsulationView
//encapsulations are customizable exports of library items, when drag'n dropping to destinations that are text-only
//you may export the item title, latex source code, with some decorations...

#import <Cocoa/Cocoa.h>

extern NSString* EncapsulationPboardType;

@class EncapsulationView;
@interface EncapsulationManager : NSObject {
  IBOutlet EncapsulationView* encapsulationTableView;
  IBOutlet NSButton*          removeEncapsulationButton;

  NSMutableArray* encapsulations; //the different custom exports (encaspulations)
  
  NSIndexSet* draggedRowIndexes; //very volatile, used for drag'n drop of encapsulationTableView rows
}

-(IBAction) addEncapsulation:(id)sender;
-(IBAction) removeEncapsulations:(id)sender;//remove selected ones

-(void) removeSelectedItemsInTableView:(NSTableView*)tableView;

@end
