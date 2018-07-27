//
//  LibraryWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "LibraryWindowController.h"

#import "AppController.h"
#import "BorderlessPanel.h"
#import "LatexitEquation.h"
#import "LibraryController.h"
#import "LibraryEquation.h"
#import "LibraryItem.h"
#import "LibraryGroupItem.h"
#import "LibraryManager.h"
#import "LibraryPreviewPanelImageView.h";
#import "LibraryView.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSSegmentedControlExtended.h"
#import "NSOutlineViewExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

extern NSString* NSMenuDidBeginTrackingNotification;

@interface LibraryWindowController (PrivateAPI)
-(void) applicationWillBecomeActive:(NSNotification*)aNotification;
-(void) _updateButtons:(NSNotification*)aNotification;
-(void) _openPanelDidEnd:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
-(void) _savePanelDidEnd:(NSSavePanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
-(void) windowWillClose:(NSNotification*)notification;
-(void) windowDidResignKey:(NSNotification*)notification;
@end

@implementation LibraryWindowController

-(id) init
{
  if ((!(self = [super initWithWindowNibName:@"LibraryWindowController"])))
    return nil;
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:LibraryDisplayPreviewPanelKey];
  [super dealloc]; 
}
//end dealloc

-(void) awakeFromNib
{
  NSPanel* window = (NSPanel*)[self window];
  [window setTitle:NSLocalizedString(@"Library", @"Library")];
  [window setHidesOnDeactivate:NO];//prevents from disappearing when LaTeXiT is not active
  [window setFloatingPanel:NO];//prevents from floating always above
  [window setFrameAutosaveName:@"library"];
  //[window setBecomesKeyOnlyIfNeeded:YES];//we could try that to enable item selecting without activating the window first
  //but this prevents keyDown events

  [self->importHomeButton setToolTip:NSLocalizedString(@"Reach default library", @"Reach default library")];
  [self->importOptionPopUpButton removeAllItems];
  [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Add to current library", @"Add to current library")];
  [[self->importOptionPopUpButton lastItem] setTag:(int)LIBRARY_IMPORT_MERGE];
  [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Overwrite current library", @"Overwrite current library")];
  [[self->importOptionPopUpButton lastItem] setTag:(int)LIBRARY_IMPORT_OVERWRITE];
  [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Change library in use", @"Change library in use")];
  [[self->importOptionPopUpButton lastItem] setTag:(int)LIBRARY_IMPORT_OPEN];

  [self->exportOnlySelectedButton setTitle:NSLocalizedString(@"Export the selection only", @"Export the selection only")];
  [self->exportFormatLabel setStringValue:NSLocalizedString(@"Format :", @"Format :")];
  NSPoint point = [self->exportFormatPopUpButton frame].origin;
  [self->exportFormatPopUpButton setFrameOrigin:NSMakePoint(NSMaxX([self->exportFormatLabel frame])+6, point.y)];
  
  NSMenu* actionMenu = [[NSMenu alloc] init];
  [actionMenu addItem:[NSMenuItem separatorItem]];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Add a folder", @"Add a folder") action:@selector(newFolder:) keyEquivalent:@""] setTarget:self];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Add current equation", @"Add current equation") action:@selector(importCurrent:) keyEquivalent:@""] setTarget:self];
  [actionMenu addItem:[NSMenuItem separatorItem]];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Rename selection", @"Rename selection") action:@selector(renameItem:) keyEquivalent:@""] setTarget:self];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Remove selection", @"Remove selection") action:@selector(removeSelectedItems:) keyEquivalent:@""] setTarget:self];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Replace current equation", @"Replace current equation") action:@selector(refreshItems:) keyEquivalent:@""] setTarget:self];
  [actionMenu addItem:[NSMenuItem separatorItem]];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Import...", @"Import...") action:@selector(open:) keyEquivalent:@""] setTarget:self];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Export...", @"Export...") action:@selector(saveAs:) keyEquivalent:@""] setTarget:self];
  [self->actionButton setMenu:actionMenu];
  [actionMenu setDelegate:self];
  [actionMenu release];
  [self->actionButton setToolTip:NSLocalizedString(@"Add to current library", @"Add to current library")];
  if (!isMacOS10_5OrAbove())//fix an interface bug to refresh the button
  {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuWillOpen:) name:NSMenuDidBeginTrackingNotification object:actionMenu];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidClose:) name:NSMenuDidEndTrackingNotification object:actionMenu];
  }//end if (!isMacOS10_5OrAbove())
  
  [self->libraryPreviewPanelSegmentedControl setToolTip:NSLocalizedString(@"Display the equations in real size on mouse over", @"Display the equations in real size on mouse over")];
  
  [self->libraryPreviewPanel setFloatingPanel:YES];
  [self->libraryPreviewPanel setBackgroundColor:[NSColor clearColor]];
  [self->libraryPreviewPanel setLevel:NSStatusWindowLevel];
  [self->libraryPreviewPanel setAlphaValue:1.0];
  [self->libraryPreviewPanel setOpaque:NO];
  [self->libraryPreviewPanel setHasShadow:YES];

  [self->actionButton setImage:[NSImage imageNamed:@"action.tiff"]];
  [self->actionButton setAlternateImage:[NSImage imageNamed:@"action-pressed.tiff"]];
  
  [self->libraryRowTypeSegmentedControl bind:NSSelectedTagBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:LibraryViewRowTypeKey] options:nil];

  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:LibraryDisplayPreviewPanelKey options:NSKeyValueObservingOptionNew context:nil];
  [self observeValueForKeyPath:LibraryDisplayPreviewPanelKey ofObject:nil change:nil context:nil];
  [self bind:@"enablePreviewImage" toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:LibraryDisplayPreviewPanelKey] options:nil];
  
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

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:LibraryDisplayPreviewPanelKey])
    [[self->libraryPreviewPanelSegmentedControl cell] setSelected:
      !change ? [[PreferencesController sharedController] libraryDisplayPreviewPanelState] : [[change objectForKey:NSKeyValueChangeNewKey] boolValue]
      forSegment:0];
}
//end observeValueForKeyPath:ofObject:change:context:

