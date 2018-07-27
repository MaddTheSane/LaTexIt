//
//  DragFilterWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/10.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.
//

#import "DragFilterWindowController.h"

#import "AppController.h"
#import "DragThroughButton.h"
#import "NSButtonPalette.h"
#import "PreferencesController.h"
#import "Utils.h"

@interface DragFilterWindowController (PrivateAPI)
-(void) updateAnimation:(NSTimer*)timer;
-(void) notified:(NSNotification*)notification;
@end

@implementation DragFilterWindowController

-(id) init
{
  if ((!(self = [super initWithWindowNibName:@"DragFilterWindowController"])))
    return nil;
  self->animationDurationIn  = .33;
  self->animationDurationOut = .10;
  return self;
}
//end init

-(void) dealloc
{
  [self->animationTimer invalidate];
  [self->animationTimer release];
  [self->animationStartDate release];
  [self->buttonPalette release];
  [super dealloc]; 
}
//end dealloc

-(void) awakeFromNib
{
  [self->dragFilterViewLabel setStringValue:NSLocalizedString(@"Drag through areas to change export type", @"Drag through areas to change export type")];
  self->buttonPalette = [[NSButtonPalette alloc] init];
  [self->buttonPalette setExclusive:YES];
  NSEnumerator* enumerator = [[self->dragFilterButtonsView subviews] objectEnumerator];
  NSView* view = nil;
  while((view = [enumerator nextObject]))
  {
    if ([view isKindOfClass:[NSButton class]])
      [self->buttonPalette add:(NSButton*)view];
  }//end while((view = [enumerator nextObject]))
  [self->closeButton setShouldBlink:NO];
  [self->closeButton setDelay:.05];

  [[self->buttonPalette buttonWithTag:EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS] setTitle:
    NSLocalizedString(@"PDF w.o.f.", @"PDF w.o.f.")];

  [[self->buttonPalette buttonWithTag:[[PreferencesController sharedController] exportFormatCurrentSession]] setState:NSOnState];

  BOOL isPdfToSvgAvailable = [[AppController appController] isPdfToSvgAvailable];
  [[self->buttonPalette buttonWithTag:EXPORT_FORMAT_SVG] setEnabled:isPdfToSvgAvailable];
  [[self->buttonPalette buttonWithTag:EXPORT_FORMAT_SVG] setToolTip:isPdfToSvgAvailable ? nil :
    [NSString stringWithFormat:NSLocalizedString(@"%@ is required", @"%@ is required"), @"pdf2svg"]];
  
  BOOL isPerlWithLibXMLAvailable = [[AppController appController] isPerlWithLibXMLAvailable];
  [[self->buttonPalette buttonWithTag:EXPORT_FORMAT_MATHML] setEnabled:isPerlWithLibXMLAvailable];
  [[self->buttonPalette buttonWithTag:EXPORT_FORMAT_MATHML] setToolTip:isPerlWithLibXMLAvailable ? nil :
    NSLocalizedString(@"The XML::LibXML perl module must be installed", @"The XML::LibXML perl module must be installed")];

  [[self->buttonPalette buttonWithTag:EXPORT_FORMAT_TEXT] setTitle:NSLocalizedString(@"Text", @"Text")];
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notified:) name:DragThroughButtonStateChangedNotification object:nil];
}
//end awakeFromNib

-(void) setWindowVisible:(BOOL)visible withAnimation:(BOOL)animate
{
  NSPoint mouseLocation = [NSEvent mouseLocation];
  [self setWindowVisible:visible withAnimation:animate atPoint:mouseLocation];
}
//end setWindowVisible:withAnimation:

-(void) setWindowVisible:(BOOL)visible withAnimation:(BOOL)animate atPoint:(NSPoint)point
{
  [self setWindowVisible:visible withAnimation:animate atPoint:point isHintOnly:YES];
}
//end setWindowVisible:withAnimation:atPoint:

