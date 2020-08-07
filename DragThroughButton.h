//
//  DragThroughButton.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 07/05/10.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* DragThroughButtonStateChangedNotification;

@class TooltipWindow;

@interface DragThroughButton : NSButton {
  NSDate* lastMoveDate;
  NSUInteger remainingSetStateWrapped;
  BOOL shouldBlink;
  CGFloat delay;
  BOOL canSwitchState;
  TooltipWindow* tooltipWindow;
  BOOL canTrackMouse;
}

-(BOOL) shouldBlink;
-(void) setShouldBlink:(BOOL)value;
-(CGFloat) delay;
-(void) setDelay:(CGFloat)value;
-(BOOL) canSwitchState;
-(void) setCanSwitchState:(BOOL)value;
-(BOOL) canTrackMouse;
-(void) setCanTrackMouse:(BOOL)value;

-(BOOL) isBlinking;

@end
