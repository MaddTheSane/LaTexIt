//
//  HistoryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HistoryTableView;
@interface HistoryController : NSWindowController {
  IBOutlet HistoryTableView* historyTableView;
  IBOutlet NSButton* clearHistoryButton;
}

-(IBAction) removeHistoryEntries:(id)sender;
-(IBAction) clearHistory:(id)sender;

-(BOOL) canRemoveEntries;
-(void) deselectAll:(id)sender;

@end
