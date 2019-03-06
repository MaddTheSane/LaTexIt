//

//  LibraryWindowController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/08/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "LibraryWindowController.h"

#import "AppController.h"
#import "BorderlessPanel.h"
#import "ComposedTransformer.h"
#import "IsKindOfClassTransformer.h"
#import "IsNotEqualToTransformer.h"
#import "LatexitEquation.h"
#import "LaTeXProcessor.h"
#import "LibraryController.h"
#import "LibraryEquation.h"
#import "LibraryItem.h"
#import "LibraryGroupItem.h"
#import "LibraryManager.h"
#import "LibraryPreviewPanelImageView.h"
#import "LibraryView.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSArrayExtended.h"
#import "NSMutableArrayExtended.h"
#import "NSObjectExtended.h"
#import "NSOutlineViewExtended.h"
#import "NSSegmentedControlExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "NSWorkspaceExtended.h"
#import "ObjectTransformer.h"
#import "OutlineViewSelectedItemTransformer.h"
#import "OutlineViewSelectedItemsTransformer.h"
#import "PreferencesController.h"
#import "TeXItemWrapper.h"
#import "Utils.h"

extern NSString* NSMenuDidBeginTrackingNotification;

@interface LibraryWindowController (PrivateAPI)
-(void) applicationWillBecomeActive:(NSNotification*)aNotification;
-(void) _updateButtons:(NSNotification*)aNotification;
-(void) _openPanelDidEnd:(NSOpenPanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
-(void) _savePanelDidEnd:(NSSavePanel*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo;
-(void) updateImportTeXItemsGUI;
-(void) windowWillClose:(NSNotification*)notification;
-(void) windowDidResignKey:(NSNotification*)notification;
-(void) notified:(NSNotification *)notification;
-(void) latexisationItemDidEndSelector:(NSDictionary*)configuration;
-(void) latexisationGroupDidEndSelector:(NSDictionary*)configuration;
@end

@implementation LibraryWindowController

-(id) init
{
  if ((!(self = [super initWithWindowNibName:@"LibraryWindowController"])))
    return nil;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notified:) name:LatexizationDidEndNotification object:nil];
  return self;
}
//end init

