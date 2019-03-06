//
//  NSMutableSetExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/10/10.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSMutableSet<ObjectType> (Extended)

-(void) safeAddObject:(ObjectType)object;

@end
