//
//  HistoryWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import "HistoryWindowController.h"

#import "AppController.h"
#import "BoolTransformer.h"
#import "HistoryController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "HistoryView.h"
#import "LatexitEquation.h"
#import "LaTeXProcessor.h"
#import "LibraryPreviewPanelImageView.h"
#import "MyDocument.h"
#import "NSManagedObjectContextExtended.h"
#import "PreferencesController.h"
#import "NSObjectExtended.h"
#import "NSStringExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "NSWorkspaceExtended.h"
#import "Utils.h"
#import "BorderlessPanel.h"

@interface HistoryWindowController (/*PrivateAPI*/)
-(void) clearAll:(BOOL)undoable;
-(void) applicationWillBecomeActive:(NSNotification*)aNotification;
-(void) _openPanelDidEnd:(NSOpenPanel*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo;
-(void) _savePanelDidEnd:(NSSavePanel*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo;
-(IBAction) relatexizeRefreshGUI:(id)sender;
-(IBAction) relatexizeAbort:(id)sender;
-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo;
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
#ifndef ARC_ENABLED
  [super dealloc];
#endif
}
//end dealloc

-(void) awakeFromNib
{
  NSPanel* window = (NSPanel*)[self window];
  [window setHidesOnDeactivate:NO];//prevents from disappearing when LaTeXiT is not active
  [window setFloatingPanel:NO];//prevents from floating always above
  [window setFrameAutosaveName:@"history"];
  [window setTitle:NSLocalizedString(@"History", @"")];
  [self->clearHistoryButton setTitle:NSLocalizedString(@"Remove all", @"")];
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
      [BoolTransformer transformerWithFalseValue:@(NSOffState) trueValue:@(NSOnState)],
      NSValueTransformerBindingOption, nil]];

  [self->importOptionPopUpButton removeAllItems];
  [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Add to current history", @"")];
  [[self->importOptionPopUpButton lastItem] setTag:(NSInteger)HISTORY_IMPORT_MERGE];
  [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Overwrite current history", @"")];
  [[self->importOptionPopUpButton lastItem] setTag:(NSInteger)HISTORY_IMPORT_OVERWRITE];

  [self->exportOnlySelectedButton setTitle:NSLocalizedString(@"Export the selection only", @"")];
  [self->exportFormatLabel setStringValue:NSLocalizedString(@"Format :", @"")];
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
    NSInteger nbItems = [self->historyView numberOfRows];
    [self->clearHistoryButton setEnabled:(isKeyWindow && nbItems)];
    [[self window] setTitle:[NSString stringWithFormat:@"%@ (%@)", NSLocalizedString(@"History", @""), @(nbItems)]];
  }//end if ([keyPath isEqualToString:@"arrangedObjects"])
  else if ([keyPath isEqualToString:HistoryDisplayPreviewPanelKey])
    [[self->historyPreviewPanelSegmentedControl cell] setSelected:
      !change ? [[PreferencesController sharedController] historyDisplayPreviewPanelState] : [[change objectForKey:NSKeyValueChangeNewKey] boolValue]
      forSegment:0];
}
//end observeValueForKeyPath:ofObject:change:context:

-(IBAction) changeLockedState:(id)sender
{
  [[HistoryManager sharedManager] setLocked:([sender state] == NSOnState)];
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
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = NSLocalizedString(@"Clear History", @"");
  alert.informativeText = NSLocalizedString(@"Are you sure you want to clear the whole history ?\nThis operation is irreversible.", @"");
  NSButton *desButton = [alert addButtonWithTitle:NSLocalizedString(@"Clear History", @"")];
  if (@available(macOS 11.0, *)) {
    desButton.hasDestructiveAction = YES;
  }
  [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
  if ([[self window] isVisible])
  {
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
      if (returnCode == NSAlertFirstButtonReturn) {
        [self clearAll:NO];
      }
      [alert release];
    }];
  }
  else
  {
    NSInteger returnCode = [alert runModal];
    if (returnCode == NSAlertFirstButtonReturn)
      [self clearAll:NO];
    [alert release];
  }
}
//end clearHistory:

