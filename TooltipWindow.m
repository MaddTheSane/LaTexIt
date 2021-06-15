//
//  TooltipWindow.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/11/10.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "TooltipWindow.h"


static NSTimeInterval defaultDuration  = 0;
static BOOL           doneInitialSetup = NO;
static NSDictionary*  textAttributes   = nil;
static NSColor*       backgroundColor  = nil;

@implementation TooltipWindow

+(void) setDefaultBackgroundColor:(NSColor*)value
{
  @synchronized(self)
  {
    if (value != backgroundColor)
    {
      [backgroundColor release];
      backgroundColor = [value copy];
    }//end if (value != backgroundColor)
  }//end @synchronized(self)
}
//end setDefaultBackgroundColor:

+(NSColor*) defaultBackgroundColor
{
  @synchronized(self)
  {
    if (!backgroundColor)
      [TooltipWindow setDefaultBackgroundColor:[NSColor colorWithDeviceRed:1.0 green:0.96 blue:0.76 alpha:1.0]];
  }
  return backgroundColor;
}
//end defaultBackgroundColor

+(void) setDefaultDuration:(NSTimeInterval)inSeconds
{
  @synchronized(self)
  {
    doneInitialSetup = YES;
    defaultDuration = inSeconds;
  }
}
//end setDefaultDuration:

+(NSTimeInterval) defaultDuration
{
  return defaultDuration;
}
//end defaultDuration

+(id) tipWithString:(NSString*)tip frame:(NSRect)frame display:(BOOL)display
{
  id result =
    [TooltipWindow tipWithAttributedString:[[[NSAttributedString alloc] initWithString:tip] autorelease] frame:frame display:display];
  return result;
}
//end tipWithString:frame:display:

+(id) tipWithAttributedString:(NSAttributedString*)tip frame:(NSRect)frame display:(BOOL)display
{
  TooltipWindow* window = [[TooltipWindow alloc] init]; // blank slate
  @synchronized(self)
  {
    if (!doneInitialSetup)
    {
      [TooltipWindow setDefaultDuration:5];
      [window setTooltip:@" "]; // Just having at least 1 char to allow the next message...
      textAttributes = [[[[window contentView] attributedStringValue] attributesAtIndex:0 effectiveRange:nil] retain];
    }//end if (!doneInitialSetup)
  }//end @synchronized(self)
  [window setTooltip:tip]; // set the tip
  [window setReleasedWhenClosed:NO]; // if we display right away we release on close
  [window setFrame:frame display:YES];
  if (display)
    [window orderFrontWithDuration:[TooltipWindow defaultDuration]]; // this is affectively autoreleasing the window after 'defaultDuration'
  return [window autorelease];
}
//end tipWithAttributedString:frame:display:

+(NSSize) suggestedSizeForTooltip:(id)tooltip
{
  NSSize tipSize = NSZeroSize;
  if ([tooltip isKindOfClass:[NSAttributedString class]])
    tipSize = [tooltip size];
  else if ([tooltip isKindOfClass:[NSString class]])
    tipSize = [tooltip sizeWithAttributes:textAttributes];
  else
    tipSize = NSZeroSize;
  if (!NSEqualSizes(tipSize, NSZeroSize))
    tipSize.width += 16;
  return tipSize;
}
//end suggestedSizeForTooltip:

-(id) init
{
  if (!(self = [super initWithContentRect:NSMakeRect(0,0,0,0)
                              styleMask:NSBorderlessWindowMask
                                backing:NSBackingStoreBuffered
                                  defer:NO]))
    return nil;
  //window setup
  [self setAlphaValue:0.90];
  [self setOpaque:NO];
  [self setBackgroundColor:[TooltipWindow defaultBackgroundColor]];
  [self setHasShadow:YES];
  [self setLevel:NSScreenSaverWindowLevel];
  [self setHidesOnDeactivate:YES];
  [self setIgnoresMouseEvents:YES];
  //textfield setup...
  NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,0,0)];
  [field setEditable:NO];
  [field setSelectable:NO];
  [field setBezeled:NO];
  [field setBordered:NO];
  [field setDrawsBackground:NO];
  [field setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [self setContentView:field];
  [self setFrame:[self frameRectForContentRect:[field frame]] display:NO];
  @synchronized([self class])
  {          
    if (!doneInitialSetup)
    {
      [TooltipWindow setDefaultDuration:5];
      [field setStringValue:@" "]; // Just having at least 1 char to allow the next message...
      textAttributes = [[[field attributedStringValue] attributesAtIndex:0 effectiveRange:nil] retain];
    }//end if (!doneInitialSetup)
  }//end @synchronized([self class])
  [field release];  
  return self;
}
//end init

-(void) dealloc
{
  [self->tooltipObject release];
  [super dealloc];
}
//end dealloc

-(id) tooltip
{
  return self->tooltipObject;
}
//end tooltip

-(void) setTooltip:(id)tip
{
  id contentView = [self contentView];
  [tip retain];
  [self->tooltipObject release];
  self->tooltipObject = tip;
  if ([contentView isKindOfClass:[NSTextField class]])
  {
    if ([tip isKindOfClass:[NSString class]])
      [contentView setStringValue:tip];
    else if ([tip isKindOfClass:[NSAttributedString class]])
      [contentView setAttributedStringValue:tip];
  }//end if ([contentView isKindOfClass:[NSTextField class]])
}
//end setTooltip:

-(void) orderFrontWithDuration:(NSTimeInterval)seconds
{
  [super orderFront:nil];
  [self performSelector:@selector(orderOut:) withObject:self afterDelay:seconds];
}
//end orderFrontWithDuration:

@end
