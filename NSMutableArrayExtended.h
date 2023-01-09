//  NSMutableArrayExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 3/05/05.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSMutableArray class

#import <Cocoa/Cocoa.h>

@interface NSMutableArray (Extended)

-(void) safeAddObject:(id)object;

//inserts another array's content at a given index
-(void) insertObjectsFromArray:(NSArray *)array atIndex:(NSInteger)index;

-(void) moveObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index;

@end
