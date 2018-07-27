//
//  HistoryWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "HistoryWindowController.h"

#import "AppController.h"
#import "BoolTransformer.h"
#import "HistoryController.h"
#import "HistoryManager.h"
#import "HistoryView.h"
#import "MyDocument.h"
#import "NSManagedObjectContextExtended.h"
#import "PreferencesController.h"
#import "NSObjectExtended.h"
#import "NSStringExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "Utils.h"
#import "LibraryPreviewPanelImageView.h"

@interface HistoryWindowController (PrivateAPI)
-(void) clearAll:(BOOL)undoable;
-(void) applicationWillBecomeActive:(NSNotification*)aNotification;
-(void) _clearHistorySheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
-(void) _openPanelDidEnd:(NSOpenPanel*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo;
-(void) _savePanelDidEnd:(NSSavePanel*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo;
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
  
  NSImage* image = nil;
  image = [self->historyLockButton image];
  [image setSize:[self->historyLockButton frame].size];
  [self->historyLockButton setImage:image];
  image = [self->historyLockButton alternateImage];
  [image setSize:[self->historyLockButton frame].size];
  [self->historyLockButton setAlternateImage:image];
  [self->historyLockButton setState:[[HistoryManager sharedManager] isLocked] ? NSOnState : NSOffState];
  [self->historyLockButton bind:NSValueBinding toObject:[[HistoryManager sharedManager] bindController] withKeyPath:@"content.locked"
    options:[NSDictionary dictionaryWithObjectsAndKeys:
      [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState] trueValue:[NSNumber numberWithInt:NSOnState]],
      NSValueTransformerBindingOption, nil]];

  [self->importOptionPopUpButton removeAllItems];
  [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Add to current history", @"Add to current history")];
  [[self->importOptionPopUpButton lastItem] setTag:(int)HISTORY_IMPORT_MERGE];
  [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Overwrite current history", @"Overwrite current history")];
  [[self->importOptionPopUpButton lastItem] setTag:(int)HISTORY_IMPORT_OVERWRITE];

  [self->exportOnlySelectedButton setTitle:NSLocalizedString(@"Export the selection only", @"Export the selection only")];
  [self->exportFormatLabel setStringValue:NSLocalizedString(@"Format :", @"Format :")];
  NSPoint point = [self->exportFormatPopUpButton frame].origin;
  [self->exportFormatPopUpButton setFrameOrigin:NSMakePoint(NSMaxX([self->exportFormatLabel frame])+6, point.y)];
  
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
    NSUInteger nbItems = [self->historyView numberOfRows];
    [self->clearHistoryButton setEnabled:(isKeyWindow && nbItems)];
    [[self window] setTitle:[NSString stringWithFormat:@"%@ (%lu)", NSLocalizedString(@"History", @"History"), (unsigned long)nbItems]];
  }//end if ([keyPath isEqualToString:@"arrangedObjects"])
  else if ([keyPath isEqualToString:HistoryDisplayPreviewPanelKey])
    [[self->historyPreviewPanelSegmentedControl cell] setSelected:
      !change ? [[PreferencesController sharedController] historyDisplayPreviewPanelState] : [[change objectForKey:NSKeyValueChangeNewKey] boolValue]
      forSegment:0];
}
//end observeValueForKeyPath:ofObject:change:context:

-(IBAction) changeLockedState:(id)sender
{
  [[HistoryManager sharedManager] setLocked:([(NSButton*)sender state] == NSOnState)];
}
//end changeLockedState:

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
  NSAlert *alert = [NSAlert new];
  alert.messageText = NSLocalizedString(@"Clear History",@"Clear History");
  alert.informativeText = NSLocalizedString(@"Are you sure you want to clear the whole history ?\nThis operation is irreversible.",
                                            @"Are you sure you want to clear the whole history ?\nThis operation is irreversible.");
  [alert addButtonWithTitle:NSLocalizedString(@"Clear History",@"Clear History")];
  [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
  if ([[self window] isVisible])
  {
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
      if (returnCode == NSAlertFirstButtonReturn) {
        [self clearAll:NO];
      }
    }];
  }
  else
  {
    NSInteger returnCode = [alert runModal];
    if (returnCode == NSAlertFirstButtonReturn)
      [self clearAll:NO];
  }
  [alert autorelease];
}
//end clearHistory:

-(void) _clearHistorySheetDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
  if (returnCode == NSAlertFirstButtonReturn)
    [self clearAll:NO];
}
//end _clearHistorySheetDidEnd:returnCode:contextInfo:

