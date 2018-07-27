//
//  DragThroughButton.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 07/05/10.
//  Copyright 2010 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* DragThroughButtonStateChangedNotification;

@class TooltipWindow;

@interface DragThroughButton : NSButton {
  NSDate* lastMoveDate;
  NSUInteger remainingSetStateWrapped;
  BOOL shouldBlink;
  CGFloat delay;
  TooltipWindow* tooltipWindow;
}

-(BOOL) shouldBlink;
-(void) setShouldBlink:(BOOL)value;
-(CGFloat) delay;
-(void) setDelay:(CGFloat)value;

-(BOOL) isBlinking;

@end
