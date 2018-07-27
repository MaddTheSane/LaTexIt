//
//  NSObjectExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/07.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject (Extended)

+(nullable Class) dynamicCastToClass:(Class)aClass;
-(nullable id)    dynamicCastToClass:(Class)aClass;

//Difficult method : returns a simplified array, to be sure that no item of the array has an ancestor
//in this array. This is useful, when several items are selected, to factorize the work in a common
//ancestor. It solves many problems.

// Returns the minimum nodes from 'allNodes' required to cover the nodes in 'allNodes'.
// This methods returns an array containing nodes from 'allNodes' such that no node in
// the returned array has an ancestor in the returned array.

@end

NS_ASSUME_NONNULL_END
