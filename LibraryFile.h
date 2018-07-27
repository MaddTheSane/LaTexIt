//  LibraryFile.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

//The LibraryFile is a libraryItem (that can appear in the library outlineview)
//But it represents a "file", that is to say a document state
//This state is stored as an historyItem, that is already perfect for that

#import <Cocoa/Cocoa.h>

#import "LibraryItem.h"

@class HistoryItem;
@interface LibraryFile : LibraryItem <NSCoding> {
  HistoryItem* historyItem;
}

-(NSImage*) icon;

//The document's state is called a "value", because the fact that it is represented by a historyItem
//should not be "public"
-(void) setValue:(HistoryItem*)historyItem setAutomaticTitle:(BOOL)setAutomaticTitle;
-(HistoryItem*) value;

//for readable export
-(id) plistDescription;

@end