-(void) setWindowVisible:(BOOL)visible withAnimation:(BOOL)animate atPoint:(NSPoint)point isHintOnly:(BOOL)isHintOnly
{
  if (visible)
  {
    NSWindow* screenWindow = [NSApp keyWindow];
    screenWindow = screenWindow ? screenWindow: [NSApp mainWindow];
    NSRect screenVisibleFrame = [(!screenWindow ? [NSScreen mainScreen] : [screenWindow screen]) visibleFrame];
    NSWindow* window = [self window];
    NSRect windowFrame = [window frame];
    NSPoint newFrameOrigin = !isHintOnly ? point : NSMakePoint(point.x-windowFrame.size.width/2, point.y+32);
    if (isHintOnly)
    {
      newFrameOrigin.x = MAX(0, newFrameOrigin.x);
      newFrameOrigin.x = MIN(screenVisibleFrame.size.width-windowFrame.size.width, newFrameOrigin.x);
      newFrameOrigin.y = MAX(0, newFrameOrigin.y);
      newFrameOrigin.y = MIN(screenVisibleFrame.size.height-windowFrame.size.height, newFrameOrigin.y);
    }//end if (isHintOnly)
    self->fromFrameOrigin = [[self window] isVisible] ? [window frame].origin : newFrameOrigin;
    self->toFrameOrigin = newFrameOrigin;
    [[self window] setFrameOrigin:self->fromFrameOrigin];
    [self->animationStartDate release];
    self->animationStartDate = [[NSDate alloc] init];
    [self->animationTimer invalidate];
    [self->animationTimer release];
    self->animationTimer = nil;
    self->animationStartAlphaValue = ![[self window] isVisible] ? 0 : [[self window] alphaValue];
    [[self window] setAlphaValue:self->animationStartAlphaValue];
    [self showWindow:self];
    if (animate)
      self->animationTimer = [[NSTimer scheduledTimerWithTimeInterval:1./25. target:self selector:@selector(updateAnimation:) userInfo:[NSNumber numberWithBool:visible] repeats:YES] retain];
    else
      [[self window] setAlphaValue:1];
  }
  else// if (!visible)
  {
    [self->animationStartDate release];
    self->animationStartDate = [[NSDate alloc] init];
    [self->animationTimer invalidate];
    [self->animationTimer release];
    self->animationTimer = nil;
    if (animate)
      self->animationTimer = [[NSTimer scheduledTimerWithTimeInterval:1./25. target:self selector:@selector(updateAnimation:) userInfo:[NSNumber numberWithBool:visible] repeats:YES] retain];
    else
      [[self window] close];
  }
}
//end setVisible:withAnimation:atPoint:isHintOnly:

-(void) updateAnimation:(NSTimer*)timer
{
  NSTimeInterval timeElapsed = !self->animationStartDate ? 0. :
    [[NSDate date] timeIntervalSinceDate:self->animationStartDate];
  BOOL toVisible = [[timer userInfo] boolValue];
  NSTimeInterval animationDuration = toVisible ? self->animationDurationIn : self->animationDurationOut;
  timeElapsed = Clip_d(0., timeElapsed, animationDuration);
  double evolution = !animationDuration ? 1. : Clip_d(0., timeElapsed/animationDuration, 1.);
  if (toVisible)
    [[self window] setAlphaValue:(1-evolution)*self->animationStartAlphaValue+evolution*1.];
  else
    [[self window] setAlphaValue:(1-evolution)*self->animationStartAlphaValue+evolution*0.];
  NSPoint currentFrameOrigin = NSMakePoint((1-evolution)*fromFrameOrigin.x+evolution*toFrameOrigin.x,
                                           (1-evolution)*fromFrameOrigin.y+evolution*toFrameOrigin.y);
  [[self window] setFrameOrigin:currentFrameOrigin];
  if (evolution >= 1)
  {
    self->fromFrameOrigin = [[self window] frame].origin;
    if (!toVisible)
      [[self window] close];
  }//end if (evolution >=1)
}
//end updateAnimation:

-(void) notified:(NSNotification*)notification
{
  if ([[notification name] isEqualToString:DragThroughButtonStateChangedNotification])
  {
    DragThroughButton* dragThroughButton = [notification object];
    if ([dragThroughButton state] == NSOnState)
    {
      int tag = [dragThroughButton tag];
      if (tag < 0)
        [self setWindowVisible:NO withAnimation:YES];
      else//if (tag >= 0)
      {
        [[PreferencesController sharedController] setExportFormatCurrentSession:(export_format_t)tag];
        [self dragFilterWindowController:self exportFormatDidChange:[[PreferencesController sharedController] exportFormatCurrentSession]];
      }//end if (tag >= 0)
    }//end if ([dragThroughButton state] == NSOnState)
  }//end if ([[notification name] isEqualToString:DragThroughButtonStateChangedNotification])
}
//end notified:

-(id) delegate
{
  return self->delegate;
}
//end delegate

-(void) setDelegate:(id)value
{
  self->delegate = value;
}
//end setDelegate:

-(void) dragFilterWindowController:(DragFilterWindowController*)dragFilterWindowController exportFormatDidChange:(export_format_t)exportFormat
{
  if (self->delegate && [self->delegate respondsToSelector:@selector(dragFilterWindowController:exportFormatDidChange:)])
    [self->delegate dragFilterWindowController:self exportFormatDidChange:exportFormat];
}
//end dragFilterWindowController:exportFormatDidChange:

@end
