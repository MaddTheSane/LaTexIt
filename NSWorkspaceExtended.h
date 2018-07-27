//
//  NSWorkspaceExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/07/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

//this file is an extension of the NSWorkspace class

#import <Cocoa/Cocoa.h>

@interface NSWorkspace (Extended)

//this method does exist under Tiger
#ifdef PANTHER
-(BOOL) setIcon:(NSImage*)image forFile:(NSString*)fullPath options:(unsigned)options;
#endif

@end