-(void) dealloc
{
  [self->importTeXOptions release];  
  [self->importTeXArrayController release];
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
  [self->exportFormatPopUpButton removeAllItems];
  [self->exportFormatPopUpButton addItemWithTitle:NSLocalizedString(@"LaTeXiT", @"LaTeXiT")];
  [[self->exportFormatPopUpButton lastItem] setTag:(int)LIBRARY_EXPORT_FORMAT_INTERNAL];
  [self->exportFormatPopUpButton addItemWithTitle:NSLocalizedString(@"XML (Property list)", @"XML (Property list)")];
  [[self->exportFormatPopUpButton lastItem] setTag:(int)LIBRARY_EXPORT_FORMAT_PLIST];
  [self->exportFormatPopUpButton addItemWithTitle:NSLocalizedString(@"TeX Source", @"TeX Source")];
  [[self->exportFormatPopUpButton lastItem] setTag:(int)LIBRARY_EXPORT_FORMAT_TEX_SOURCE];
  
  [self->exportOptionCommentedPreamblesButton setTitle:NSLocalizedString(@"Export commented preambles", @"Export commented preambles")];
  [self->exportOptionUserCommentsButton setTitle:NSLocalizedString(@"Export user comments", @"Export user comments")];
  [self->exportOptionIgnoreTitleHierarchyButton setTitle:NSLocalizedString(@"Ignore title hierarchy", @"Ignore title hierarchy")];
  [self->exportOptionCommentedPreamblesButton sizeToFit];
  [self->exportOptionUserCommentsButton sizeToFit];
  [self->exportOptionIgnoreTitleHierarchyButton sizeToFit];
  
  NSMenu* actionMenu = [[NSMenu alloc] init];
  NSMenuItem* menuItem = nil;  
  [actionMenu addItem:[NSMenuItem separatorItem]];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Open the equation in a document", @"Open the equation in a document") action:@selector(openEquation:) keyEquivalent:@""] setTarget:self];
  menuItem = [actionMenu addItemWithTitle:NSLocalizedString(@"Open the equation in a linked document", @"Open the equation in a linked document") action:@selector(openLinkedEquation:) keyEquivalent:@""];
  [menuItem setTarget:self];
  [menuItem setKeyEquivalentModifierMask:NSAlternateKeyMask];
  [menuItem setAlternate:YES];
  [actionMenu addItem:[NSMenuItem separatorItem]];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Add a folder", @"Add a folder") action:@selector(newFolder:) keyEquivalent:@""] setTarget:self];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Add current equation", @"Add current equation") action:@selector(importCurrent:) keyEquivalent:@""] setTarget:self];
  [actionMenu addItem:[NSMenuItem separatorItem]];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Rename selection", @"Rename selection") action:@selector(renameItem:) keyEquivalent:@""] setTarget:self];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Remove selection", @"Remove selection") action:@selector(removeSelectedItems:) keyEquivalent:@""] setTarget:self];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Replace selection by current equation", @"Replace selection by current equation") action:@selector(refreshItems:) keyEquivalent:@""] setTarget:self];
  [actionMenu addItem:[NSMenuItem separatorItem]];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Show comments pane", @"Show comments pane") action:@selector(toggleCommentsPane:) keyEquivalent:@""] setTarget:self];
  [actionMenu addItem:[NSMenuItem separatorItem]];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Import...", @"Import...") action:@selector(open:) keyEquivalent:@""] setTarget:self];
  [[actionMenu addItemWithTitle:NSLocalizedString(@"Export...", @"Export...") action:@selector(saveAs:) keyEquivalent:@""] setTarget:self];
  [self->actionButton setMenu:actionMenu];
  [actionMenu setDelegate:(id)self];
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

  [self->actionButton setImage:[NSImage imageNamed:@"action"]];
  [self->actionButton setAlternateImage:[NSImage imageNamed:@"action-pressed"]];
  
  [self->libraryRowTypeSegmentedControl bind:NSSelectedTagBinding toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:LibraryViewRowTypeKey] options:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outlineViewSelectionIsChanging:) name:NSOutlineViewSelectionIsChangingNotification object:self->libraryView];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(outlineViewSelectionDidChange:) name:NSOutlineViewSelectionDidChangeNotification object:self->libraryView];
  [self->commentTextView setDelegate:self];
  [self outlineViewSelectionDidChange:nil];
  
  [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:LibraryDisplayPreviewPanelKey options:NSKeyValueObservingOptionNew context:nil];
  [self observeValueForKeyPath:LibraryDisplayPreviewPanelKey ofObject:nil change:nil context:nil];
  [self bind:@"enablePreviewImage" toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:LibraryDisplayPreviewPanelKey] options:nil];
  
  [self->importTeXPanelInlineCheckBox setTitle:NSLocalizedString(@"\"Inline\" items", @"")];
  [self->importTeXPanelDisplayCheckBox setTitle:NSLocalizedString(@"\"Dislay\" items", @"")];
  [self->importTeXPanelAlignCheckBox setTitle:NSLocalizedString(@"\"Align\" items", @"")];
  [self->importTeXPanelEqnarrayCheckBox setTitle:NSLocalizedString(@"\"Eqnarray\" items", @"")];
  [self->importTeXImportButton setTitle:NSLocalizedString(@"Import selection", @"")];
  [self->importTeXCancelButton setTitle:NSLocalizedString(@"Cancel", @"")];
  [self->importTeXImportButton sizeToFit];
  [self->importTeXCancelButton sizeToFit];
  CGRect cgrect1 = NSRectToCGRect([self->importTeXImportButton frame]);
  CGRect cgrect2 = NSRectToCGRect([[self->importTeXImportButton superview] bounds]);
  cgrect1.origin.x = CGRectGetMaxX(cgrect2)-16-cgrect1.size.width;
  [self->importTeXImportButton setFrame:NSRectFromCGRect(cgrect1)];
  cgrect2 = NSRectToCGRect([self->importTeXCancelButton frame]);
  cgrect2.origin.x = CGRectGetMinX(cgrect1)-8-cgrect2.size.width;
  [self->importTeXCancelButton setFrame:NSRectFromCGRect(cgrect2)];
  
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

-(void) notified:(NSNotification*)notification
{
  if ([[notification name] isEqualTo:LatexizationDidEndNotification])
  {
    NSDictionary* configuration = [[notification object] dynamicCastToClass:[NSDictionary class]];
    [self latexisationItemDidEndSelector:configuration];
    [self performSelectorOnMainThread:@selector(latexisationGroupDidEndSelector:) withObject:configuration waitUntilDone:YES];
  }//end if ([[notification name] isEqualTo:LatexizationDidEndNotification])
}
//end notified:

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if (object && (object == self->importTeXArrayController))
  {
    if (!self->updateLevel)
      [self updateImportTeXItemsGUI];
  }//end if (object && (object == self->importTeXArrayController))
  else if ([keyPath isEqualToString:LibraryDisplayPreviewPanelKey])
    [[self->libraryPreviewPanelSegmentedControl cell] setSelected:
      !change ? [[PreferencesController sharedController] libraryDisplayPreviewPanelState] : [[change objectForKey:NSKeyValueChangeNewKey] boolValue]
      forSegment:0];
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) outlineViewSelectionIsChanging:(NSNotification *)notification
{
  if ([notification object] == self->libraryView)
  {
    [[self window] makeFirstResponder:self->libraryView];
  }//end if (object == self->libraryView)
}
//end outlineViewSelectionIsChanging:

-(void) outlineViewSelectionDidChange:(NSNotification *)notification
{
  if (!notification || ([notification object] == self->libraryView))
  {
    LibraryEquation* libraryEquation = [[self->libraryView selectedItem] dynamicCastToClass:[LibraryEquation class]];
    NSString* comment = [libraryEquation comment];
    [self->commentTextView setBackgroundColor:(libraryEquation != nil) ? [NSColor controlBackgroundColor] : [NSColor windowBackgroundColor]];
    [self->commentTextView setEditable:(libraryEquation != nil)];
    [self->commentTextView setString:!comment ? @"" : comment];
  }//end if (!notification || ([notification object] == self->libraryView))
}
//end outlineViewSelectionDidChange:

