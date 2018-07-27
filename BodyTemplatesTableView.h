//
//  BodyTemplatesTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/09/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BodyTemplatesTableView : NSTableView {
  NSIndexSet* draggedRowIndexes;//transient, used only during drag'n drop
}

-(IBAction) edit:(id)sender;

@end
