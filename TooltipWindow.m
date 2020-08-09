//
//  TooltipWindow.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/11/10.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "TooltipWindow.h"


static NSTimeInterval defaultDuration  = 0;
static BOOL           doneInitialSetup = NO;
static NSDictionary*  textAttributes   = nil;
static NSColor*       backgroundColor  = nil;

@implementation TooltipWindow
@synthesize tooltip = tooltipObject;

+(void) setDefaultBackgroundColor:(NSColor*)value
{
  @synchronized(self)
  {
    if (value != backgroundColor)
    {
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
    [self tipWithAttributedString:[[NSAttributedString alloc] initWithString:tip] frame:frame display:display];
  return result;
}
//end tipWithString:frame:display:

+(id) tipWithAttributedString:(NSAttributedString*)tip frame:(NSRect)frame display:(BOOL)display
{
  TooltipWindow* window = [[self alloc] init]; // blank slate
  @synchronized(self)
  {
    if (!doneInitialSetup)
    {
      [TooltipWindow setDefaultDuration:5];
      window.tooltip = @" "; // Just having at least 1 char to allow the next message...
      textAttributes = [[window.contentView attributedStringValue] attributesAtIndex:0 effectiveRange:nil];
    }//end if (!doneInitialSetup)
  }//end @synchronized(self)
  window.tooltip = tip; // set the tip
  [window setReleasedWhenClosed:NO]; // if we display right away we release on close
  [window setFrame:frame display:YES];
  if (display)
    [window orderFrontWithDuration:[TooltipWindow defaultDuration]]; // this is affectively autoreleasing the window after 'defaultDuration'
  return window;
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

- (instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)style backing:(NSBackingStoreType)backingStoreType defer:(BOOL)flag
{
  return [self init];
}

-(instancetype) init
{
  if (!(self = [super initWithContentRect:NSMakeRect(0,0,0,0)
                              styleMask:NSBorderlessWindowMask
                                backing:NSBackingStoreBuffered
                                  defer:NO]))
    return nil;
  //window setup
  self.alphaValue = 0.90;
  [self setOpaque:NO];
  self.backgroundColor = [TooltipWindow defaultBackgroundColor];
  [self setHasShadow:YES];
  self.level = NSScreenSaverWindowLevel;
  [self setHidesOnDeactivate:YES];
  [self setIgnoresMouseEvents:YES];
  //textfield setup...
  NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,0,0)];
  [field setEditable:NO];
  [field setSelectable:NO];
  [field setBezeled:NO];
  [field setBordered:NO];
  [field setDrawsBackground:NO];
  field.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.contentView = field;
  [self setFrame:[self frameRectForContentRect:field.frame] display:NO];
  @synchronized([self class])
  {          
    if (!doneInitialSetup)
    {
      [TooltipWindow setDefaultDuration:5];
      field.stringValue = @" "; // Just having at least 1 char to allow the next message...
      textAttributes = [field.attributedStringValue attributesAtIndex:0 effectiveRange:nil];
    }//end if (!doneInitialSetup)
  }//end @synchronized([self class])
  return self;
}
//end init

-(void) setTooltip:(id)tip
{
  id contentView = self.contentView;
  tooltipObject = [tip copy];
  if ([contentView isKindOfClass:[NSTextField class]])
  {
    if ([tip isKindOfClass:[NSString class]])
      [contentView setStringValue:tooltipObject];
    else if ([tip isKindOfClass:[NSAttributedString class]])
      [contentView setAttributedStringValue:tooltipObject];
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
