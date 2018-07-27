//
//  HistoryWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "HistoryWindowController.h"

#import "AppController.h"
#import "HistoryController.h"
#import "HistoryManager.h"
#import "HistoryView.h"
#import "MyDocument.h"
#import "NSManagedObjectContextExtended.h"
#import "PreferencesController.h"
#import "NSUserDefaultsControllerExtended.h"
#import "Utils.h"

@interface HistoryWindowController (PrivateAPI)
-(void) clearAll:(BOOL)undoable;
-(void) applicationWillBecomeActive:(NSNotification*)aNotification;
-(void) _clearHistorySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@implementation HistoryWindowController

-(id) init
{
  if ((!(self = [super initWithWindowNibName:@"HistoryWindowController"])))
    return nil;
  self->enablePreviewImage = YES;
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:HistoryDisplayPreviewPanelKey];
  [super dealloc]; 
}
//end dealloc

-(void) awakeFromNib
{
  NSPanel* window = (NSPanel*)[self window];
  [window setHidesOnDeactivate:NO];//prevents from disappearing when LaTeXiT is not active
  [window setFloatingPanel:NO];//prevents from floating always above
  [window setFrameAutosaveName:@"history"];
  [window setTitle:NSLocalizedString(@"History", @"History")];
  [self->clearHistoryButton setTitle:NSLocalizedString(@"Remove all", @"Remove all")];
  //[window setBecomesKeyOnlyIfNeeded:YES];//we could try that to enable item selecting without activating the window first
  //but this prevents keyDown events
  
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:HistoryDisplayPreviewPanelKey options:NSKeyValueObservingOptionNew context:nil];
  [self observeValueForKeyPath:HistoryDisplayPreviewPanelKey ofObject:nil change:nil context:nil];
  [self bind:@"enablePreviewImage" toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:HistoryDisplayPreviewPanelKey] options:nil];

  [self->historyPreviewPanel setFloatingPanel:YES];
  [self->historyPreviewPanel setBackgroundColor:[NSColor clearColor]];
  [self->historyPreviewPanel setLevel:NSStatusWindowLevel];
  [self->historyPreviewPanel setAlphaValue:1.0];
  [self->historyPreviewPanel setOpaque:NO];
  [self->historyPreviewPanel setHasShadow:YES];

  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  
  [notificationCenter addObserver:self selector:@selector(applicationWillBecomeActive:)
                             name:NSApplicationWillBecomeActiveNotification object:nil];
  
  [[self->historyView historyItemsController] addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionNew context:0];
  [self observeValueForKeyPath:@"arrangedObjects" ofObject:nil change:nil context:nil];//force UI refresh
}
//end awakeFromNib

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:@"arrangedObjects"])
  {
    BOOL isKeyWindow = [[self window] isKeyWindow];
    unsigned int nbItems = [self->historyView numberOfRows];
    [self->clearHistoryButton setEnabled:(isKeyWindow && nbItems)];
    [[self window] setTitle:[NSString stringWithFormat:@"%@ (%d)", NSLocalizedString(@"History", @"History"), nbItems]];
  }//end if ([keyPath isEqualToString:@"arrangedObjects"])
  else if ([keyPath isEqualToString:HistoryDisplayPreviewPanelKey])
    [[self->historyPreviewPanelSegmentedControl cell] setSelected:
      !change ? [[PreferencesController sharedController] historyDisplayPreviewPanelState] : [[change objectForKey:NSKeyValueChangeNewKey] boolValue]
      forSegment:0];
}
//end observeValueForKeyPath:ofObject:change:context:

-(IBAction) changeHistoryDisplayPreviewPanelState:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  [preferencesController setHistoryDisplayPreviewPanelState:![preferencesController historyDisplayPreviewPanelState]];
}
//end changeHistoryDisplayPreviewPanelState:

-(HistoryView*) historyView
{
  return self->historyView;
}
//end historyView

