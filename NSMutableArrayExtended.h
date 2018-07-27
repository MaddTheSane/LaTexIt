//  NSMutableArrayExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 3/05/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSMutableArray class

#import <Cocoa/Cocoa.h>

@interface NSMutableArray (Extended)

//inserts another array's content at a given index
-(void) insertObjectsFromArray:(NSArray *)array atIndex:(int)index;

//checks if indexOfObjectIdenticalTo returns a valid index
-(BOOL) containsObjectIdenticalTo:(id)object;

//this method does exist in Tiger
#ifdef PANTHER
-(void) removeObjectsAtIndexes:(NSIndexSet *)indexes;
#endif

@end
