//
//  DragThroughButton.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 07/05/10.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSNotificationName const DragThroughButtonStateChangedNotification;

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

@property BOOL shouldBlink;
@property CGFloat delay;
-(BOOL) canSwitchState;
-(void) setCanSwitchState:(BOOL)value;
-(BOOL) canTrackMouse;
-(void) setCanTrackMouse:(BOOL)value;

@property (readonly, getter=isBlinking) BOOL blinking;

@end
