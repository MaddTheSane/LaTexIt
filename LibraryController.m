//
//  LibraryController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "LibraryController.h"

#import "AppController.h"
#import "HistoryItem.h"
#import "LibraryItem.h"
#import "LibraryFile.h"
#import "LibraryManager.h"
#import "LibraryTableView.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "PreferencesController.h"
#import "NSSegmentedControlExtended.h"

@interface LibraryController (PrivateAPI)
-(void) applicationWillBecomeActive:(NSNotification*)aNotification;
-(void) _updateButtons:(NSNotification*)aNotification;
-(void) _openPanelDidEnd:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
-(void) _savePanelDidEnd:(NSSavePanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
@end

@implementation LibraryController

-(id) init
{
  if (![super initWithWindowNibName:@"Library"])
    return nil;
  return self;
}

-(void) awakeFromNib
{
  NSPanel* window = (NSPanel*)[self window];
  [window setHidesOnDeactivate:NO];//prevents from disappearing when LaTeXiT is not active
  [window setFloatingPanel:NO];//prevents from floating always above
  [window setFrameAutosaveName:@"library"];
  //[window setBecomesKeyOnlyIfNeeded:YES];//we could try that to enable item selecting without activating the window first
  //but this prevents keyDown events

  [libraryTableView setDataSource:[LibraryManager sharedManager]];
  [libraryTableView setDelegate:[LibraryManager sharedManager]];
  NSArray* items = [[LibraryManager sharedManager] allItems];
  NSEnumerator* enumerator = [items objectEnumerator];
  LibraryItem* item = [enumerator nextObject];
  while(item)
  {
    if ([item isExpanded])
      [libraryTableView expandItem:item];
    item = [enumerator nextObject];
  }

  [[importCurrentButton cell] setShowsStateBy:NSChangeGrayCellMask];//fixes a cosmetic bug of Panther
  
  NSString* iconPath = nil;
  NSImage*  image = nil;
  iconPath = [[NSBundle mainBundle] pathForResource:@"action" ofType:@"tiff"];
  image = [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease];
  [actionButton setImage:image];
  iconPath = [[NSBundle mainBundle] pathForResource:@"action-pressed" ofType:@"tiff"];
  image = [[[NSImage alloc] initWithContentsOfFile:iconPath] autorelease];
  [actionButton setAlternateImage:image];
  
  library_row_t type = (library_row_t) [[NSUserDefaults standardUserDefaults] integerForKey:LibraryViewRowTypeKey];
  [libraryRowTypeSegmentedControl selectSegmentWithTag:type];
  [self changeLibraryRowType:libraryRowTypeSegmentedControl];
  
  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(applicationWillBecomeActive:)
                             name:NSApplicationWillBecomeActiveNotification object:nil];
  [notificationCenter addObserver:self selector:@selector(_updateButtons:) name:NSWindowDidBecomeKeyNotification object:nil];
  [notificationCenter addObserver:self selector:@selector(_updateButtons:) name:NSWindowDidResignMainNotification object:nil];
  [notificationCenter addObserver:self selector:@selector(_updateButtons:) name:ImageDidChangeNotification object:nil];
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc]; 
}

-(IBAction) showOrHideWindow:(id)sender
{
  NSWindow* window = [self window];
  if ([window isVisible])
    [window orderOut:self];
  else
    [self showWindow:self];
}

-(NSArray*) selectedItems
{
  return [libraryTableView selectedItems];
}

-(BOOL) canRemoveSelectedItems
{
  return [[self window] isVisible] && ([libraryTableView selectedRow] >= 0);
}

-(BOOL) canRefreshItems
{
  NSDocument* document = [AppController currentDocument];
  NSIndexSet* selectedRowIndexes = [libraryTableView selectedRowIndexes];
  BOOL onlyOneItemSelected = ([selectedRowIndexes count] == 1);
  unsigned int firstIndex = [selectedRowIndexes firstIndex];
  return (document != nil) && onlyOneItemSelected && [[libraryTableView itemAtRow:firstIndex] isKindOfClass:[LibraryFile class]];
}

-(NSMenu*) actionMenu
{
  return [actionButton menu];
}

-(BOOL) validateMenuItem:(NSMenuItem*)menuItem
{
  BOOL ok = [[self window] isVisible];
  if ([menuItem action] == @selector(importCurrent:))
  {
    MyDocument* document = (MyDocument*) [AppController currentDocument];
    ok &= document && [document hasImage];
  }
  else if ([menuItem action] == @selector(removeSelectedItems:))
    ok &= [self canRemoveSelectedItems];
  else if ([menuItem action] == @selector(refreshItems:))
    ok &= [self canRefreshItems];
  return ok;
}

//Creates a library item with the current document state
-(IBAction) importCurrent:(id)sender
{
  MyDocument*  document = (MyDocument*) [AppController currentDocument];
  HistoryItem* historyItem = [document historyItemWithCurrentState];
  //maybe the user did modify parameter since the equation was computed : we correct it from the pdfData inside the history item
  historyItem = [HistoryItem historyItemWithPdfData:[historyItem pdfData] useDefaults:YES];
  LibraryItem* newItem = [[LibraryManager sharedManager] newFile:historyItem outlineView:libraryTableView];
  [libraryTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[libraryTableView rowForItem:newItem]]
           byExtendingSelection:NO];
}