-(void) textDidEndEditing:(NSNotification*)aNotification
{
  if ([aNotification object] == self->commentTextView)
  {
    LibraryEquation* libraryEquation = [[self->libraryView selectedItem] dynamicCastToClass:[LibraryEquation class]];
    NSString* comment = [[[self->commentTextView string] copy] autorelease];
    [libraryEquation setComment:!comment || [comment isEqualToString:@""] ? nil : comment];
  }//end if ([aNotification object] == self->commentTextView)
}
//end textDidEndEditing:

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

-(LibraryView*) libraryView
{
  return self->libraryView;
}
//end libraryView

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

-(BOOL) isCommentsPaneOpen
{
  BOOL result = ([self->commentDrawer state] == NSDrawerOpenState) || ([self->commentDrawer state] == NSDrawerOpeningState);
  return result;
}
//end isCommentsPaneOpen

-(BOOL) validateMenuItem:(NSMenuItem*)menuItem
{
  BOOL ok = [[self window] isVisible];
  if ([menuItem action] == @selector(openEquation:))
    ok &= ([[[self->libraryView selectedItems] filteredArrayWithItemsOfClass:[LibraryEquation class] exactClass:NO] count] != 0);
  else if ([menuItem action] == @selector(openLinkedEquation:))
    ok &= ([[[self->libraryView selectedItems] filteredArrayWithItemsOfClass:[LibraryEquation class] exactClass:NO] count] != 0);
  else if ([menuItem action] == @selector(importCurrent:))
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
  else if ([menuItem action] == @selector(toggleCommentsPane:))
  {
    [menuItem setTitle:
      [self isCommentsPaneOpen] ?
        NSLocalizedString(@"Hide comments pane", @"Hide comments pane") :
        NSLocalizedString(@"Show comments pane", @"Show comments pane")];
    ok = YES;
  }//end if ([menuItem action] == @selector(toggleCommentsPane:))
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
  [document triggerSmartHistoryFeature];
  id parentOfSelection = [[self->libraryView selectedItem] parent];
  unsigned int nbBrothers = [[self->libraryView dataSource] outlineView:self->libraryView numberOfChildrenOfItem:parentOfSelection];
  [[[document undoManager] prepareWithInvocationTarget:document] applyLatexitEquation:currentLatexitEquation isRecentLatexisation:NO];
  //maybe the user did modify parameter since the equation was computed : we correct it from the pdfData inside the history item
  LatexitEquation* latexitEquationToStore =
    [LatexitEquation latexitEquationWithPDFData:[currentLatexitEquation pdfData] useDefaults:YES];
  [latexitEquationToStore setBackgroundColor:[currentLatexitEquation backgroundColor]];
  LibraryEquation* newLibraryEquation =
    [[LibraryEquation alloc] initWithParent:parentOfSelection equation:latexitEquationToStore
             insertIntoManagedObjectContext:managedObjectContext];
  if (newLibraryEquation)
  {
    [newLibraryEquation setSortIndex:nbBrothers];
    [newLibraryEquation setBestTitle];
    [managedObjectContext processPendingChanges];
    [undoManager setActionName:NSLocalizedString(@"Add Library item", @"Add Library item")];
  }//end if (newLibraryEquation)
  [undoManager endUndoGrouping];
  [self->libraryView reloadData];
  [self->libraryView sizeLastColumnToFit];
  [self->libraryView selectItem:newLibraryEquation byExtendingSelection:NO];
  if (newLibraryEquation)
    [newLibraryEquation release];
}
//end importCurrent:

-(IBAction) openEquation:(id)sender
{
  BOOL makeLink = NO;
  NSArray* libraryEquations =
    [[self->libraryView selectedItems] filteredArrayWithItemsOfClass:[LibraryEquation class] exactClass:NO];
  NSEnumerator* enumerator = [libraryEquations objectEnumerator];
  id object = nil;
  while((object = [enumerator nextObject]))
  {
    MyDocument* document = (MyDocument*)[AppController currentDocument];
    if (!document || (makeLink && [document linkedLibraryEquation]))
    {
      [[NSDocumentController sharedDocumentController] newDocument:self];
      document = (MyDocument*)[AppController currentDocument];
    }
    [self->libraryView openEquation:(LibraryEquation*)object inDocument:document makeLink:makeLink];
  }//end for each libraryEquation
}
//end openEquation:

