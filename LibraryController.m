//
//  LibraryController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "LibraryController.h"

#import "AppController.h"
#import "BorderlessPanel.h"
#import "HistoryItem.h"
#import "LibraryItem.h"
#import "LibraryFile.h"
#import "LibraryManager.h"
#import "LibraryPreviewPanelImageView.h";
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
-(void) windowWillClose:(NSNotification*)notification;
-(void) windowDidResignKey:(NSNotification*)notification;
@end

@implementation LibraryController

-(id) init
{
  if (![super initWithWindowNibName:@"Library"])
    return nil;
  enablePreviewImage = YES;
  return self;
}
//end init

-(void) awakeFromNib
{
  NSPanel* window = (NSPanel*)[self window];
  [window setHidesOnDeactivate:NO];//prevents from disappearing when LaTeXiT is not active
  [window setFloatingPanel:NO];//prevents from floating always above
  [window setFrameAutosaveName:@"library"];
  //[window setBecomesKeyOnlyIfNeeded:YES];//we could try that to enable item selecting without activating the window first
  //but this prevents keyDown events
  
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [libraryPreviewPanelSegmentedControl setSelected:[userDefaults boolForKey:LibraryDisplayPreviewPanelKey] forSegment:0];
  [self changeLibraryPreviewPanelSegmentedControl:libraryPreviewPanelSegmentedControl];

  [libraryPreviewPanel setFloatingPanel:YES];
  [libraryPreviewPanel setBackgroundColor:[NSColor clearColor]];
  [libraryPreviewPanel setLevel:NSStatusWindowLevel];
  [libraryPreviewPanel setAlphaValue:1.0];
  [libraryPreviewPanel setOpaque:NO];
  [libraryPreviewPanel setHasShadow:YES];

  [libraryTableView setDataSource:[LibraryManager sharedManager]];
  [libraryTableView setDelegate:[LibraryManager sharedManager]];
  BOOL oldLibraryShouldBeSaved = [[LibraryManager sharedManager] libraryShouldBeSaved];
  NSArray* items = [[LibraryManager sharedManager] allItems];
  NSEnumerator* enumerator = [items objectEnumerator];
  LibraryItem* item = [enumerator nextObject];
  while(item)
  {
    if ([item isExpanded])
      [libraryTableView expandItem:item];
    item = [enumerator nextObject];
  }
  //here, using old value, we may cancel a side effect of expand item that marks the library as needing saving
  [[LibraryManager sharedManager] setLibraryShouldBeSaved:oldLibraryShouldBeSaved];

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
  [notificationCenter addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification object:[self window]];
  [notificationCenter addObserver:self selector:@selector(windowDidResignKey:) name:NSWindowDidResignKeyNotification object:[self window]];
}
//end awakeFromNib

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc]; 
}
//end dealloc

-(IBAction) showOrHideWindow:(id)sender
{
  NSWindow* window = [self window];
  if ([window isVisible])
    [window orderOut:self];
  else
    [self showWindow:self];
}
//end showOrHideWindow:

-(NSArray*) selectedItems
{
  return [libraryTableView selectedItems];
}
//end selectedItems

-(BOOL) canRemoveSelectedItems
{
  return [[self window] isVisible] && ([libraryTableView selectedRow] >= 0);
}
//end canRemoveSelectedItems

-(BOOL) canRenameSelectedItems
{
  return [[self window] isVisible] && ([[libraryTableView selectedRowIndexes] count] == 1);
}
//end canRenameSelectedItems

-(BOOL) canRefreshItems
{
  NSDocument* document = [AppController currentDocument];
  NSIndexSet* selectedRowIndexes = [libraryTableView selectedRowIndexes];
  BOOL onlyOneItemSelected = ([selectedRowIndexes count] == 1);
  unsigned int firstIndex = [selectedRowIndexes firstIndex];
  return (document != nil) && onlyOneItemSelected && [[libraryTableView itemAtRow:firstIndex] isKindOfClass:[LibraryFile class]];
}
//end canRefreshItems

-(NSMenu*) actionMenu
{
  return [actionButton menu];
}
//end actionMenu

-(BOOL) validateMenuItem:(NSMenuItem*)menuItem
{
  BOOL ok = [[self window] isVisible];
  if ([menuItem action] == @selector(importCurrent:))
  {
    MyDocument* document = (MyDocument*) [AppController currentDocument];
    ok &= document && [document hasImage];
  }
  else if ([menuItem action] == @selector(renameItem:))
    ok &= [self canRenameSelectedItems];
  else if ([menuItem action] == @selector(removeSelectedItems:))
    ok &= [self canRemoveSelectedItems];
  else if ([menuItem action] == @selector(refreshItems:))
    ok &= [self canRefreshItems];
  return ok;
}
//end validateMenuItem:

//Creates a library item with the current document state
-(IBAction) importCurrent:(id)sender
{
  MyDocument*  document = (MyDocument*) [AppController currentDocument];
  HistoryItem* historyItem = [document historyItemWithCurrentState];
  [[[document undoManager] prepareWithInvocationTarget:document] applyHistoryItem:historyItem];
  //maybe the user did modify parameter since the equation was computed : we correct it from the pdfData inside the history item
  HistoryItem* historyItem2 = [HistoryItem historyItemWithPDFData:[historyItem pdfData] useDefaults:YES];
  LibraryItem* newItem = [[LibraryManager sharedManager] newFile:historyItem2 outlineView:libraryTableView];
  [libraryTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[libraryTableView rowForItem:newItem]]
           byExtendingSelection:NO];
  [[document windowForSheet] makeKeyWindow];
}
//end importCurrent:

//Creates a folder library item
-(IBAction) newFolder:(id)sender
{
  LibraryItem* newItem = [[LibraryManager sharedManager] newFolder:libraryTableView];
  [libraryTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[libraryTableView rowForItem:newItem]]
           byExtendingSelection:NO];
  [libraryTableView edit:self];
}
//end newFolder:

//remove selected items
-(IBAction) removeSelectedItems:(id)sender
{
  [libraryTableView removeSelectedItems];
}
//end removeSelectedItems:

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
      BOOL cancel = NO;
      if (item && [document lastAppliedLibraryFile] && (item != [document lastAppliedLibraryFile]))
      {
        NSAlert* alert =
          [NSAlert alertWithMessageText:NSLocalizedString(@"You may not be updating the good equation", @"You may not be updating the good equation")
                          defaultButton:NSLocalizedString(@"Update the equation", @"Update the equation")
                        alternateButton:NSLocalizedString(@"Cancel", @"Cancel")
                            otherButton:nil
              informativeTextWithFormat:NSLocalizedString(@"You changed the library selection since the last equation was imported into the editor",
                                                          @"You changed the library selection since the last equation was imported into the editor")];
         cancel = ([alert runModal] == NSAlertAlternateReturn);
      }

      if (!cancel)
      {
        LibraryFile* fileItem = (LibraryFile*) item;
        HistoryItem* newValue = [document historyItemWithCurrentState];
        [newValue setTitle:[fileItem title]];
        [[LibraryManager sharedManager] refreshFileItem:fileItem withValue:newValue];
        [libraryTableView reloadItem:item];
        
        //let's make it blink a little to inform the user that it has change

        //we un-register the selectionDidChange notification of the delegate to speed up blinking
        [[NSNotificationCenter defaultCenter] removeObserver:[libraryTableView delegate]
                                                        name:NSOutlineViewSelectionDidChangeNotification
                                                      object:libraryTableView];
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
          NSDate* now = [NSDate date];
          [libraryTableView display];
          NSDate* next = [now addTimeInterval:1./30.];
          [NSThread sleepUntilDate:next];
        }
        [libraryTableView selectRowIndexes:itemIndexes byExtendingSelection:NO];
        //we restore the delegate notification receiving
        [[NSNotificationCenter defaultCenter] addObserver:[libraryTableView delegate]
                                                 selector:@selector(outlineViewSelectionDidChange:)
                                                     name:NSOutlineViewSelectionDidChangeNotification
                                                   object:libraryTableView];
        [libraryTableView setNeedsDisplay:YES];
      }//end if !cancel
    }//end if selection is LibraryFile
  }//end if document
}
//end refreshItems:

-(IBAction) renameItem:(id)sender
{
  [libraryTableView edit:sender];
}
//end renameItem:

-(IBAction) open:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setTitle:NSLocalizedString(@"Import library...", @"Import library...")];
  [openPanel setAccessoryView:[importAccessoryView retain]];
  if ([[self window] isVisible])
    [openPanel beginSheetForDirectory:nil file:nil types:[NSArray arrayWithObjects:@"latexlib", @"library", nil] modalForWindow:[self window]
                        modalDelegate:self didEndSelector:@selector(_openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
  else
    [self _openPanelDidEnd:openPanel returnCode:[openPanel runModalForTypes:[NSArray arrayWithObjects:@"latexlib", @"library", nil]] contextInfo:NULL];
}
//end open:

-(void) _openPanelDidEnd:(NSOpenPanel*)openPanel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  library_import_option_t import_option = [importOptionPopUpButton selectedTag];
  if (returnCode == NSOKButton)
    [[LibraryManager sharedManager] loadFrom:[[[openPanel URLs] lastObject] path] option:import_option];
}
//end _openPanelDidEnd:returnCode:contextInfo;