-(IBAction) clearHistory:(id)sender
{
  if ([[self window] isVisible])
  {
    NSBeginAlertSheet(NSLocalizedString(@"Clear History",@"Clear History"),
                      NSLocalizedString(@"Clear History",@"Clear History"),
                      NSLocalizedString(@"Cancel", @"Cancel"),
                      nil, [self window], self,
                      @selector(_clearHistorySheetDidEnd:returnCode:contextInfo:), nil, NULL,
                      NSLocalizedString(@"Are you sure you want to clear the whole history ?\nThis operation is irreversible.",
                                        @"Are you sure you want to clear the whole history ?\nThis operation is irreversible."));
  }
  else
  {
    int returnCode =
      NSRunAlertPanel(NSLocalizedString(@"Clear History",@"Clear History"),
                      NSLocalizedString(@"Are you sure you want to clear the whole history ?\nThis operation is irreversible.",
                                        @"Are you sure you want to clear the whole history ?\nThis operation is irreversible."),
                      NSLocalizedString(@"Clear History",@"Clear History"),
                      NSLocalizedString(@"Cancel", @"Cancel"), nil);
    if (returnCode == NSAlertDefaultReturn)
      [self clearAll:NO];
  }
}
//end clearHistory:

-(void) _clearHistorySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
  if (returnCode == NSAlertDefaultReturn)
    [self clearAll:NO];
}
//end _clearHistorySheetDidEnd:returnCode:contextInfo:

-(BOOL) canRemoveEntries
{
  BOOL result = [[historyView historyItemsController] canRemove];
  return result;
}
//end canRemoveEntries

-(void) deselectAll:(id)sender
{
  [historyView deselectAll:sender];
}
//end deselectAll:

//the clear history button is not available if the history is not the key window
-(void) windowDidBecomeKey:(NSNotification *)aNotification
{
  unsigned int nbItems = [self->historyView numberOfRows];
  [self->clearHistoryButton setEnabled:nbItems];
}
//end windowDidBecomeKey:

-(void) windowDidBecomeMain:(NSNotification *)aNotification
{
  unsigned int nbItems = [self->historyView numberOfRows];
  [self->clearHistoryButton setEnabled:nbItems];
}
//end windowDidBecomeMain:

-(void) windowDidResignKey:(NSNotification *)aNotification
{
  [self->clearHistoryButton setEnabled:NO];
  [self->historyPreviewPanel orderOut:self];
}
//end windowDidResignKey:

//display history when application becomes active
-(void) applicationWillBecomeActive:(NSNotification*)aNotification
{
  if ([[self window] isVisible])
    [[self window] orderFront:self];
}
//end applicationWillBecomeActive:

-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;
{
  if (!image && [self->historyPreviewPanel isVisible])
    [self->historyPreviewPanel orderOut:self];
  else if (image && self->enablePreviewImage)
  {
    NSSize imageSize = [image size];
    NSRect naturalRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);
    NSRect adaptedRect = adaptRectangle(naturalRect, NSMakeRect(0, 0, 512, 512), YES, NO, NO);
    NSPoint locationOnScreen = [NSEvent mouseLocation];
    NSSize screenSize = [[NSScreen mainScreen] frame].size;
    int shiftRight = 24;
    int shiftLeft = -24-adaptedRect.size.width-16;
    int shift = (locationOnScreen.x+shiftRight+adaptedRect.size.width+16 > screenSize.width) ? shiftLeft : shiftRight;
    NSRect newFrame = NSMakeRect(MAX(0, locationOnScreen.x+shift),
                                  MIN(locationOnScreen.y-adaptedRect.size.height/2, screenSize.height-adaptedRect.size.height-16),
                                 adaptedRect.size.width+16, adaptedRect.size.height+16);
    if (image != [self->historyPreviewPanelImageView image])
      [self->historyPreviewPanelImageView setImage:image];
    [self->historyPreviewPanelImageView setBackgroundColor:backgroundColor];
    [self->historyPreviewPanel setFrame:newFrame display:image ? YES : NO];
    if (![self->historyPreviewPanel isVisible])
      [self->historyPreviewPanel orderFront:self];
  }
}
//end displayPreviewImage:backgroundColor:

-(void) setEnablePreviewImage:(BOOL)status
{
  self->enablePreviewImage = status;
}
//end setEnablePreviewImage:

-(void) windowWillClose:(NSNotification*)notification
{
  [self->historyPreviewPanel orderOut:self];
}
//end windowWillClose:

-(void) clearAll:(BOOL)undoable
{
  NSArrayController* controller = [self->historyView historyItemsController];
  NSArray* allItems = [controller arrangedObjects];
  NSManagedObjectContext* managedObjectContext = [[HistoryManager sharedManager] managedObjectContext];
  if (undoable)
    [controller removeObjects:allItems];
  else//if (!undoable)
  {
    [[managedObjectContext undoManager] removeAllActions];
    [managedObjectContext disableUndoRegistration];
    [controller removeObjects:allItems];
    [managedObjectContext enableUndoRegistration];
  }//end if (!undoable)
}
//end clearAll:

@end
