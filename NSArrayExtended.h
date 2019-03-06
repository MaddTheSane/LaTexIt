//  NSArrayExtended.h
//  LaTeXiT
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.

// This file is an extension of the NSArray class

#import <Cocoa/Cocoa.h>
#import "DeepCopying.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSArray<ObjectType> (Extended) <DeepCopying, DeepMutableCopying>
-(nullable ObjectType) firstObjectIdenticalTo:(ObjectType)object;
-(nullable ObjectType) firstObjectNotIdenticalTo:(ObjectType)object;

//checks if the array contains an object, based on adress comparison, not isEqual:
-(BOOL) containsObjectIdenticalTo:(ObjectType)object;

//returns a copy of the receiver in the reversed order
@property (readonly, copy) NSArray<ObjectType> * _Nonnull reversed;

-(NSArray<ObjectType>*) arrayByAddingObject:(ObjectType)object atIndex:(NSUInteger)index;
-(NSArray<ObjectType>*) arrayByMovingObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index;

-(NSArray<ObjectType>*) filteredArrayWithItemsOfClass:(Class)aClass exactClass:(BOOL)exactClass;

@property (readonly, strong) id _Nonnull deepCopy;
-(id) deepCopyWithZone:(nullable NSZone*)zone;
@property (readonly, strong) id _Nonnull deepMutableCopy;
-(id) deepMutableCopyWithZone:(nullable NSZone*)zone;

@end

NS_ASSUME_NONNULL_END
