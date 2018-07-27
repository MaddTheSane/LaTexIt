//
//  DragThroughButton.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 07/05/10.
//  Copyright 2010 LAIC. All rights reserved.
//

#import "DragThroughButton.h"

#import "LatexitEquation.h"

NSString* DragThroughButtonStateChangedNotification = @"DragThroughButtonStateChangedNotification";

@interface DragThroughButton (PrivateAPI)
-(void) checkLastMove:(id)object;
-(void) setStateWrapped:(NSNumber*)number;
@end

@implementation DragThroughButton

-(id) initWithCoder:(NSCoder*)coder
{
  if (!(self = [super initWithCoder:coder]))
    return nil;
  [self registerForDraggedTypes:[NSArray arrayWithObjects:LatexitEquationsPboardType, nil]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [self->lastMoveDate release];
  [super dealloc];
}
//end dealloc:

-(void) checkLastMove:(id)object
{
  self->remainingSetStateWrapped += 5;
  [self performSelector:@selector(setStateWrapped:) withObject:[NSNumber numberWithInt:NSOnState] afterDelay:0.05];
  [self performSelector:@selector(setStateWrapped:) withObject:[NSNumber numberWithInt:NSOffState] afterDelay:0.10];
  [self performSelector:@selector(setStateWrapped:) withObject:[NSNumber numberWithInt:NSOnState] afterDelay:0.15];
  [self performSelector:@selector(setStateWrapped:) withObject:[NSNumber numberWithInt:NSOffState] afterDelay:0.20];
  [self performSelector:@selector(setStateWrapped:) withObject:[NSNumber numberWithInt:NSOnState] afterDelay:0.25];
}
//end checkLastMove:

-(void) setStateWrapped:(NSNumber*)number
{
  if (self->remainingSetStateWrapped)
    --self->remainingSetStateWrapped;
  [self setState:[number intValue]];
}
//end setStateWrapped:

-(void) setState:(int)value
{
  [super setState:value];
  if (!self->remainingSetStateWrapped)
    [[NSNotificationCenter defaultCenter] postNotificationName:DragThroughButtonStateChangedNotification object:self userInfo:nil];
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

-(BOOL) draggingEntered:(id<NSDraggingInfo>)sender
{
  [self->lastMoveDate release];
  self->lastMoveDate = [[NSDate alloc] init];
  [self performSelector:@selector(checkLastMove:) withObject:nil afterDelay:.33];
  return NSDragOperationAll;
}
//end draggingEntered:

-(BOOL) draggingUpdated:(id<NSDraggingInfo>)sender
{
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkLastMove:) object:nil];
  [self->lastMoveDate release];
  self->lastMoveDate = [[NSDate alloc] init];
  [self performSelector:@selector(checkLastMove:) withObject:nil afterDelay:.33];
  return NSDragOperationAll;
}
//end draggingExited:

-(BOOL) draggingExited:(id<NSDraggingInfo>)sender
{
  [NSRunLoop cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkLastMove:) object:nil];
  return NSDragOperationAll;
}
//end draggingExited:

@end
