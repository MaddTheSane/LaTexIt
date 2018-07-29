//
//  AdditionalFilesTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AdditionalFilesTableView : NSTableView <NSTableViewDelegate, NSTableViewDataSource> {
  BOOL isDefaultTableView;
  NSIndexSet* draggedRowIndexes;//transient, used only during drag'n drop
  NSArrayController* filesWithExtrasController;
  NSMutableArray* previousDefaultsFiles;
}

-(IBAction) addFiles:(id)sender;
-(IBAction) remove:(id)sender;

@property  BOOL isDefaultTableView;

@property (readonly, copy) NSArray<NSString*> *additionalFilesPaths;

@property (readonly) BOOL canAdd;
@property (readonly) BOOL canRemove;

@end
