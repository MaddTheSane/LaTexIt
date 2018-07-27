//  NSArrayExtended.h
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import <Cocoa/Cocoa.h>

@interface NSArray (Extended)

//returns a copy of the receiver in the reversed order
-(NSArray*) reversed;

#ifdef PANTHER
-(NSArray*) objectsAtIndexes:(NSIndexSet *)indexes; //does exist in Tiger
#endif

@end
