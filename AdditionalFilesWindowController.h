//
//  AdditionalFilesWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class AdditionalFilesTableView;
@class ImagePopupButton;

@interface AdditionalFilesWindowController : NSWindowController {
  IBOutlet AdditionalFilesTableView* additionalFilesTableView;
  IBOutlet NSButton*                 additionalFilesAddButton;
  IBOutlet NSButton*                 additionalFilesRemoveButton;
  IBOutlet ImagePopupButton*         additionalFilesMenuButton;
}

-(NSArray*) additionalFilesPaths;

@end