-(IBAction) changeLibraryDisplayPreviewPanelState:(id)sender
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  [preferencesController setLibraryDisplayPreviewPanelState:![preferencesController libraryDisplayPreviewPanelState]];
}
//end changeLibraryDisplayPreviewPanelState:

-(IBAction) showOrHideWindow:(id)sender
{
  NSWindow* window = [self window];
  if ([window isVisible])
    [window orderOut:self];
  else
    [self showWindow:self];
}
//end showOrHideWindow:

-(BOOL) canRemoveSelectedItems
{
  return [[self window] isVisible] && ([self->libraryView selectedRow] >= 0);
}
//end canRemoveSelectedItems

-(BOOL) canRenameSelectedItems
{
  return [[self window] isVisible] && ([[self->libraryView selectedRowIndexes] count] == 1);
}
//end canRenameSelectedItems

-(BOOL) canRefreshItems
{
  BOOL result = NO;
  NSDocument* document = [AppController currentDocument];
  NSIndexSet* selectedRowIndexes = [self->libraryView selectedRowIndexes];
  BOOL onlyOneItemSelected = ([selectedRowIndexes count] == 1);
  unsigned int firstIndex = [selectedRowIndexes firstIndex];
  result = (document != nil) && onlyOneItemSelected &&
           [[self->libraryView itemAtRow:firstIndex] isKindOfClass:[LibraryEquation class]];
  return result;
}
//end canRefreshItems

-(NSMenu*) actionMenu
{
  return [self->actionButton menu];
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
  LibraryController* libraryTreeController = [self->libraryView libraryController];
  NSManagedObjectContext* managedObjectContext = [libraryTreeController managedObjectContext];
  NSUndoManager* undoManager = [libraryTreeController undoManager];
  [undoManager beginUndoGrouping];
  MyDocument*  document = (MyDocument*) [AppController currentDocument];
  LatexitEquation* currentLatexitEquation = [document latexitEquationWithCurrentStateTransient:YES];
  id parentOfSelection = [[self->libraryView selectedItem] parent];
  unsigned int nbBrothers = [[self->libraryView dataSource] outlineView:self->libraryView numberOfChildrenOfItem:parentOfSelection];
  [[[document undoManager] prepareWithInvocationTarget:document] applyLatexitEquation:currentLatexitEquation];
  //maybe the user did modify parameter since the equation was computed : we correct it from the pdfData inside the history item
  LatexitEquation* latexitEquationToStore =
    [LatexitEquation latexitEquationWithPDFData:[currentLatexitEquation pdfData] useDefaults:YES];
  LibraryEquation* newLibraryEquation =
    [[LibraryEquation alloc] initWithParent:parentOfSelection equation:latexitEquationToStore
             insertIntoManagedObjectContext:managedObjectContext];
  if (newLibraryEquation)
  {
    [newLibraryEquation setSortIndex:nbBrothers];
    [newLibraryEquation setBestTitle];
    [managedObjectContext processPendingChanges];
    [newLibraryEquation release];
    [undoManager setActionName:NSLocalizedString(@"Add Library item", @"Add Library item")];
  }//end if (newLibraryEquation)
  [undoManager endUndoGrouping];
  [self->libraryView reloadData];
  [self->libraryView sizeLastColumnToFit];
  [self->libraryView selectItem:newLibraryEquation byExtendingSelection:NO];
}
//end importCurrent:

//Creates a folder library item
-(IBAction) newFolder:(id)sender
{
  LibraryController* libraryController = [self->libraryView libraryController];
  NSManagedObjectContext* managedObjectContext = [libraryController managedObjectContext];
  NSUndoManager* undoManager = [libraryController undoManager];
  [undoManager beginUndoGrouping];
  id parentOfSelection = [[self->libraryView selectedItem] parent];
  unsigned int nbBrothers = [[self->libraryView dataSource] outlineView:self->libraryView numberOfChildrenOfItem:parentOfSelection];
  LibraryGroupItem* newLibraryGroupItem =
    [[LibraryGroupItem alloc] initWithParent:parentOfSelection
              insertIntoManagedObjectContext:managedObjectContext];
  if (newLibraryGroupItem)
  {
    [newLibraryGroupItem setSortIndex:nbBrothers];
    [newLibraryGroupItem setTitle:NSLocalizedString(@"Untitled", @"Untitled")];
    [managedObjectContext processPendingChanges];
    [newLibraryGroupItem release];
    [undoManager setActionName:NSLocalizedString(@"Add Library folder", @"Add Library folder")];
  }//end if (newLibraryGroupItem)
  [undoManager endUndoGrouping];
  [self->libraryView reloadData];
  [self->libraryView sizeLastColumnToFit];
  [self->libraryView selectItem:newLibraryGroupItem byExtendingSelection:NO];
  [self->libraryView performSelector:@selector(edit:) withObject:self afterDelay:0.];
}
//end newFolder:

//remove selected items
-(IBAction) removeSelectedItems:(id)sender
{
  [self->libraryView removeSelection:self];
}
//end removeSelectedItems:

//if one LibraryFile item is selected, update it with current document's state
-(IBAction) refreshItems:(id)sender
{
  MyDocument*  document = (MyDocument*) [AppController currentDocument];
  if (document)
  {
    unsigned int index = [[self->libraryView selectedRowIndexes] firstIndex];
    id           item  = [self->libraryView itemAtRow:index];
    LibraryItem* libraryItem  = item;
    
    if ([libraryItem isKindOfClass:[LibraryEquation class]])
    {
      BOOL cancel = NO;
      if (libraryItem && [document lastAppliedLibraryEquation] && (libraryItem != [document lastAppliedLibraryEquation]))
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
        NSUndoManager* undoManager = [[[LibraryManager sharedManager] managedObjectContext] undoManager];
        [undoManager beginUndoGrouping];
        LibraryEquation* libraryEquation = (LibraryEquation*)libraryItem;
        LatexitEquation* newLatexitEquation = [document latexitEquationWithCurrentStateTransient:NO];
        [newLatexitEquation setTitle:[libraryEquation title]];
        [libraryEquation setEquation:newLatexitEquation];
        [[[LibraryManager sharedManager] managedObjectContext] processPendingChanges];
        if (item)
          [self->libraryView reloadItem:item];
        
        //let's make it blink a little to inform the user that it has change

        //we un-register the selectionDidChange notification of the delegate to speed up blinking
        [[NSNotificationCenter defaultCenter] removeObserver:[self->libraryView delegate]
                                                        name:NSOutlineViewSelectionDidChangeNotification
                                                      object:self->libraryView];
        BOOL isSelected = YES;
        unsigned int itemIndex   = index;
        NSIndexSet*  itemIndexes = [NSIndexSet indexSetWithIndex:itemIndex];
        int i = 0;
        for(i = 0 ; i<7 ; ++i)
        {
          if (isSelected)
            [self->libraryView deselectRow:itemIndex];
          else
            [self->libraryView selectRowIndexes:itemIndexes byExtendingSelection:NO];
          isSelected = !isSelected;
          NSDate* now = [NSDate date];
          [self->libraryView display];
          NSDate* next = [now addTimeInterval:1./30.];
          [NSThread sleepUntilDate:next];
        }
        [undoManager setActionName:NSLocalizedString(@"Refresh current equation", @"Refresh current equation")];
        [undoManager endUndoGrouping];
        [self->libraryView selectRowIndexes:itemIndexes byExtendingSelection:NO];
        //we restore the delegate notification receiving
        [[NSNotificationCenter defaultCenter] addObserver:[self->libraryView delegate]
                                                 selector:@selector(outlineViewSelectionDidChange:)
                                                     name:NSOutlineViewSelectionDidChangeNotification
                                                   object:self->libraryView];
        [self->libraryView setNeedsDisplay:YES];
      }//end if !cancel
    }//end if selection is LibraryFile
  }//end if document
}
//end refreshItems:

