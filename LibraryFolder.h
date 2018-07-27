//  LibraryFolder.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//The LibraryFolder is a libraryItem (that can appear in the library outlineview)
//But it represents a "folder", that is to say a parent for other library items
//It contains nothing more than a LibraryItem, which is already similar to an XMLNode

#import <Cocoa/Cocoa.h>

#import "LibraryItem.h"

@interface LibraryFolder : LibraryItem <NSCoding, NSCopying> {
}

-(NSImage*) icon; //to get an icon
-(NSImage*) bigIcon; //to get an icon

@end
