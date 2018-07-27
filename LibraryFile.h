//  LibraryFile.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//The LibraryFile is a libraryItem (that can appear in the library outlineview)
//But it represents a "file", that is to say a document state
//This state is stored as an historyItem, that is already perfect for that

#import <Cocoa/Cocoa.h>

@interface LibraryFile : NSObject <NSCoding> {
}

@end
