//
//  EncapsulationController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//this class is the "encapsulation palette", see encaspulationManager for more details

#import <Cocoa/Cocoa.h>

@class EncapsulationTableView;
@interface EncapsulationController : NSWindowController {
  IBOutlet EncapsulationTableView* encapsulationTableView;
  IBOutlet NSButton*               removeButton;
}

-(IBAction) newEncapsulation:(id)sender;
-(IBAction) removeSelectedEncapsulations:(id)sender;
-(IBAction) openHelp:(id)sender;

@end
