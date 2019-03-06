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
  TooltipWindow* tooltipWindow;
}

@property BOOL shouldBlink;
@property CGFloat delay;

@property (readonly, getter=isBlinking) BOOL blinking;

@end
