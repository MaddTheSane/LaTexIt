//
//  NSArrayControllerExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/05/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSArrayController (Extended)

-(void) moveObjectsAtIndices:(NSIndexSet*)indices toIndex:(unsigned int)index;

@end