//Creates a folder library item
-(IBAction) newFolder:(id)sender
{
  LibraryItem* newItem = [[LibraryManager sharedManager] newFolder:libraryTableView];
  [libraryTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[libraryTableView rowForItem:newItem]]
           byExtendingSelection:NO];
  [libraryTableView edit:self];
}

//remove selected items
-(IBAction) removeSelectedItems:(id)sender
{
  [libraryTableView removeSelectedItems];
}

//if one LibraryFile item is selected, update it with current document's state
-(IBAction) refreshItems:(id)sender
{
  MyDocument*  document = (MyDocument*) [AppController currentDocument];
  if (document)
  {
    unsigned int index = [[libraryTableView selectedRowIndexes] firstIndex];
    LibraryItem* item = [libraryTableView itemAtRow:index];
    if ([item isKindOfClass:[LibraryFile class]])
    {
      LibraryFile* fileItem = (LibraryFile*) item;
      HistoryItem* newValue = [document historyItemWithCurrentState];
      [[LibraryManager sharedManager] refreshFileItem:fileItem withValue:newValue];
      [libraryTableView reloadItem:item];
      
      //let's make it blink a little to inform the user that it has change
      [libraryTableView setDelegate:nil];//remove delegate to speed up blinking
      BOOL isSelected = YES;
      unsigned int itemIndex   = index;
      NSIndexSet*  itemIndexes = [NSIndexSet indexSetWithIndex:itemIndex];
      int i = 0;
      for(i = 0 ; i<7 ; ++i)
      {
        if (isSelected)
          [libraryTableView deselectRow:itemIndex];
        else
          [libraryTableView selectRowIndexes:itemIndexes byExtendingSelection:NO];
        isSelected = !isSelected;
        [libraryTableView display];
        NSDate* now = [NSDate date];
        NSDate* next = [now addTimeInterval:1./30.];
        [NSThread sleepUntilDate:next];
      }
      [libraryTableView selectRowIndexes:itemIndexes byExtendingSelection:NO];
      [libraryTableView display];
      [libraryTableView setDelegate:[LibraryManager sharedManager]];//restore delegate after blinking
    }//end if selection is LibraryFile
  }//end if document
}

-(IBAction) open:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setTitle:NSLocalizedString(@"Open library...", @"Open library...")];
  if ([[self window] isVisible])
    [openPanel beginSheetForDirectory:nil file:nil types:[NSArray arrayWithObject:@"latexlib"] modalForWindow:[self window]
                        modalDelegate:self didEndSelector:@selector(_openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
  else
    [self _openPanelDidEnd:openPanel returnCode:[openPanel runModalForTypes:[NSArray arrayWithObject:@"latexlib"]] contextInfo:NULL];
}

-(void) _openPanelDidEnd:(NSOpenPanel*)openPanel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSOKButton)
    [[LibraryManager sharedManager] loadFrom:[[[openPanel URLs] lastObject] path]];
}


-(IBAction) saveAs:(id)sender
{
  NSSavePanel* savePanel = [NSSavePanel savePanel];
  [savePanel setTitle:NSLocalizedString(@"Save library as...", @"Save library as...")];
  [savePanel setRequiredFileType:@"latexlib"];
  [savePanel setCanSelectHiddenExtension:YES];
  if ([[self window] isVisible])
    [savePanel beginSheetForDirectory:nil file:nil modalForWindow:[self window] modalDelegate:self
                       didEndSelector:@selector(_savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
  else
    [self _savePanelDidEnd:savePanel returnCode:[savePanel runModal] contextInfo:NULL];
}

-(void) _savePanelDidEnd:(NSSavePanel*)savePanel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSFileHandlingPanelOKButton)
    [[LibraryManager sharedManager] saveAs:[[savePanel URL] path]];
}

-(void) _updateButtons:(NSNotification *)aNotification
{
  //maybe all documents are closed, so we must update the import button
  MyDocument* anyDocument = (MyDocument*) [AppController currentDocument];
  [importCurrentButton setEnabled:(anyDocument && [anyDocument hasImage])];
  [[[libraryTableView superview] superview] setNeedsDisplay:YES];//to bring scrollview to front and hide the top line of the button
}

//display library when application becomes active
-(void) applicationWillBecomeActive:(NSNotification*)aNotification
{
  [self _updateButtons:nil];
  if ([[self window] isVisible])
    [[self window] orderFront:self];
}

-(IBAction) changeLibraryRowType:(id)sender
{
  int tag = [[sender cell] tagForSegment:[sender selectedSegment]];
  [libraryTableView setLibraryRowType:(library_row_t)tag];
  [[NSUserDefaults standardUserDefaults] setInteger:tag forKey:LibraryViewRowTypeKey];
}

@end