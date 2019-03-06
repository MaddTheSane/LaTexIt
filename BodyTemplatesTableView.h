//
//  BodyTemplatesTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/09/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface BodyTemplatesTableView : NSTableView {
  NSIndexSet* draggedRowIndexes;//transient, used only during drag'n drop
}

-(IBAction) edit:(id)sender;

@end