-(IBAction) openLinkedEquation:(id)sender
{
  BOOL makeLink = YES;
  NSArray* libraryEquations =
    [[self->libraryView selectedItems] filteredArrayWithItemsOfClass:[LibraryEquation class] exactClass:NO];
  NSEnumerator* enumerator = [libraryEquations objectEnumerator];
  id object = nil;
  while((object = [enumerator nextObject]))
  {
    MyDocument* document = (MyDocument*)[AppController currentDocument];
    if (!document || (makeLink && [document linkedLibraryEquation]))
    {
      [[NSDocumentController sharedDocumentController] newDocument:self];
      document = (MyDocument*)[AppController currentDocument];
    }
    [self->libraryView openEquation:(LibraryEquation*)object inDocument:document makeLink:YES];
  }//end for each libraryEquation
}
//end openLinkedEquation:

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
    [undoManager setActionName:NSLocalizedString(@"Add Library folder", @"Add Library folder")];
  }//end if (newLibraryGroupItem)
  [undoManager endUndoGrouping];
  [self->libraryView reloadData];
  [self->libraryView sizeLastColumnToFit];
  [self->libraryView selectItem:newLibraryGroupItem byExtendingSelection:NO];
  if (newLibraryGroupItem)
    [newLibraryGroupItem release];
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
        [libraryEquation setComment:nil];
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
          NSDate* next = isMacOS10_6OrAbove() ? [now dateByAddingTimeInterval:1./30.] : [now addTimeInterval:1./30.];
          [NSThread sleepUntilDate:next];
        }
        [undoManager setActionName:NSLocalizedString(@"Replace selection by current equation", @"Replace selection by current equation")];
        [undoManager endUndoGrouping];
        [self->libraryView selectRowIndexes:itemIndexes byExtendingSelection:NO];
        //we restore the delegate notification receiving
        [[NSNotificationCenter defaultCenter] addObserver:[self->libraryView delegate]
                                                 selector:@selector(outlineViewSelectionDidChange:)
                                                     name:NSOutlineViewSelectionDidChangeNotification
                                                   object:self->libraryView];
        [self->libraryView setNeedsDisplay:YES];
      }//end if !cancel
      [self outlineViewSelectionDidChange:nil];
    }//end if selection is LibraryFile
  }//end if document
}
//end refreshItems:

-(IBAction) renameItem:(id)sender
{
  [self->libraryView edit:sender];
}
//end renameItem:

-(IBAction) toggleCommentsPane:(id)sender
{
  [self->commentDrawer toggle:sender];
}
//end toggleCommentsPane:

-(IBAction) open:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setDelegate:(id)self];
  [openPanel setTitle:NSLocalizedString(@"Import library...", @"Import library...")];
  [openPanel setAccessoryView:[importAccessoryView retain]];
  if ([[self window] isVisible])
    [openPanel beginSheetForDirectory:nil file:nil types:[NSArray arrayWithObjects:@"latexlib", @"latexhist", @"library", @"plist", @"tex", nil] modalForWindow:[self window]
                        modalDelegate:self didEndSelector:@selector(_openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
  else if (!isMacOS10_6OrAbove())
    [self _openPanelDidEnd:openPanel returnCode:[openPanel runModalForTypes:[NSArray arrayWithObjects:@"latexlib", @"latexhist", @"library", @"plist", @"tex", nil]] contextInfo:NULL];
  else//if (isMacOS10_6OrAbove())
  {
    [openPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"latexlib", @"latexhist", @"library", @"plist", @"tex", nil]];
    NSInteger returnCode = [openPanel runModal];
    [self _openPanelDidEnd:openPanel returnCode:returnCode contextInfo:NULL];
  }//end if (isMacOS10_6OrAbove())
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
  NSString* selectedFileName = [[sender URL] path];
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
  }//end if (isLaTeXiTLibrary)
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
    NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:([self->exportOptionCommentedPreamblesButton state] == NSOnState)], @"exportCommentedPreambles",
      [NSNumber numberWithBool:([self->exportOptionUserCommentsButton state] == NSOnState)], @"exportUserComments",
      [NSNumber numberWithBool:([self->exportOptionIgnoreTitleHierarchyButton state] == NSOnState)], @"ignoreTitleHierarchy",
      nil];
    BOOL ok = [[LibraryManager sharedManager] saveAs:[[theSavePanel URL] path] onlySelection:onlySelection selection:selectedLibraryItems
                                              format:[exportFormatPopUpButton selectedTag]
                                             options:options];
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
      [self->exportAccessoryView setFrame:
        NSMakeRect(0, 0, NSMaxX([self->exportFormatPopUpButton frame])+20, 82)];
      if (!isMacOS10_6OrAbove())
        [self->savePanel setRequiredFileType:@"latexlib"];
      else
        [self->savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"latexlib", nil]];
      break;
    case LIBRARY_EXPORT_FORMAT_PLIST:
      [self->exportAccessoryView setFrame:
       NSMakeRect(0, 0, NSMaxX([self->exportFormatPopUpButton frame])+20, 82)];
      if (!isMacOS10_6OrAbove())
        [self->savePanel setRequiredFileType:@"plist"];
      else
        [self->savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"plist", nil]];
      break;
    case LIBRARY_EXPORT_FORMAT_TEX_SOURCE:
      [self->exportAccessoryView setFrame:
       NSMakeRect(0, 0, 
         MAX(NSMaxX([self->exportFormatPopUpButton frame]),
             MAX(NSMaxX([self->exportOptionCommentedPreamblesButton frame]),
                 MAX(NSMaxX([self->exportOptionUserCommentsButton frame]),
                     NSMaxX([self->exportOptionIgnoreTitleHierarchyButton frame])))),
                  156)];
      if (!isMacOS10_6OrAbove())
        [self->savePanel setRequiredFileType:@"tex"];
      else
        [self->savePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"tex", nil]];
      break;
  }
}
//end changeLibraryExportFormat:

-(IBAction) librarySearchFieldChanged:(id)sender
{
  /*NSString* searchString = [[[sender dynamicCastToClass:[NSSearchField class]] stringValue] trim];
  NSString* predicateString = !searchString || [searchString isEqualToString:@""] ? nil :
    [NSString stringWithFormat:@"(title contains[cd] '%@') OR (equation.sourceText.string contains[cd] '%@')", searchString, searchString];
  NSPredicate* predicate = !predicateString? nil :
  [NSPredicate predicateWithFormat:predicateString];
  [[self->libraryView libraryController] setFilterPredicate:predicate];*/
}
//end librarySearchFieldChanged:

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

-(void) blink:(LibraryEquation*)libraryEquation
{
  NSInteger  itemIndex = [self->libraryView rowForItem:libraryEquation];
  if (itemIndex >= 0)
  {
    BOOL isInitiallySelected = [[self->libraryView selectedItems] containsObject:libraryEquation];
    BOOL isSelected = isInitiallySelected;
    NSIndexSet* itemIndexAsSet = [NSIndexSet indexSetWithIndex:itemIndex];
    NSUInteger i = 0;
    for(i = 0 ; i<7 ; ++i)
    {
      if (isSelected)
        [self->libraryView deselectRow:itemIndex];
      else
        [self->libraryView selectRowIndexes:itemIndexAsSet byExtendingSelection:YES];
      isSelected = !isSelected;
      NSDate* now = [NSDate date];
      [self->libraryView display];
      NSDate* next = isMacOS10_6OrAbove() ? [now dateByAddingTimeInterval:1./30.] : [now addTimeInterval:1./30.];
      [NSThread sleepUntilDate:next];
    }
    if (isInitiallySelected)
      [self->libraryView selectRowIndexes:itemIndexAsSet byExtendingSelection:YES];
    else
      [self->libraryView deselectRow:itemIndex];
  }//end if (itemIndex >= 0)
}
//end blink:libraryEquation

