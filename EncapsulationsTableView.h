//
//  EncapsulationsTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//EncapsulationsTableView presents custom encapsulations from an encapsulation manager. I has user friendly capabilities

#import <Cocoa/Cocoa.h>

@interface EncapsulationsTableView : NSTableView <NSTableViewDelegate, NSTableViewDataSource> {
  NSIndexSet* draggedRowIndexes;//transient, used only during drag'n drop
}

-(IBAction) edit:(id)sender;

//sent through the first responder chain
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

@end
