//
//  NSArrayControllerExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/05/09.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSArrayController (Extended)

-(void) moveObjectsAtIndices:(NSIndexSet*)indices toIndex:(NSUInteger)index;

@end
