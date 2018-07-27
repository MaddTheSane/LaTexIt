////  ServiceShortcutsTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/12/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.

//The ServiceShortcutsTableView is the class used to display the application service shortcut preferences.
//It has been sub-classed to tune a little the behaviour

#import <Cocoa/Cocoa.h>

#import "DelegatingTransformer.h"

@interface ServiceShortcutsTableView : NSTableView <DelegatingTransformerDelegate> {
  IBOutlet NSButton* serviceWarningShortcutConflictButton;
}

-(id) transformer:(DelegatingTransformer*)transformer reverse:(BOOL)reverse value:(id)value context:(id)context;

@end
