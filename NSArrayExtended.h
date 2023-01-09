//  NSArrayExtended.h
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import <Cocoa/Cocoa.h>

@interface NSArray<__covariant ObjectType> (Extended)

-(ObjectType) firstObject;
-(ObjectType) firstObjectIdenticalTo:(id)object;
-(ObjectType) firstObjectNotIdenticalTo:(id)object;

//checks if the array contains an object, based on adress comparison, not isEqual:
-(BOOL) containsObjectIdenticalTo:(id)object;

//returns a copy of the receiver in the reversed order
-(NSArray<ObjectType>*) reversed;

-(NSArray<ObjectType>*) arrayByAddingObject:(ObjectType)object atIndex:(NSUInteger)index;
-(NSArray<ObjectType>*) arrayByMovingObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index;

-(NSArray<ObjectType>*) filteredArrayWithItemsOfClass:(Class)aClass exactClass:(BOOL)exactClass;

-(id) copyDeep;
-(id) copyDeepWithZone:(NSZone*)zone;
-(id) mutableCopyDeep;
-(id) mutableCopyDeepWithZone:(NSZone*)zone;

@end
