//  NSArrayExtended.h
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import <Cocoa/Cocoa.h>
#import "DeepCopying.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSArray<ObjectType> (Extended) <DeepCopying, DeepMutableCopying>

//checks if the array contains an object, based on adress comparison, not isEqual:
-(BOOL) containsObjectIdenticalTo:(ObjectType)object;

//returns a copy of the receiver in the reversed order
-(NSArray<ObjectType>*) reversed;

-(NSArray<ObjectType>*) arrayByAddingObject:(ObjectType)object atIndex:(NSUInteger)index;
-(NSArray<ObjectType>*) arrayByMovingObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index;

-(NSArray<ObjectType>*) filteredArrayWithItemsOfClass:(Class)aClass exactClass:(BOOL)exactClass;

-(id) deepCopy;
-(id) deepCopyWithZone:(nullable NSZone*)zone;
-(id) deepMutableCopy;
-(id) deepMutableCopyWithZone:(nullable NSZone*)zone;

@end

NS_ASSUME_NONNULL_END