-(IBAction) saveAs:(id)sender
{
  self->savePanel = [[NSSavePanel savePanel] retain];
  [self->savePanel setTitle:NSLocalizedString(@"Export history...", @"Export history...")];
  [self changeHistoryExportFormat:self->exportFormatPopUpButton];
  [self->savePanel setCanSelectHiddenExtension:YES];
  [self->savePanel setAccessoryView:[self->exportAccessoryView retain]];
  [self->exportOnlySelectedButton setState:NSOffState];
  [self->exportOnlySelectedButton setEnabled:([self->historyView selectedRow] >= 0)];
  if ([[self window] isVisible]) {
    savePanel.nameFieldStringValue = NSLocalizedString(@"Untitled", @"Untitled");
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
      [self _savePanelDidEnd:self->savePanel returnCode:result contextInfo:NULL];
    }];
  } else {
    [self _savePanelDidEnd:self->savePanel returnCode:[self->savePanel runModal] contextInfo:NULL];
  }
}

-(void) _savePanelDidEnd:(NSSavePanel*)theSavePanel returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSFileHandlingPanelOKButton)
  {
    BOOL onlySelection = ([exportOnlySelectedButton state] == NSOnState);
    NSArray* selectedHistoryItems = [[[self->historyView historyItemsController] arrangedObjects] objectsAtIndexes:[self->historyView selectedRowIndexes]];
    BOOL ok = [[HistoryManager sharedManager] saveAs:[[theSavePanel URL] path] onlySelection:onlySelection selection:selectedHistoryItems
                                              format:[exportFormatPopUpButton selectedTag]];
    if (!ok)
    {
      NSAlert* alert = [NSAlert new];
      alert.messageText = NSLocalizedString(@"An error occured while saving.", @"An error occured while saving.");
      alert.informativeText = @"";
      [alert runModal];
      [alert release];
    }//end if (ok)
  }
  [self->savePanel release];
  self->savePanel = nil;
}
//end _savePanelDidEnd:returnCode:contextInfo:

-(IBAction) changeHistoryExportFormat:(id)sender
{
  switch((history_export_format_t)[sender selectedTag])
  {
    case HISTORY_EXPORT_FORMAT_INTERNAL:
      savePanel.allowedFileTypes = @[@"latexhist"];
      break;
    case HISTORY_EXPORT_FORMAT_PLIST:
      savePanel.allowedFileTypes = @[@"plist"];
      break;
  }
}
//end changeLibraryExportFormat:

-(IBAction) historySearchFieldChanged:(id)sender
{
  NSString* searchString = [[[sender dynamicCastToClass:[NSSearchField class]] stringValue] trim];
  NSString* predicateString = !searchString || [searchString isEqualToString:@""] ? nil :
    [NSString stringWithFormat:@"equation.sourceText.string contains[cd] '%@'", searchString];
  NSPredicate* predicate = !predicateString? nil :
    [NSPredicate predicateWithFormat:predicateString];
  [[self->historyView historyItemsController] setFilterPredicate:predicate];
}
//end historySearchFieldChanged:

-(IBAction) open:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setDelegate:(id)self];
  [openPanel setTitle:NSLocalizedString(@"Import history...", @"Import history...")];
  [openPanel setAccessoryView:[self->importAccessoryView retain]];
  openPanel.allowedFileTypes = [NSArray arrayWithObjects:@"latexhist", @"plist", nil];
  if ([[self window] isVisible]) {
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
      [self _openPanelDidEnd:openPanel returnCode:result contextInfo:NULL];
    }];
  } else {
    [self _openPanelDidEnd:openPanel returnCode:[openPanel runModal] contextInfo:NULL];
  }
}
//end open:

-(void) _openPanelDidEnd:(NSOpenPanel*)openPanel returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
  history_import_option_t import_option = [self->importOptionPopUpButton selectedTag];
  if (returnCode == NSModalResponseOK)
  {
    BOOL ok = [[HistoryManager sharedManager] loadFrom:[[[openPanel URLs] lastObject] path] option:import_option];
    if (!ok)
    {
      NSAlert* alert = [NSAlert new];
      alert.messageText = NSLocalizedString(@"Loading error", @"Loading error");
      alert.informativeText = NSLocalizedString(@"The file does not appear to be a valid format", @"The file does not appear to be a valid format");
      [alert runModal];
      [alert release];
    }
    else
    {
      [[[HistoryManager sharedManager] managedObjectContext] processPendingChanges];
      [self->historyView reloadData];
    }
  }//end if (returnCode == NSOKButton)
}
//end _openPanelDidEnd:returnCode:contextInfo;

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
  NSUInteger nbItems = [self->historyView numberOfRows];
  [self->clearHistoryButton setEnabled:nbItems];
}
//end windowDidBecomeKey:

-(void) windowDidBecomeMain:(NSNotification *)aNotification
{
  NSUInteger nbItems = [self->historyView numberOfRows];
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