-(IBAction) renameItem:(id)sender
{
  [self->libraryView edit:sender];
}
//end renameItem:

-(IBAction) open:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setDelegate:self];
  [openPanel setTitle:NSLocalizedString(@"Import library...", @"Import library...")];
  [openPanel setAccessoryView:[importAccessoryView retain]];
  if ([[self window] isVisible])
    [openPanel beginSheetForDirectory:nil file:nil types:[NSArray arrayWithObjects:@"latexlib", @"library", @"plist", nil] modalForWindow:[self window]
                        modalDelegate:self didEndSelector:@selector(_openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
  else
    [self _openPanelDidEnd:openPanel returnCode:[openPanel runModalForTypes:[NSArray arrayWithObjects:@"latexlib", @"plist", @"library", nil]] contextInfo:NULL];
}
//end open:

-(void) _openPanelDidEnd:(NSOpenPanel*)openPanel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  library_import_option_t import_option = [importOptionPopUpButton selectedTag];
  if (returnCode == NSOKButton)
  {
    BOOL ok = [[LibraryManager sharedManager] loadFrom:[[[openPanel URLs] lastObject] path] option:import_option parent:nil];
    if (!ok)
    {
      NSAlert* alert = [NSAlert
        alertWithMessageText:NSLocalizedString(@"Loading error", @"Loading error")
               defaultButton:NSLocalizedString(@"OK", @"OK")
             alternateButton:nil otherButton:nil
   informativeTextWithFormat:NSLocalizedString(@"The file does not appear to be a valid format", @"The file does not appear to be a valid format")];
     [alert beginSheetModalForWindow:nil modalDelegate:nil didEndSelector:nil contextInfo:nil];
    }
    else
    {
      [[[LibraryManager sharedManager] managedObjectContext] processPendingChanges];
      [self->libraryView reloadData];
      [self->libraryView scrollRowToVisible:[self->libraryView numberOfRows]-1];
    }
  }//end if (returnCode == NSOKButton)
}
//end _openPanelDidEnd:returnCode:contextInfo;