-(IBAction) saveAs:(id)sender
{
  self->savePanel = [[NSSavePanel savePanel] retain];
  [self->savePanel setTitle:NSLocalizedString(@"Export history...", @"")];
  [self changeHistoryExportFormat:self->exportFormatPopUpButton];
  [self->savePanel setCanSelectHiddenExtension:YES];
  [self->savePanel setAccessoryView:[self->exportAccessoryView retain]];
  /*if ([self->saxvePanel respondsToSelector:@selector(setAccessoryViewDisclosed:)])
    [self->savePanel setAccessoryViewDisclosed:NO];*/
  [self->exportOnlySelectedButton setState:NSOffState];
  [self->exportOnlySelectedButton setEnabled:([self->historyView selectedRow] >= 0)];
  [self->savePanel setNameFieldStringValue:NSLocalizedString(@"Untitled", @"")];
  if ([[self window] isVisible])
    [self->savePanel beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result) {
      [self _savePanelDidEnd:self->savePanel returnCode:result contextInfo:0];
    }];
  else
    [self _savePanelDidEnd:self->savePanel returnCode:[self->savePanel runModal] contextInfo:NULL];
}

-(void) _savePanelDidEnd:(NSSavePanel*)theSavePanel returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSModalResponseOK)
  {
    BOOL onlySelection = ([exportOnlySelectedButton state] == NSOnState);
    NSArray* selectedHistoryItems = [[[self->historyView historyItemsController] arrangedObjects] objectsAtIndexes:[self->historyView selectedRowIndexes]];
    BOOL ok = [[HistoryManager sharedManager] saveAs:[[theSavePanel URL] path] onlySelection:onlySelection selection:selectedHistoryItems
                                              format:(history_export_format_t)[exportFormatPopUpButton selectedTag]];
    if (!ok)
    {
      NSAlert* alert = [[NSAlert alloc] init];
      alert.messageText = NSLocalizedString(@"An error occured while saving.", @"");
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
      [self->savePanel setAllowedFileTypes:@[@"latexhist"]];
      break;
    case HISTORY_EXPORT_FORMAT_PLIST:
      [self->savePanel setAllowedFileTypes:@[@"plist"]];
      break;
  }
}
//end changeLibraryExportFormat:

-(IBAction) historySearchFieldChanged:(id)sender
{
  NSString* searchString = [[[sender dynamicCastToClass:[NSSearchField class]] stringValue] trim];
  NSString* predicateString = !searchString || [searchString isEqualToString:@""] ? nil :
    [NSString stringWithFormat:@"equation.sourceText.string contains[cd] '%@'", searchString];
  NSPredicate* predicate = !predicateString? nil : [NSPredicate predicateWithFormat:predicateString];
  [[self->historyView historyItemsController] setFilterPredicate:predicate];
}
//end historySearchFieldChanged:

-(IBAction) open:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setDelegate:(id)self];
  [openPanel setTitle:NSLocalizedString(@"Import history...", @"")];
  [openPanel setAccessoryView:[self->importAccessoryView retain]];
  if ([openPanel respondsToSelector:@selector(setAccessoryViewDisclosed:)])
    [openPanel setAccessoryViewDisclosed:NO];
  [openPanel setAllowedFileTypes:@[@"latexhist", @"plist"]];
  if ([[self window] isVisible])
    [openPanel beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse result) {
      [self _openPanelDidEnd:openPanel returnCode:result contextInfo:0];
    }];
  [self _openPanelDidEnd:openPanel returnCode:[openPanel runModal] contextInfo:NULL];
}
//end open:

-(void) _openPanelDidEnd:(NSOpenPanel*)openPanel returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
  history_import_option_t import_option = (history_import_option_t)[self->importOptionPopUpButton selectedTag];
  if (returnCode == NSModalResponseOK)
  {
    BOOL ok = [[HistoryManager sharedManager] loadFrom:[[[openPanel URLs] lastObject] path] option:import_option];
    if (!ok)
    {
      NSAlert* alert = [[NSAlert alloc] init];
      alert.messageText = NSLocalizedString(@"Loading error", @"");
      alert.informativeText = NSLocalizedString(@"The file does not appear to be a valid format", @"");
     [alert runModal];
      [alert release];
    }
    else
    {
      [[[HistoryManager sharedManager] managedObjectContext] processPendingChanges];
      [self->historyView reloadData];
    }
  }//end if (returnCode == NSModalResponseOK)
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
  NSInteger nbItems = [self->historyView numberOfRows];
  [self->clearHistoryButton setEnabled:(nbItems>0)];
}
//end windowDidBecomeKey:

-(void) windowDidBecomeMain:(NSNotification *)aNotification
{
  NSInteger nbItems = [self->historyView numberOfRows];
  [self->clearHistoryButton setEnabled:(nbItems>0)];
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
    NSInteger shiftRight = 24;
    NSInteger shiftLeft = -24-adaptedRect.size.width-16;
    NSInteger shift = (locationOnScreen.x+shiftRight+adaptedRect.size.width+16 > screenSize.width) ? shiftLeft : shiftRight;
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

-(IBAction) relatexizeRefreshGUI:(id)sender
{
  NSString* title = [NSString stringWithFormat:@"%@... (%llu/%llu)", NSLocalizedString(@"latexize selection again", @""), (unsigned long long)self->relatexizeCurrentIndex+1, (unsigned long long)self->relatexizeCurrentCount];
  [self->relatexizeProgressTextField setStringValue:title];
  [self->relatexizeProgressIndicator setDoubleValue:!self->relatexizeCurrentCount ? 0. : (1.*(self->relatexizeCurrentIndex+1)/self->relatexizeCurrentCount)];
}
//end relatexizeRefreshGUI:

-(IBAction) relatexizeAbort:(id)sender
{
  self->relatexizeAbortMonitor = YES;
}
//end relatexizeAbort:

-(IBAction) relatexizeSelectedItems:(id)sender
{
  NSArray* selectedLibraryItems = [self->historyView selectedItems];
  NSMutableArray* inputQueue = [NSMutableArray arrayWithArray:selectedLibraryItems];
  NSMutableArray* flattenedEquations = [NSMutableArray arrayWithCapacity:[inputQueue count]];
  while([inputQueue count] != 0)
  {
    HistoryItem* historyItem = [[inputQueue objectAtIndex:0] dynamicCastToClass:[HistoryItem class]];
    [inputQueue removeObjectAtIndex:0];
    LatexitEquation* equation = [historyItem equation];
    if (equation)
      [flattenedEquations addObject:equation];
  }//end while([inputQueue count] != 0)
  NSUInteger itemsToLatexizeCount = [flattenedEquations count];
  if (itemsToLatexizeCount)
  {
    self->relatexizeAbortMonitor = NO;
    self->relatexizeCurrentIndex = 0;
    self->relatexizeCurrentCount = itemsToLatexizeCount;
    [self->relatexizeProgressIndicator setMinValue:0.];
    [self->relatexizeProgressIndicator setMaxValue:1.];
    [self->relatexizeProgressIndicator setDoubleValue:0.];
    [self->relatexizeProgressIndicator startAnimation:self];
    [self->relatexizeAbortButton setTarget:self];
    [self->relatexizeAbortButton setAction:@selector(relatexizeAbort:)];
    [self.window beginSheet:self->relatexizeWindow completionHandler:^(NSModalResponse returnCode) {
      [self sheetDidEnd:self->relatexizeWindow returnCode:returnCode contextInfo:NULL];
    }];
    [self->relatexizeTimer release];
    self->relatexizeTimer = [[NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(relatexizeRefreshGUI:) userInfo:nil repeats:YES] retain];
    [self relatexizeRefreshGUI:self];
    [self->relatexizeMonitor release];
    self->relatexizeMonitor = [[NSConditionLock alloc] initWithCondition:0];
    [NSApplication detachDrawingThread:@selector(relatexizeItemsThreadFunction:) toTarget:self withObject:flattenedEquations];
  }//end itemsToLatexizeCount
}
//end relatexizeSelectedItems:

-(void) relatexizeItemsThreadFunction:(id)object
{
  [self->relatexizeMonitor lockWhenCondition:0];
  NSArray* flattenedLibraryEquations = [object dynamicCastToClass:[NSArray class]];
  
  LaTeXProcessor* latexProcessor = [LaTeXProcessor sharedLaTeXProcessor];
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSDictionary* compositionConfiguration = [preferencesController compositionConfigurationDocument];
  CGFloat topMargin = [preferencesController marginsAdditionalTop];
  CGFloat leftMargin = [preferencesController marginsAdditionalLeft];
  CGFloat bottomMargin = [preferencesController marginsAdditionalBottom];
  CGFloat rightMargin = [preferencesController marginsAdditionalRight];
  NSArray* additionalFilesPaths = [preferencesController additionalFilesPaths];
  NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
  NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-history"];
  NSDictionary* fullEnvironment  = [latexProcessor fullEnvironment];
  NSString* fullLog = nil;
  NSArray* errors = nil;
  self->relatexizeCurrentIndex = 0;
  self->relatexizeCurrentCount = [flattenedLibraryEquations count];
  NSEnumerator* enumerator = [flattenedLibraryEquations objectEnumerator];
  id flattenedItem = nil;
  while(!self->relatexizeAbortMonitor && ((flattenedItem = [enumerator nextObject])))
  {
    @autoreleasepool {
    @try{
      LatexitEquation* latexitEquation = [flattenedItem dynamicCastToClass:[LatexitEquation class]];
      if (latexitEquation)
      {
        NSData* newPdfData = nil;
        [latexProcessor
          latexiseWithPreamble:[[latexitEquation preamble] string]
                          body:[[latexitEquation sourceText] string]
                         color:[latexitEquation color]
                          mode:[latexitEquation mode]
                 magnification:[latexitEquation pointSize]
      compositionConfiguration:compositionConfiguration
               backgroundColor:[latexitEquation backgroundColor]
                         title:[latexitEquation title]
                    leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin
          additionalFilesPaths:additionalFilesPaths
              workingDirectory:workingDirectory
               fullEnvironment:fullEnvironment
              uniqueIdentifier:uniqueIdentifier outFullLog:&fullLog outErrors:&errors
               outPdfData:&newPdfData];
        if (newPdfData)
          [latexitEquation setPdfData:newPdfData];
      }//end if (latexitEquation)
      ++self->relatexizeCurrentIndex;
    }
    @catch(NSException* e){
      DebugLog(0, @"exception : <%@>", e);
    }
    }//@autoreleasepool
  }//end for each libraryItem
  [self->relatexizeMonitor unlockWithCondition:1];
  [self.window performSelectorOnMainThread:@selector(endSheet:) withObject:self->relatexizeWindow waitUntilDone:NO];
}
//end relatexizeItemsThreadFunction:

-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
  if (sheet == self->relatexizeWindow)
  {
    [self->relatexizeMonitor lockWhenCondition:1];
    [self->relatexizeMonitor unlockWithCondition:1];
    [self->relatexizeMonitor release];
    self->relatexizeMonitor = nil;
    [self->relatexizeTimer invalidate];
    [self->relatexizeTimer release];
    self->relatexizeTimer = nil;
    [[HistoryManager sharedManager] vacuum];
    [self->relatexizeProgressIndicator stopAnimation:self];
    [sheet orderOut:self];
  }//end if (sheet == self->relatexizeWindow)
  else//if (sheet != self->relatexizeWindow)
  {
    [sheet orderOut:self];
    [self->historyView reloadData];
  }//end if (sheet != self->relatexizeWindow)
}
//end sheetDidEnd:returnCode:contextInfo:

@end
