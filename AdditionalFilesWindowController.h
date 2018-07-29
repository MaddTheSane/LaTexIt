//
//  AdditionalFilesWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AdditionalFilesTableView;

@interface AdditionalFilesWindowController : NSWindowController {
  IBOutlet AdditionalFilesTableView* additionalFilesTableView;
  IBOutlet NSButton*                 additionalFilesAddButton;
  IBOutlet NSButton*                 additionalFilesRemoveButton;
  IBOutlet NSPopUpButton*            additionalFilesMenuButton;
}

@property (readonly, copy) NSArray<NSString*> *additionalFilesPaths;

@end
