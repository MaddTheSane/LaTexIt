//
//  EncapsulationsWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.

//this class is the "encapsulation palette", see encaspulationManager for more details

#import <Cocoa/Cocoa.h>

@class EncapsulationsTableView;
@interface EncapsulationsWindowController : NSWindowController {
  IBOutlet EncapsulationsTableView* encapsulationsTableView;
  IBOutlet NSButton*                addButton;
  IBOutlet NSButton*                removeButton;
}

-(IBAction) openHelp:(id)sender;

@end
