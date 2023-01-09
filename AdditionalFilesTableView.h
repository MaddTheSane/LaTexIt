//
//  AdditionalFilesTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AdditionalFilesTableView : NSTableView {
  BOOL isDefaultTableView;
  NSIndexSet* draggedRowIndexes;//transient, used only during drag'n drop
  NSArrayController* filesWithExtrasController;
  NSMutableArray* previousDefaultsFiles;
}

-(IBAction) addFiles:(id)sender;
-(IBAction) remove:(id)sender;

-(BOOL) isDefaultTableView;
-(void) setIsDefaultTableView:(BOOL)value;

-(NSArray*) additionalFilesPaths;

-(BOOL) canAdd;
-(BOOL) canRemove;

@end