-(void) panelSelectionDidChange:(id)sender
{
  NSString* selectedFileName = [sender filename];
  BOOL isLaTeXiTLibrary = [[selectedFileName pathExtension] isEqualToString:@"latexlib"];
  unsigned int selectedIndex = [self->importOptionPopUpButton indexOfSelectedItem];
  [self->importOptionPopUpButton removeAllItems];
  [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Add to current library", @"Add to current library")];
  [[self->importOptionPopUpButton lastItem] setTag:(int)LIBRARY_IMPORT_MERGE];
  [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Overwrite current library", @"Overwrite current library")];
  [[self->importOptionPopUpButton lastItem] setTag:(int)LIBRARY_IMPORT_OVERWRITE];
  if (isLaTeXiTLibrary)
  {
    [self->importOptionPopUpButton addItemWithTitle:NSLocalizedString(@"Change library in use", @"Change library in use")];
    [[self->importOptionPopUpButton lastItem] setTag:(int)LIBRARY_IMPORT_OPEN];
  }
  if (selectedIndex >= [[self->importOptionPopUpButton itemArray] count])
    selectedIndex = 0;
  [self->importOptionPopUpButton selectItemAtIndex:selectedIndex];
}
//end panelSelectionDidChange:

-(IBAction) openDefaultLibraryPath:(id)sender
{
  [(NSOpenPanel*)[importAccessoryView window]
    setDirectory:[[[LibraryManager sharedManager] defaultLibraryPath] stringByDeletingLastPathComponent]];
}
//end openDefaultLibraryPath:

-(IBAction) saveAs:(id)sender
{
  self->savePanel = [[NSSavePanel savePanel] retain];
  [self->savePanel setTitle:NSLocalizedString(@"Export library...", @"Export library...")];
  [self changeLibraryExportFormat:self->exportFormatPopUpButton];
  [self->savePanel setCanSelectHiddenExtension:YES];
  [self->savePanel setAccessoryView:[self->exportAccessoryView retain]];
  [self->exportOnlySelectedButton setState:NSOffState];
  [self->exportOnlySelectedButton setEnabled:([self->libraryView selectedRow] >= 0)];
  if ([[self window] isVisible])
    [self->savePanel beginSheetForDirectory:nil file:NSLocalizedString(@"Untitled", @"Untitled") modalForWindow:[self window] modalDelegate:self
                       didEndSelector:@selector(_savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
  else
    [self _savePanelDidEnd:self->savePanel returnCode:[self->savePanel runModal] contextInfo:NULL];
}

-(void) _savePanelDidEnd:(NSSavePanel*)theSavePanel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSFileHandlingPanelOKButton)
  {
    BOOL onlySelection = ([exportOnlySelectedButton state] == NSOnState);
    NSArray* selectedLibraryItems = [self->libraryView selectedItems];
    BOOL ok = [[LibraryManager sharedManager] saveAs:[[theSavePanel URL] path] onlySelection:onlySelection selection:selectedLibraryItems
                                              format:[exportFormatPopUpButton selectedTag]];
    if (!ok)
    {
      NSAlert* alert = [NSAlert
        alertWithMessageText:NSLocalizedString(@"An error occured while saving.", @"An error occured while saving.")
               defaultButton:NSLocalizedString(@"OK", @"OK")
             alternateButton:nil otherButton:nil
   informativeTextWithFormat:nil];
     [alert beginSheetModalForWindow:nil modalDelegate:nil didEndSelector:nil contextInfo:nil];
    }//end if (ok)
  }
  [self->savePanel release];
  self->savePanel = nil;
}
//end _savePanelDidEnd:returnCode:contextInfo:

-(IBAction) changeLibraryExportFormat:(id)sender
{
  switch((library_export_format_t)[sender selectedTag])
  {
    case LIBRARY_EXPORT_FORMAT_INTERNAL:
      [self->savePanel setRequiredFileType:@"latexlib"];
      break;
    case LIBRARY_EXPORT_FORMAT_PLIST:
      [self->savePanel setRequiredFileType:@"plist"];
      break;
  }
}
//end changeLibraryExportFormat:

-(void) _updateButtons:(NSNotification *)aNotification
{
  //maybe all documents are closed, so we must update the import button
  MyDocument* anyDocument = (MyDocument*) [AppController currentDocument];
  [importCurrentButton setEnabled:(anyDocument && [anyDocument hasImage])];
  [[[self->libraryView superview] superview] setNeedsDisplay:YES];//to bring scrollview to front and hide the top line of the button
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

-(void) displayPreviewImage:(NSImage*)image backgroundColor:(NSColor*)backgroundColor;
{
  if (!image && [libraryPreviewPanel isVisible])
    [libraryPreviewPanel orderOut:self];
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
    if (image != [libraryPreviewPanelImageView image])
      [libraryPreviewPanelImageView setImage:image];
    [libraryPreviewPanelImageView setBackgroundColor:backgroundColor];
    [libraryPreviewPanel setFrame:newFrame display:image ? YES : NO];
    if (![libraryPreviewPanel isVisible])
      [libraryPreviewPanel orderFront:self];
  }
}
//end displayPreviewImage:backgroundColor:

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

#pragma mark menu delegate to fix an interface bug
-(void) menuWillOpen:(id)sender {[self->actionButton setAlternateImage:[NSImage imageNamed:@"action-pressed.tiff"]];}
-(void) menuDidClose:(id)sender {[self->actionButton setAlternateImage:[NSImage imageNamed:@"action.tiff"]];}
@end
