//
//  TextShortcutsController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

#import <Cocoa/Cocoa.h>

@class TextShortcutsTableView;
@interface TextShortcutsController : NSWindowController {
  IBOutlet TextShortcutsTableView* textShortcutsTableView;
  IBOutlet NSButton*               removeButton;
}

-(IBAction) newTextShortcut:(id)sender;
-(IBAction) removeSelectedTextShortcuts:(id)sender;

@end
