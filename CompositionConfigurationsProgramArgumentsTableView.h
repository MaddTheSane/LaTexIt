//
//  CompositionConfigurationsProgramArgumentsTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CompositionConfigurationsProgramArgumentsController;

@interface CompositionConfigurationsProgramArgumentsTableView : NSTableView {
  CompositionConfigurationsProgramArgumentsController* controller;
  NSIndexSet* draggedRowIndexes;//transient, used only during drag'n drop
}

-(void) setController:(CompositionConfigurationsProgramArgumentsController*)controller;

-(IBAction) add:(id)sender;
-(IBAction) edit:(id)sender;

//sent through the first responder chain
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

@end
