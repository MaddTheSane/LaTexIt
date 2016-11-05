//  LibraryView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.

//This the library outline view, with some added methods to manage the selection

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class LibraryController;
@class LibraryEquation;
@class MyDocument;

@interface LibraryView : NSOutlineView {
  LibraryController* libraryController;
  library_row_t      libraryRowType;
  BOOL               willEdit;
  NSPoint            lastDragStartPointSelfBased;
  BOOL               shouldRedrag;
}

@property (readonly, retain) LibraryController *libraryController;

@property library_row_t libraryRowType;

-(void) expandOutlineItems;

-(IBAction) removeSelection:(id)sender;
-(IBAction) copy:(id)sender;
-(IBAction) cut:(id)sender;
-(IBAction) paste:(id)sender;
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

-(void) edit:(id)sender;
-(void) openEquation:(LibraryEquation*)equation inDocument:(MyDocument*)document makeLink:(BOOL)makeLink;

-(BOOL) pasteContentOfPasteboard:(NSPasteboard*)pasteboard onItem:(id)item childIndex:(NSInteger)index;

@end
