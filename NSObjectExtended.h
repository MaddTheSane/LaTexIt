//
//  NSObjectExtended.h
//  MozoDojo
//
//  Created by Pierre Chatelier on 16/03/07.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSObject (Extended)

-(void) forwardInvocation:(NSInvocation*)anInvocation;

//Difficult method : returns a simplified array, to be sure that no item of the array has an ancestor
//in this array. This is useful, when several items are selected, to factorize the work in a common
//ancestor. It solves many problems.

// Returns the minimum nodes from 'allNodes' required to cover the nodes in 'allNodes'.
// This methods returns an array containing nodes from 'allNodes' such that no node in
// the returned array has an ancestor in the returned array.

@end