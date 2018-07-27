//
//  AdditionalFilesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AdditionalFilesTableView;

@interface AdditionalFilesController : NSWindowController {
  IBOutlet AdditionalFilesTableView* filesTableView;
  IBOutlet NSButton* removeFilesButton;
  NSMutableArray*    filesArray;
  NSArrayController* filesArrayController;
}

-(IBAction) addFiles:(id)sender;
-(IBAction) removeFiles:(id)sender;
-(IBAction) help:(id)sender;

-(NSArray*) filepaths;

@end
