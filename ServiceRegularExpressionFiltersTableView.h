//
//  ServiceRegularExpressionFiltersTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ServiceRegularExpressionFiltersTableView : NSTableView {
  NSIndexSet* draggedRowIndexes;//transient, used only during drag'n drop
}

-(IBAction) edit:(id)sender;

//sent through the first responder chain
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

@end
