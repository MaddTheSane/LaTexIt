//
//  TextShortcutsTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.

//TextShortcutsTableView presents custom text shortcuts from an text shortcut manager. I has user friendly capabilities

#import <Cocoa/Cocoa.h>

@interface TextShortcutsTableView : NSTableView {
}

-(IBAction) edit:(id)sender;

//sent through the first responder chain
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

@end
