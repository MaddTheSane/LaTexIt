//
//  HistoryController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.
//

#import "HistoryController.h"

#import "AppController.h"
#import "HistoryManager.h"
#import "HistoryTableView.h"
#import "MyDocument.h"

@interface HistoryController (PrivateAPI)
-(void) applicationWillBecomeActive:(NSNotification*)aNotification;
-(void) _historyDidChange:(NSNotification*)notification;
-(void) _clearHistorySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@implementation HistoryController

-(id) init
{
  if (![super initWithWindowNibName:@"History"])
    return nil;
  enablePreviewImage = YES;
  return self;
}

-(void) awakeFromNib
{
  NSPanel* window = (NSPanel*)[self window];
  [window setHidesOnDeactivate:NO];//prevents from disappearing when LaTeXiT is not active
  [window setFloatingPanel:NO];//prevents from floating always above
  [window setFrameAutosaveName:@"history"];
  //[window setBecomesKeyOnlyIfNeeded:YES];//we could try that to enable item selecting without activating the window first
  //but this prevents keyDown events

  [historyTableView setDataSource:[HistoryManager sharedManager]];
  [historyTableView setDelegate:[HistoryManager sharedManager]];
  
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [historyPreviewPanelSegmentedControl setSelected:[userDefaults boolForKey:HistoryDisplayPreviewPanelKey] forSegment:0];
  [self changeHistoryPreviewPanelSegmentedControl:historyPreviewPanelSegmentedControl];

  [historyPreviewPanel setFloatingPanel:YES];
  [historyPreviewPanel setBackgroundColor:[NSColor clearColor]];
  [historyPreviewPanel setLevel:NSStatusWindowLevel];
  [historyPreviewPanel setAlphaValue:1.0];
  [historyPreviewPanel setOpaque:NO];
  [historyPreviewPanel setHasShadow:YES];

  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  
  [notificationCenter addObserver:self selector:@selector(applicationWillBecomeActive:)
                             name:NSApplicationWillBecomeActiveNotification object:nil];
  [notificationCenter addObserver:self selector:@selector(_historyDidChange:) name:HistoryDidChangeNotification object:nil];

  //posts historyDidChange to update "clear history" button state (self) and update column header (historyTableView)
  BOOL oldHistoryShouldBeSaved = [[HistoryManager sharedManager] historyShouldBeSaved];
  [[NSNotificationCenter defaultCenter] postNotificationName:HistoryDidChangeNotification object:nil];
  //but the historyDidChange notification sets <historyDidChange> to YES as a side effect; we may cancel it using old value
  [[HistoryManager sharedManager] setHistoryShouldBeSaved:oldHistoryShouldBeSaved];
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc]; 
}

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
      [[HistoryManager sharedManager] clearAll];
  }
}

-(void) _clearHistorySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
  if (returnCode == NSAlertDefaultReturn)
    [[HistoryManager sharedManager] clearAll];
}

-(IBAction) removeHistoryEntries:(id)sender
{
  [historyTableView deleteBackward:sender];
}

-(BOOL) canRemoveEntries
{
  return ([historyTableView selectedRow] >= 0);
}

-(void) deselectAll:(id)sender
{
  [historyTableView deselectAll:sender];
}

//if a selection is made in the history, updates the document state
-(void) _historyDidChange:(NSNotification*)notification
{
  BOOL isKeyWindow = [[self window] isKeyWindow];
  [clearHistoryButton setEnabled:(isKeyWindow && [[[HistoryManager sharedManager] historyItems] count])];
  [[self window] setTitle:[NSString stringWithFormat:@"%@ (%d)", 
                                    NSLocalizedString(@"History", @"History"), [[[HistoryManager sharedManager] historyItems] count]]];
}

//the clear history button is not available if the history is not the key window
-(void) windowDidBecomeKey:(NSNotification *)aNotification
{
  [clearHistoryButton setEnabled:[[[HistoryManager sharedManager] historyItems] count]];
}

-(void) windowDidBecomeMain:(NSNotification *)aNotification
{
  [clearHistoryButton setEnabled:[[[HistoryManager sharedManager] historyItems] count]];
}

-(void) windowDidResignKey:(NSNotification *)aNotification
{
  [clearHistoryButton setEnabled:NO];
  [historyPreviewPanel orderOut:self];
}

//display history when application becomes active
-(void) applicationWillBecomeActive:(NSNotification*)aNotification
{
  if ([[self window] isVisible])
    [[self window] orderFront:self];
}

//preview pane
-(IBAction) changeHistoryPreviewPanelSegmentedControl:(id)sender
{
  int segment = [sender selectedSegment];
  BOOL status = (segment != -1) ? [sender isSelectedForSegment:segment] : NO;
  [[NSUserDefaults standardUserDefaults] setBool:status forKey:HistoryDisplayPreviewPanelKey];
  [self setEnablePreviewImage:status];
}

-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;
{
  if (!image && [historyPreviewPanel isVisible])
    [historyPreviewPanel orderOut:self];
  else if (image && enablePreviewImage)
  {
    NSSize imageSize = [image size];
    NSPoint locationOnScreen = [NSEvent mouseLocation];
    NSSize screenSize = [[NSScreen mainScreen] frame].size;
    int shiftRight = 24;
    int shiftLeft = -24-imageSize.width-16;
    int shift = (locationOnScreen.x+shiftRight+imageSize.width+16 > screenSize.width) ? shiftLeft : shiftRight;
    NSRect newFrame = NSMakeRect(MAX(0, locationOnScreen.x+shift),
                                  MIN(locationOnScreen.y-imageSize.height/2, screenSize.height-imageSize.height-16),
                                 imageSize.width+16, imageSize.height+16);
    if (image != [historyPreviewPanelImageView image])
      [historyPreviewPanelImageView setImage:image];
    [historyPreviewPanelImageView setBackgroundColor:backgroundColor];
    [historyPreviewPanel setFrame:newFrame display:image ? YES : NO];
    if (![historyPreviewPanel isVisible])
      [historyPreviewPanel orderFront:self];
  }
}

-(void) setEnablePreviewImage:(BOOL)status
{
  enablePreviewImage = status;
}

-(void) windowWillClose:(NSNotification*)notification
{
  [historyPreviewPanel orderOut:self];
}

@end