-(IBAction) openDefaultLibraryPath:(id)sender
{
  [(NSOpenPanel*)[importAccessoryView window]
    setDirectory:[[[LibraryManager sharedManager] defaultLibraryPath] stringByDeletingLastPathComponent]];
}
//end openDefaultLibraryPath:

-(IBAction) saveAs:(id)sender
{
  savePanel = [[NSSavePanel savePanel] retain];
  [savePanel setTitle:NSLocalizedString(@"Export library...", @"Export library...")];
  [self changeLibraryExportFormat:exportFormatPopUpButton];
  [savePanel setCanSelectHiddenExtension:YES];
  [savePanel setAccessoryView:[exportAccessoryView retain]];
  [exportOnlySelectedButton setState:([[self selectedItems] count] ? NSOnState : NSOffState)];
  if ([[self window] isVisible])
    [savePanel beginSheetForDirectory:nil file:nil modalForWindow:[self window] modalDelegate:self
                       didEndSelector:@selector(_savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
  else
    [self _savePanelDidEnd:savePanel returnCode:[savePanel runModal] contextInfo:NULL];
}

-(void) _savePanelDidEnd:(NSSavePanel*)theSavePanel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSFileHandlingPanelOKButton)
  {
    BOOL onlySelection = ([exportOnlySelectedButton state] == NSOnState);
    [[LibraryManager sharedManager] saveAs:[[theSavePanel URL] path] onlySelection:onlySelection selection:[libraryTableView selectedItems]
                                    format:[exportFormatPopUpButton selectedTag]];
  }
  [savePanel release];
  savePanel = nil;
}
//end _savePanelDidEnd:returnCode:contextInfo:

-(IBAction) changeLibraryExportFormat:(id)sender
{
  switch((library_export_format_t)[sender selectedTag])
  {
    case LIBRARY_EXPORT_FORMAT_INTERNAL:
      [savePanel setRequiredFileType:@"latexlib"];
      break;
    case LIBRARY_EXPORT_FORMAT_PLIST:
      [savePanel setRequiredFileType:@"plist"];
      break;
  }
}
//end changeLibraryExportFormat:

-(void) _updateButtons:(NSNotification *)aNotification
{
  //maybe all documents are closed, so we must update the import button
  MyDocument* anyDocument = (MyDocument*) [AppController currentDocument];
  [importCurrentButton setEnabled:(anyDocument && [anyDocument hasImage])];
  [[[libraryTableView superview] superview] setNeedsDisplay:YES];//to bring scrollview to front and hide the top line of the button
}
//end _updateButtons:

//display library when application becomes active
-(void) applicationWillBecomeActive:(NSNotification*)aNotification
{
  [self _updateButtons:nil];
  if ([[self window] isVisible])
    [[self window] orderFront:self];
}
//end applicationWillBecomeActive:

-(IBAction) changeLibraryRowType:(id)sender
{
  int tag = [[sender cell] tagForSegment:[sender selectedSegment]];
  [libraryTableView setLibraryRowType:(library_row_t)tag];
  [[NSUserDefaults standardUserDefaults] setInteger:tag forKey:LibraryViewRowTypeKey];
}
//end changeLibraryRowType:

-(IBAction) changeLibraryPreviewPanelSegmentedControl:(id)sender
{
  int segment = [sender selectedSegment];
  BOOL status = (segment != -1) ? [sender isSelectedForSegment:segment] : NO;
  [[NSUserDefaults standardUserDefaults] setBool:status forKey:LibraryDisplayPreviewPanelKey];
  [self setEnablePreviewImage:status];
}
//end changeLibraryPreviewPanelSegmentedControl:

-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;
{
  if (!image && [libraryPreviewPanel isVisible])
    [libraryPreviewPanel orderOut:self];
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
    if (image != [libraryPreviewPanelImageView image])
      [libraryPreviewPanelImageView setImage:image];
    [libraryPreviewPanelImageView setBackgroundColor:backgroundColor];
    [libraryPreviewPanel setFrame:newFrame display:image ? YES : NO];
    if (![libraryPreviewPanel isVisible])
      [libraryPreviewPanel orderFront:self];
  }
}
//end displayPreviewImage:backgroundColor:

-(void) setEnablePreviewImage:(BOOL)status
{
  enablePreviewImage = status;
}
//end setEnablePreviewImage:

-(void) windowWillClose:(NSNotification*)notification
{
  [libraryPreviewPanel orderOut:self];
}
//end windowWillClose:

-(void) windowDidResignKey:(NSNotification*)notification
{
  [libraryPreviewPanel orderOut:self];
}
//end windowDidResignKey:

@end
