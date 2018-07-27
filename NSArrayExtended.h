//  NSArrayExtended.h
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import <Cocoa/Cocoa.h>

@interface NSArray (Extended)

//returns a copy of the receiver in the reversed order
-(NSArray*) reversed;

-(NSArray*) arrayByMovingObjectsAtIndices:(NSIndexSet*)indices toIndex:(unsigned int)index;

#ifdef PANTHER
-(NSArray*) objectsAtIndexes:(NSIndexSet *)indexes; //does exist in Tiger
#endif

-(id) deepCopy;
-(id) deepCopyWithZone:(NSZone*)zone;
-(id) deepMutableCopy;
-(id) deepMutableCopyWithZone:(NSZone*)zone;

@end
