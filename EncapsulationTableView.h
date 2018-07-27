//
//  EncapsulationTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//EncapsulationTableView presents custom encapsulations from an encapsulation manager. I has user friendly capabilities

#import <Cocoa/Cocoa.h>

@interface EncapsulationTableView : NSTableView {
  NSMutableArray* cachedEncapsulations;
}

-(IBAction) edit:(id)sender;

//sent through the first responder chain
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

@end
