//  NSArrayExtended.h
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import <Cocoa/Cocoa.h>

@interface NSArray (Extended)

-(id) firstObject;
-(id) firstObjectIdenticalTo:(id)object;
-(id) firstObjectNotIdenticalTo:(id)object;

//checks if the array contains an object, based on adress comparison, not isEqual:
-(BOOL) containsObjectIdenticalTo:(id)object;

//returns a copy of the receiver in the reversed order
-(NSArray*) reversed;

-(NSArray*) arrayByAddingObject:(id)object atIndex:(NSUInteger)index;
-(NSArray*) arrayByMovingObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index;

-(NSArray*) filteredArrayWithItemsOfClass:(Class)aClass exactClass:(BOOL)exactClass;

-(id) deepCopy;
-(id) deepCopyWithZone:(NSZone*)zone;
-(id) deepMutableCopy;
-(id) deepMutableCopyWithZone:(NSZone*)zone;

@end
