//
//  DragThroughButton.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 07/05/10.
//  Copyright 2010 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* DragThroughButtonStateChangedNotification;

@interface DragThroughButton : NSButton {
  NSDate* lastMoveDate;
  NSUInteger remainingSetStateWrapped;
}

-(BOOL) isBlinking;

@end
