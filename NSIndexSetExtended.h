//  NSIndexSetExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/05/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSIndexSet class

#import <Cocoa/Cocoa.h>

@interface NSIndexSet (Extended)

//returns a representation of the receiver as an array of unsigned NSNumbers
-(NSArray*) array;

@end
