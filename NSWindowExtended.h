//
//  NSWindowExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/07/12.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSWindow (Extended) 

-(void) setAnimationEnabled:(BOOL)value;
-(NSPoint) bridge_convertPointToScreen:(NSPoint)point;

@end
