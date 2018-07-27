//
//  BodyTemplatesTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/09/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BodyTemplatesTableView : NSTableView {
  NSIndexSet* draggedRowIndexes;//transient, used only during drag'n drop
}

-(IBAction) edit:(id)sender;

@end
