//  LibraryView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This the library outline view, with some added methods to manage the selection

#import <Cocoa/Cocoa.h>

@class MyDocument;
@interface LibraryView : NSOutlineView {
  IBOutlet MyDocument* document;
}

-(MyDocument*) document;

-(IBAction) copy:(id)sender;

-(NSArray*) selectedFileItems;
-(NSArray*) selectedItems;
-(void) removeSelectedItems;

@end
