//
//  CompositionConfigurationsTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/03/06.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CompositionConfigurationsTableView : NSTableView {
  NSIndexSet* draggedRowIndexes;//transient, used only during drag'n drop
}

-(IBAction) edit:(id)sender;

//sent through the first responder chain
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

@end
