//
//  DragThroughButton.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 07/05/10.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "DragThroughButton.h"

#import "LatexitEquation.h"
#import "LibraryManager.h"
#import "TooltipWindow.h"

NSString* DragThroughButtonStateChangedNotification = @"DragThroughButtonStateChangedNotification";

@interface DragThroughButton (PrivateAPI)
-(void) checkLastMove:(id)object;
-(void) setStateWrapped:(NSNumber*)number;
-(void) windowWillCloseNotification:(NSNotification*)notification;
@end

@implementation DragThroughButton

-(id) initWithCoder:(NSCoder*)coder
{
  if (!(self = [super initWithCoder:coder]))
    return nil;
  self->shouldBlink = YES;
  self->delay = .33;
  self->canTrackMouse = YES;
  [self registerForDraggedTypes:[NSArray arrayWithObjects:LatexitEquationsPboardType, LibraryItemsWrappedPboardType, nil]];
  return self;
}
//end initWithCoder:

-(id) initWithFrame:(NSRect)frameRect
{
  if (!(self = [super initWithFrame:frameRect]))
    return nil;
  self->shouldBlink = YES;
  self->delay = .33;
  self->canTrackMouse = YES;
  [self registerForDraggedTypes:[NSArray arrayWithObjects:LatexitEquationsPboardType, LibraryItemsWrappedPboardType, nil]];
  return self;
}
//end initWithFrame:

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->tooltipWindow release];
  [self->lastMoveDate release];
  [super dealloc];
}
//end dealloc:

-(void) awakeFromNib
{
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillCloseNotification:) name:NSWindowWillCloseNotification object:[self window]];
}
//end awakeFromNib

-(BOOL) isOpaque {return YES;}

-(BOOL) shouldBlink
{
  return self->shouldBlink;
}
//end shouldBlink

-(void) setShouldBlink:(BOOL)value
{
  self->shouldBlink = value;
}
//end setShouldBlink:

-(CGFloat) delay
{
  return self->delay;
}
//end delay

-(void) setDelay:(CGFloat)value
{
  self->delay = value;
}
//end setDelay:

-(BOOL) canSwitchState
{
  return self->canSwitchState;
}
//end canSwitchState

-(void) setCanSwitchState:(BOOL)value
{
  self->canSwitchState = value;
}
//end setCanSwitchState:

-(BOOL) canTrackMouse
{
  return self->canTrackMouse;
}
//end canTrackMouse

-(void) setCanTrackMouse:(BOOL)value
{
  self->canTrackMouse = value;
}
//end setCanTrackMouse:

-(void) checkLastMove:(id)object
{
  if ([self toolTip])
  {
    NSPoint mouseLocation = [NSEvent mouseLocation];
    NSSize  toolTipSize = [TooltipWindow suggestedSizeForTooltip:[self toolTip]];
    NSRect  toolTipFrame = NSMakeRect(mouseLocation.x, mouseLocation.y, toolTipSize.width, toolTipSize.height);
    if (!self->tooltipWindow)
      self->tooltipWindow = [[TooltipWindow tipWithString:[self toolTip] frame:toolTipFrame display:YES] retain];
    [self->tooltipWindow orderFrontWithDuration:5];
  }//end if ([self toolTip])
  if ([self isEnabled] && self->canTrackMouse)
  {
    NSInteger currentState = [self state];
    NSInteger newState = !self->canSwitchState ? NSOnState :
      (currentState == NSOnState) ? NSOffState :
      (currentState == NSOffState) ? NSOnState :
      currentState;
    NSInteger antiState =
      (newState == NSOnState) ? NSOffState :
      (newState == NSOffState) ? NSOnState :
      newState;
    if (!self->shouldBlink)
      [self setState:newState];
    else//if (self->shouldBlink)
    {
      self->remainingSetStateWrapped += 5;
      [self performSelector:@selector(setStateWrapped:) withObject:@(newState) afterDelay:0.05];
      [self performSelector:@selector(setStateWrapped:) withObject:@(antiState) afterDelay:0.10];
      [self performSelector:@selector(setStateWrapped:) withObject:@(newState) afterDelay:0.15];
      [self performSelector:@selector(setStateWrapped:) withObject:@(antiState) afterDelay:0.20];
      [self performSelector:@selector(setStateWrapped:) withObject:@(newState) afterDelay:0.25];
    }//end if (self->shouldBlink)
  }//end if ([self isEnabled] && self->canTrackMouse)
}
//end checkLastMove:

-(void) setStateWrapped:(NSNumber*)number
{
  if ([self isEnabled])
  {
    if (self->remainingSetStateWrapped)
      --self->remainingSetStateWrapped;
    [self setState:[number integerValue]];
  }//end if ([self isEnabled])
}
//end setStateWrapped:

-(void) setState:(NSInteger)value
{
  if ([self isEnabled])
  {
    [super setState:value];
    if (!self->remainingSetStateWrapped)
      [[NSNotificationCenter defaultCenter] postNotificationName:DragThroughButtonStateChangedNotification object:self userInfo:nil];
  }//end if ([self isEnabled])
}
//end setState:

-(BOOL) isBlinking
{
  BOOL result = (self->remainingSetStateWrapped > 0);
  return result;
}
//end isBlinking

-(BOOL) wantsPeriodicDraggingUpdates
{
  return NO;
}
//end wantsPeriodicDraggingUpdates

-(NSDragOperation) draggingEntered:(id<NSDraggingInfo>)sender
{
  [self->lastMoveDate release];
  self->lastMoveDate = [[NSDate alloc] init];
  NSInteger currentState = [self state];
  NSInteger nextState = !self->canSwitchState ? NSOnState :
    (currentState == NSOnState) ? NSOffState :
    (currentState == NSOffState) ? NSOnState :
    currentState;
  if (currentState != nextState)
    [self performSelector:@selector(checkLastMove:) withObject:nil afterDelay:self->delay];
  return NSDragOperationAll;
}
//end draggingEntered:

-(NSDragOperation) draggingUpdated:(id<NSDraggingInfo>)sender
{
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkLastMove:) object:nil];
  [self->lastMoveDate release];
  self->lastMoveDate = [[NSDate alloc] init];
  NSInteger currentState = [self state];
  NSInteger nextState = !self->canSwitchState ? NSOnState :
    (currentState == NSOnState) ? NSOffState :
    (currentState == NSOffState) ? NSOnState :
    currentState;
  if (currentState != nextState)
    [self performSelector:@selector(checkLastMove:) withObject:nil afterDelay:self->delay];
  return NSDragOperationAll;
}
//end draggingExited:

-(void) draggingExited:(id<NSDraggingInfo>)sender
{
  [self->tooltipWindow orderOut:self];
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkLastMove:) object:nil];
}
//end draggingExited:

-(void) windowWillCloseNotification:(NSNotification*)notification
{
  [self->tooltipWindow orderOut:self];
}
//end windowWillCloseNotification:

-(void) drawRect:(NSRect)rect
{
  if (![self isEnabled])
  {
    [[NSColor grayColor] set];
    NSRectFill([self bounds]);
  }//end if (![self isEnabled])
  [super drawRect:rect];
}
//end drawRect:

@end