-(void) importTeXItemsWithOptions:(NSDictionary*)options
{
  NSArray* texItems = [[options objectForKey:@"teXItems"] dynamicCastToClass:[NSArray class]];
  if ([texItems count] > 0)
  {
    NSMutableArray* dataSource = [NSMutableArray array];
    NSDictionary* texItem = nil;
    NSEnumerator* enumerator = [texItems objectEnumerator];
    while((texItem = [enumerator nextObject]))
    {
      NSDictionary* texItemDict = [texItem dynamicCastToClass:[NSDictionary class]];
      TeXItemWrapper* wrapper = !texItem ? nil : [[[TeXItemWrapper alloc] initWithItem:texItemDict] autorelease];
      [dataSource safeAddObject:wrapper];
    }//end while((texItem = [enumerator nextObject]))
    if (!self->importTeXArrayController)
    {
      self->importTeXArrayController = [[NSArrayController alloc] initWithContent:dataSource];
      [self->importTeXArrayController setAutomaticallyPreparesContent:YES];
      [self->importTeXArrayController setAutomaticallyRearrangesObjects:YES];
      [self->importTeXArrayController setObjectClass:[TeXItemWrapper class]];
      [self->importTeXArrayController addObserver:self forKeyPath:@"arrangedObjects.checked" options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionNew context:nil];
    }//end if (!self->importTeXArrayController)
    [self changeImportTeXItems:nil];//updatePredicate
    [self->importTeXPanelTableView bind:NSContentBinding toObject:self->importTeXArrayController withKeyPath:@"arrangedObjects" options:nil];
    [self->importTeXPanelTableView setDelegate:self];
    NSString* NSEnabled2Binding = [NSEnabledBinding stringByAppendingString:@"2"];
    NSString* NSEnabled3Binding = [NSEnabledBinding stringByAppendingString:@"3"];
    NSTableColumn* tableColumnChecked = [self->importTeXPanelTableView tableColumnWithIdentifier:@"checked"];
    NSTableColumn* tableColumnTitle = [self->importTeXPanelTableView tableColumnWithIdentifier:@"title"];
    NSTableColumn* tableColumnImportButton = [self->importTeXPanelTableView tableColumnWithIdentifier:@"import"];
    NSTableColumn* tableColumnImportState = [self->importTeXPanelTableView tableColumnWithIdentifier:@"state"];
    [tableColumnChecked bind:NSEnabledBinding toObject:self->importTeXArrayController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.enabled"] options:nil];
    [tableColumnChecked bind:NSValueBinding toObject:self->importTeXArrayController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.checked"] options:nil];
    [tableColumnTitle bind:NSEnabledBinding toObject:self->importTeXArrayController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.enabled"] options:nil];
    [tableColumnTitle bind:NSValueBinding toObject:self->importTeXArrayController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.title"] options:nil];
    [tableColumnImportButton bind:NSEnabledBinding toObject:self->importTeXArrayController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.enabled"] options:nil];
    [tableColumnImportButton bind:NSEnabled2Binding toObject:self->importTeXArrayController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.checked"] options:nil];
    [tableColumnImportButton bind:NSEnabled3Binding toObject:self->importTeXArrayController
                      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.importState"] options:
       [NSDictionary dictionaryWithObjectsAndKeys:
         [IsNotEqualToTransformer transformerWithReference:[NSNumber numberWithInteger:1]], NSValueTransformerBindingOption,
        nil]];
    [tableColumnImportState bind:NSEnabledBinding toObject:self->importTeXArrayController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.enabled"] options:nil];
    [tableColumnImportState bind:NSValueBinding toObject:self->importTeXArrayController
      withKeyPath:[NSString stringWithFormat:@"arrangedObjects.importState"] options:
        [NSDictionary dictionaryWithObjectsAndKeys:
           [ObjectTransformer transformerWithDictionary:
              [NSDictionary dictionaryWithObjectsAndKeys:
                @"", [NSNumber numberWithInteger:0],
                NSLocalizedString(@"_IMPORTING_", @""), [NSNumber numberWithInteger:1],
                NSLocalizedString(@"_IMPORTED_", @""), [NSNumber numberWithInteger:2],
                @"!", [NSNumber numberWithInteger:3],
               nil]], NSValueTransformerBindingOption,
         nil]];

    [self->importTeXOptions release];
    self->importTeXOptions = [options copy];
    [NSApp beginSheet:self->importTeXPanel modalForWindow:[self window] modalDelegate:self
       didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:0];
  }//end if ([texItems count] > 0)
}
//end importTeXItems:

-(IBAction) changeImportTeXItems:(id)sender
{
  if (!self->updateLevel)
  {
    ++self->updateLevel;
    /*NSMutableArray* predicates = [NSMutableArray array];
    if ([self->importTeXPanelInlineCheckBox state] == NSOnState)
      [predicates addObject:[NSPredicate predicateWithFormat:@"self.data.mode == %d", (int)LATEX_MODE_INLINE]];
    if ([self->importTeXPanelDisplayCheckBox state] == NSOnState)
      [predicates addObject:[NSPredicate predicateWithFormat:@"self.data.mode == %d", (int)LATEX_MODE_DISPLAY]];
    if ([self->importTeXPanelAlignCheckBox state] == NSOnState)
      [predicates addObject:[NSPredicate predicateWithFormat:@"self.data.mode == %d", (int)LATEX_MODE_ALIGN]];
    if ([self->importTeXPanelEqnarrayCheckBox state] == NSOnState)
      [predicates addObject:[NSPredicate predicateWithFormat:@"self.data.mode == %d", (int)LATEX_MODE_EQNARRAY]];
    NSPredicate* filterPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:predicates];
    [self->importTeXArrayController setFilterPredicate:filterPredicate];*/
    
    NSEnumerator* enumerator = [[self->importTeXArrayController arrangedObjects] objectEnumerator];
    TeXItemWrapper* teXItem = nil;
    while((teXItem = [enumerator nextObject]))
    {
      teXItem = [teXItem dynamicCastToClass:[TeXItemWrapper class]];
      NSDictionary* teXItemData = teXItem.data;
      latex_mode_t latexMode = (latex_mode_t)[[[teXItemData objectForKey:@"mode"] dynamicCastToClass:[NSNumber class]] integerValue];
      //teXItem.enabled = [filterPredicate evaluateWithObject:teXItem];
      teXItem.checked =
        (sender == self->importTeXPanelInlineCheckBox) && (latexMode == LATEX_MODE_INLINE) ?
          ([self->importTeXPanelInlineCheckBox state] != NSOffState) :
        (sender == self->importTeXPanelDisplayCheckBox) && (latexMode == LATEX_MODE_DISPLAY) ?
          ([self->importTeXPanelDisplayCheckBox state] != NSOffState) :
        (sender == self->importTeXPanelAlignCheckBox) && (latexMode == LATEX_MODE_ALIGN) ?
          ([self->importTeXPanelAlignCheckBox state] != NSOffState) :
        (sender == self->importTeXPanelEqnarrayCheckBox) && (latexMode == LATEX_MODE_EQNARRAY) ?
          ([self->importTeXPanelEqnarrayCheckBox state] != NSOffState) :
        teXItem.checked;
    }//end for each teXItem
    --self->updateLevel;
  }//end if (!self->updateLevel)
  [self updateImportTeXItemsGUI];
}
//end changeImportTeXItems:

-(IBAction) closeImportTeXItems:(id)sender
{
  LibraryManager* libraryManager = [LibraryManager sharedManager];
  NSNumber* importOption = [[self->importTeXOptions objectForKey:@"importOption"] dynamicCastToClass:[NSNumber class]];
  #ifdef ARC_ENABLED
  @autoreleasepool {
  #else
  NSAutoreleasePool* ap1 = [[NSAutoreleasePool alloc] init];
  #endif
  NSArray* itemsToRemove = nil;
  if (importOption && ([importOption integerValue] == LIBRARY_IMPORT_OVERWRITE))
    itemsToRemove = [libraryManager allItems];
  [self->importTeXOptions release];
  self->importTeXOptions = nil;

  BOOL souldImport = (sender == self->importTeXImportButton);
  if (souldImport)
    [self performImportTeXItems:sender];
  
  if (itemsToRemove)
    [libraryManager removeItems:itemsToRemove];
  #ifdef ARC_ENABLED
  }//end @autoreleasepool
  #else
  [ap1 release];
  #endif
  [NSApp endSheet:self->importTeXPanel returnCode:(souldImport ? 1 : 0)];
  [self->importTeXArrayController removeObserver:self forKeyPath:@"arrangedObjects.checked"];
  [self->importTeXArrayController release];
  self->importTeXArrayController = nil;
}
//end closeImportTeXItems:

-(void) sheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  [sheet orderOut:self];
  [self->libraryView reloadData];
}
//end sheetDidEnd:returnCode:contextInfo:

-(IBAction) performImportTeXItems:(id)sender
{
  NSInteger clickedRow = [self->importTeXPanelTableView clickedRow];
  NSArray* arrangedObjects = [self->importTeXArrayController arrangedObjects];
  TeXItemWrapper* teXItem = (clickedRow < 0) || ((unsigned)clickedRow >= [arrangedObjects count]) ? nil :
    [[arrangedObjects objectAtIndex:clickedRow] dynamicCastToClass:[TeXItemWrapper class]];
  BOOL isFullImport = !teXItem;
  NSMutableArray* teXItems = [NSMutableArray array];
  [teXItems safeAddObject:teXItem];
  if (isFullImport)
  {
    NSEnumerator* enumerator = [arrangedObjects objectEnumerator]; 
    while((teXItem = [enumerator nextObject]))
    {
      if ([teXItem enabled] && [teXItem checked])
        [teXItems safeAddObject:teXItem];
    }//end for each teXItem
  }//end if (isFullImport)
  
  BOOL backgroundly = !isFullImport;
  [[LaTeXProcessor sharedLaTeXProcessor]
     latexiseTeXItems:teXItems backgroundly:backgroundly
     delegate:self
   itemDidEndSelector:(backgroundly ? nil : @selector(latexisationItemDidEndSelector:))//in case of backgroundly, handled by notification
   groupDidEndSelector:(backgroundly ? nil : @selector(latexisationGroupDidEndSelector:))//in case of backgroundly, handled by notification
   ];
  
  if (isFullImport)
  {
    id proposedParentItem = nil;
    LibraryEquation* proposedLocationAsEquation = nil;
    LibraryGroupItem* proposedLocationAsGroup = nil;
    LibraryGroupItem* parent = nil;
    NSInteger proposedChildIndex = 0;

    LibraryManager* libraryManager = [LibraryManager sharedManager];
    NSMutableArray* newLibraryRootItems = [[NSMutableArray alloc] init];
    NSEnumerator* enumerator = [teXItems objectEnumerator];
    while((teXItem = [enumerator nextObject]))
    {
      NSDictionary* teXItemData = teXItem.data;
      proposedParentItem = [teXItemData objectForKey:@"proposedParentItem"];
      proposedChildIndex = [[[teXItemData objectForKey:@"proposedChildIndex"] dynamicCastToClass:[NSNumber class]] integerValue];
      proposedLocationAsEquation = [proposedParentItem dynamicCastToClass:[LibraryEquation class]];
      proposedLocationAsGroup = [proposedParentItem dynamicCastToClass:[LibraryGroupItem class]];
      parent =
        (proposedLocationAsGroup != nil) ? proposedLocationAsGroup :
        [[proposedLocationAsEquation parent] dynamicCastToClass:[LibraryGroupItem class]];
      LatexitEquation* latexitEquation = teXItem.equation;
      LibraryEquation* libraryEquation = !latexitEquation ? nil :
        [[[LibraryEquation alloc] initWithParent:parent equation:latexitEquation insertIntoManagedObjectContext:[libraryManager managedObjectContext]] autorelease];
      if (libraryEquation)
      {
       [libraryEquation setBestTitle];
       [newLibraryRootItems safeAddObject:libraryEquation];
      }//end if (libraryEquation)
    }//end for each teXItem
    
    //fix sortIndexes of root nodes
    LibraryController* libraryController = [self->libraryView libraryController];
    NSMutableArray* brothers = [NSMutableArray arrayWithArray:
                                !parent  ? [libraryController rootItems] : [parent childrenOrdered]];
    [brothers removeObjectsInArray:newLibraryRootItems];
    [brothers insertObjectsFromArray:newLibraryRootItems atIndex:(proposedChildIndex == NSOutlineViewDropOnItemIndex) ?
      [brothers count] : MIN([brothers count], (unsigned)proposedChildIndex)];
    unsigned int nbBrothers = [brothers count];
    while(nbBrothers--)
      [[brothers objectAtIndex:nbBrothers] setSortIndex:nbBrothers];
    [newLibraryRootItems release];
  }//end if (isFullImport))

  [self->importTeXArrayController rearrangeObjects];
}
//end performImportTeXItems:

-(void) latexisationItemDidEndSelector:(NSDictionary*)configuration
{
  TeXItemWrapper* teXItem = [[configuration objectForKey:@"context"] dynamicCastToClass:[TeXItemWrapper class]];
  NSData* pdfData = [[configuration objectForKey:@"outPdfData"] dynamicCastToClass:[NSData class]];
  LatexitEquation* latexitEquation = ![pdfData length] ? nil :
    [[[LatexitEquation alloc] initWithData:pdfData sourceUTI:(NSString*)kUTTypePDF useDefaults:YES] autorelease];
  teXItem.importState = !latexitEquation ? 3 : 2;
  teXItem.equation = latexitEquation;
  [self->importTeXArrayController rearrangeObjects];
}
//end latexisationItemDidEndSelector:

-(void) latexisationGroupDidEndSelector:(NSDictionary*)configuration
{
  [self updateImportTeXItemsGUI];
}
//end latexisationGroupDidEndSelector:

-(void) updateImportTeXItemsGUI
{
  if (!self->updateLevel)
  {
    ++self->updateLevel;
    [self->importTeXArrayController rearrangeObjects];
    NSUInteger inlineEnabledCount = 0;
    NSUInteger inlineDisabledCount = 0;
    NSUInteger displayEnabledCount = 0;
    NSUInteger displayDisabledCount = 0;
    NSUInteger alignEnabledCount = 0;
    NSUInteger alignDisabledCount = 0;
    NSUInteger eqnarrayEnabledCount = 0;
    NSUInteger eqnarrayDisabledCount = 0;
    NSArray* arrangedObjects = [[[self->importTeXArrayController arrangedObjects] mutableCopy] autorelease];
    NSEnumerator* enumerator = [arrangedObjects objectEnumerator];
    TeXItemWrapper* teXItem = nil;
    while((teXItem = [enumerator nextObject]))
    {
      teXItem = [teXItem dynamicCastToClass:[TeXItemWrapper class]];
      NSDictionary* teXItemData = teXItem.data;
      latex_mode_t latexMode = (latex_mode_t)[[[teXItemData objectForKey:@"mode"] dynamicCastToClass:[NSNumber class]] integerValue];
      if (latexMode == LATEX_MODE_INLINE)
      {
        inlineEnabledCount += teXItem.checked ? 1 : 0;
        inlineDisabledCount += !teXItem.checked ? 1 : 0;
      }//end if (latexMode == LATEX_MODE_INLINE)
      else if (latexMode == LATEX_MODE_DISPLAY)
      {
        displayEnabledCount += teXItem.checked ? 1 : 0;
        displayDisabledCount += !teXItem.checked ? 1 : 0;
      }//end if (latexMode == LATEX_MODE_DISPLAY)  
      else if (latexMode == LATEX_MODE_ALIGN)
      {
        alignEnabledCount += teXItem.checked ? 1 : 0;
        alignDisabledCount += !teXItem.checked ? 1 : 0;
      }//end if (latexMode == LATEX_MODE_ALIGN)  
      else if (latexMode == LATEX_MODE_EQNARRAY)
      {
        eqnarrayEnabledCount += teXItem.checked ? 1 : 0;
        eqnarrayDisabledCount += !teXItem.checked ? 1 : 0;
      }//end if (latexMode == LATEX_MODE_EQNARRAY)  
    }//end for each teXItem
    [self->importTeXPanelInlineCheckBox setEnabled:((inlineEnabledCount+inlineDisabledCount)>0)];
    [self->importTeXPanelInlineCheckBox setState:
      !inlineEnabledCount && !inlineDisabledCount ? NSOffState :
      inlineEnabledCount && !inlineDisabledCount ? NSOnState :
      !inlineEnabledCount && inlineDisabledCount ? NSOffState :
      NSMixedState];
    [self->importTeXPanelDisplayCheckBox setEnabled:((displayEnabledCount+displayDisabledCount)>0)];
    [self->importTeXPanelDisplayCheckBox setState:
      !displayEnabledCount && !displayDisabledCount ? NSOffState :
      displayEnabledCount && !displayDisabledCount ? NSOnState :
      !displayEnabledCount && displayDisabledCount ? NSOffState :
      NSMixedState];
    [self->importTeXPanelAlignCheckBox setEnabled:((alignEnabledCount+alignDisabledCount)>0)];
    [self->importTeXPanelAlignCheckBox setState:
      !alignEnabledCount && !alignDisabledCount ? NSOffState :
      alignEnabledCount && !alignDisabledCount ? NSOnState :
      !alignEnabledCount && alignDisabledCount ? NSOffState :
      NSMixedState];
    [self->importTeXPanelEqnarrayCheckBox setEnabled:((eqnarrayEnabledCount+eqnarrayDisabledCount)>0)];
    [self->importTeXPanelEqnarrayCheckBox setState:
      !eqnarrayEnabledCount && !eqnarrayDisabledCount ? NSOffState :
      eqnarrayEnabledCount && !eqnarrayDisabledCount ? NSOnState :
      !eqnarrayEnabledCount && eqnarrayDisabledCount ? NSOffState :
      NSMixedState];
    --self->updateLevel;
  }//end if (!self-updateLevel)
}
//end updateImportTeXItemsGUI

-(void) windowWillClose:(NSNotification*)notification
{
  [libraryPreviewPanel orderOut:self];
}
//end windowWillClose:

-(void) windowDidResignKey:(NSNotification*)notification
{
  [libraryPreviewPanel orderOut:self];
  [[LibraryManager sharedManager] saveLibrary];
}
//end windowDidResignKey:

#pragma mark menu delegate to fix an interface bug
-(void) menuWillOpen:(id)sender {[self->actionButton setAlternateImage:[NSImage imageNamed:@"action-pressed"]];}
-(void) menuDidClose:(id)sender {[self->actionButton setAlternateImage:[NSImage imageNamed:@"action"]];}

#pragma mark TableViewDelegate

@end
