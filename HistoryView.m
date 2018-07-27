//  HistoryView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.

//This is the table view displaying the history in the history drawer
//Its delegate and datasource are the HistoryManager, the history being shared by all documents

#import "HistoryView.h"

#import "AppController.h"
#import "DragFilterWindow.h"
#import "DragFilterWindowController.h"
#import "HistoryCell.h"
#import "HistoryController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "HistoryWindowController.h"
#import "LatexitEquation.h"
#import "LaTeXProcessor.h"
#import "LibraryManager.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSColorExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

@interface HistoryView (PrivateAPI)
-(void) activateSelectedItem;
@end

@implementation HistoryView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  [self setDelegate:self];
  [self setDataSource:self];
  [self registerForDraggedTypes:[NSArray arrayWithObject:NSColorPboardType]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->historyItemsController release];
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
  [[self window] setAcceptsMouseMovedEvents:YES]; //to allow history to detect mouse moved events
  self->historyItemsController = [[HistoryController alloc] initWithContent:nil];
  [self->historyItemsController setAutomaticallyPreparesContent:YES];
  [self->historyItemsController setEntityName:[HistoryItem className]];
  [self->historyItemsController setManagedObjectContext:[[HistoryManager sharedManager] managedObjectContext]];
  [self->historyItemsController setSortDescriptors:
    [NSArray arrayWithObjects:[[[NSSortDescriptor alloc] initWithKey:@"equationWrapper.equation.date" ascending:NO] autorelease], nil]];
  [self->historyItemsController prepareContent];
  NSTableColumn* tableColumn = [[self tableColumns] objectAtIndex:0];
  NSDictionary* bindingOptions = nil;
  [self bind:NSContentBinding toObject:self->historyItemsController withKeyPath:@"arrangedObjects" options:bindingOptions];
  [self bind:NSSelectionIndexesBinding toObject:self->historyItemsController withKeyPath:@"selectionIndexes" options:bindingOptions];
  [tableColumn bind:NSValueBinding toObject:self->historyItemsController withKeyPath:@"arrangedObjects.equation.pdfCachedImage" options:bindingOptions];
  [tableColumn bind:NSEnabledBinding toObject:self->historyItemsController withKeyPath:@"arrangedObjects.dummyPropertyToForceUIRefresh" options:bindingOptions];
}
//end awakeFromNib

-(HistoryController*) historyItemsController
{
  return self->historyItemsController;
}
//end historyItemsController

-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  int row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}
//end acceptsFirstMouse:

-(IBAction) undo:(id)sender
{
  NSUndoManager* undoManager = [[HistoryManager sharedManager] undoManager];
  if ([undoManager canUndo])
    [undoManager undo];
}
//end undo:

-(IBAction) redo:(id)sender
{
  NSUndoManager* undoManager = [[HistoryManager sharedManager] undoManager];
  if ([undoManager canRedo])
    [undoManager redo];
}
//end redo:

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  NSUndoManager* undoManager = [[HistoryManager sharedManager] undoManager];
  if ([sender action] == @selector(copy:))
    ok = ([self selectedRow] >= 0);
  else if ([sender action] == @selector(paste:))
    ok = NO;
  else if ([sender action] == @selector(undo:))
  {
    ok = [undoManager canUndo];
    [sender setTitleWithMnemonic:[undoManager undoMenuItemTitle]];
  }
  else if ([sender action] == @selector(redo:))
  {
    ok = [undoManager canRedo];
    [sender setTitleWithMnemonic:[undoManager redoMenuItemTitle]];
  }
  return ok;
}
//end validateMenuItem:

//events management, particularly cursor moving and selection

-(void) activateSelectedItem
{
  MyDocument* document = (MyDocument*)[AppController currentDocument];
  if (!document)
  {
    [[NSDocumentController sharedDocumentController] newDocument:self];
    document = (MyDocument*)[AppController currentDocument];
  }
  if (document)
  {
    LatexitEquation* equation = [[[self->historyItemsController selectedObjects] lastObject] equation];
    if (equation)
    {
      NSUndoManager* documentUndoManager = [document undoManager];
      [document applyLatexitEquation:equation isRecentLatexisation:NO];
      [documentUndoManager setActionName:NSLocalizedString(@"Apply History item", @"Apply History item")];
    }
    [[document windowForSheet] makeKeyAndOrderFront:nil];
  }//end if (document)
}
//end activateSelectedItem:

-(void) keyDown:(NSEvent*)theEvent
{
  unsigned short keyCode = [theEvent keyCode];
  if ((keyCode == 36) || (keyCode == 76) || (keyCode == 49)) //enter or return or space
    [self activateSelectedItem];
  else
    [super interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}
//end keyDown:

-(void) mouseDown:(NSEvent*)theEvent
{
  if ([theEvent clickCount] == 1)
    [super mouseDown:theEvent];
  else if ([theEvent clickCount] == 2)
    [self activateSelectedItem];
}
//end mouseDown:

-(void) cancelOperation:(id)sender
{
  [self deselectAll:self];
}
//end cancelOperation:

-(void) deleteBackward:(id)sender
{
  [self removeSelection:sender];
}
//end deleteBackward:

-(IBAction) removeSelection:(id)sender
{
  [self->historyItemsController removeObjects:[self->historyItemsController selectedObjects]];
}
//end removeSelection:

-(void) moveDownAndModifySelection:(id)sender
{
  //selection to down
  NSUInteger lastSelectedRow   = [self selectedRow];
  NSIndexSet* selectedRowIndexes = [self selectedRowIndexes];
  if (lastSelectedRow == [selectedRowIndexes lastIndex]) //if the selection is going down, and down, increase it
  {
    if (lastSelectedRow != NSNotFound)
      ++lastSelectedRow;
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:lastSelectedRow] byExtendingSelection:YES];
    [self scrollRowToVisible:lastSelectedRow-1];
  }
  else //if we are going down after an upwards selection, deselect last selected item
  {
    unsigned int firstIndex = [selectedRowIndexes firstIndex];
    [self deselectRow:firstIndex];
    [self scrollRowToVisible:firstIndex+1];
  }
}
//end moveDownAndModifySelection:

-(void) moveUpAndModifySelection:(id)sender
{
  //selection to up
  unsigned int lastSelectedRow   = [self selectedRow];
  NSIndexSet* selectedRowIndexes = [self selectedRowIndexes];
  if (lastSelectedRow == [selectedRowIndexes firstIndex]) //if the selection is going up, and up, increase it
  {
    if (lastSelectedRow > 0)
      --lastSelectedRow;
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:lastSelectedRow] byExtendingSelection:YES];
    [self scrollRowToVisible:lastSelectedRow];
  }
  else //if we are going up after an downwards selection, deselect last selected item
  {
    unsigned int lastIndex = [selectedRowIndexes lastIndex];
    [self deselectRow:lastIndex];
    [self scrollRowToVisible:lastIndex-1];
  }
}
//end moveUpAndModifySelection:

-(void) moveUp:(id)sender
{
  int selectedRow = [self selectedRow];
  if (selectedRow > 0)
    --selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}
//end moveUp:

-(void) moveDown:(id)sender
{
  int selectedRow = [self selectedRow];
  if ((selectedRow >= 0) && (selectedRow+1 < [self numberOfRows]))
    ++selectedRow;
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:selectedRow] byExtendingSelection:NO];
  [self scrollRowToVisible:selectedRow];
}
//end moveDown:

-(void) scrollWheel:(NSEvent*)event
{
  [super scrollWheel:event];
  [self mouseMoved:event];//to trigger preview display
}
//end scrollWheel:

-(void) mouseMoved:(NSEvent*)event
{
  [super mouseMoved:event];
  HistoryWindowController* historyWindowController = (HistoryWindowController*) [[self window] windowController];
  NSClipView*        clipView          = (NSClipView*) [self superview];
  NSPoint            location          = [clipView convertPoint:[event locationInWindow] fromView:nil];
  if (!NSPointInRect(location, [clipView bounds]))
    [historyWindowController displayPreviewImage:nil backgroundColor:nil];
  else//if NSPointInRect(location, [clipView bounds])
  {
    location = [self convertPoint:location fromView:clipView];
    int row = [self rowAtPoint:location];
    id historyItem = (row >= 0) && (row < [self numberOfRows]) ?
       [[self->historyItemsController arrangedObjects] objectAtIndex:row] : nil;
    LatexitEquation* equation = [historyItem equation];
    NSImage* image            = [equation pdfCachedImage];
    NSColor* backgroundColor  = [equation backgroundColor];
    [historyWindowController displayPreviewImage:image backgroundColor:backgroundColor];
  }//end if NSPointInRect(location, [clipView bounds])
}
//end mouseMoved:

#pragma mark copy/paste

-(IBAction) copy:(id)sender
{
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard declareTypes:[NSArray array] owner:self];
  
  //LatexitEquationsPboardType
  NSArray* selectedHistoryItems = [self->historyItemsController selectedObjects];
  NSMutableArray* selectedLatexitEquations = [NSMutableArray arrayWithCapacity:[selectedHistoryItems count]];
  NSEnumerator* enumerator = [selectedHistoryItems objectEnumerator];
  HistoryItem* historyItem = nil;
  while((historyItem = [enumerator nextObject]))
    [selectedLatexitEquations addObject:[historyItem equation]];
  [pasteboard addTypes:[NSArray arrayWithObject:LatexitEquationsPboardType] owner:self];
  [pasteboard setData:[NSKeyedArchiver archivedDataWithRootObject:selectedLatexitEquations] forType:LatexitEquationsPboardType];

  //NSPDFPboardType
  NSData* lastLatexitEquationPdfData = [[selectedLatexitEquations lastObject] pdfData];
  if (lastLatexitEquationPdfData)
  {
    [pasteboard addTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:self];
    [pasteboard setData:lastLatexitEquationPdfData forType:NSPDFPboardType];
    [pasteboard addTypes:[NSArray arrayWithObject:@"com.adobe.pdf"] owner:self];
    [pasteboard setData:lastLatexitEquationPdfData forType:@"com.adobe.pdf"];
  }//end if (lastLatexitEquationPdfData)
}
//end copy:

-(IBAction) paste:(id)sender
{
}
//end paste:

#pragma mark NSTableDataSource (dummy, to avoid warnings. Real data source is handled trough binding to an arrayController)
-(int) numberOfRowsInTableView:(NSTableView*)aTableView {return 0;}
-(id)  tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex {return nil;}

#pragma mark NSTableViewDelegate

-(void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  LatexitEquation* latexitEquation = [[[self->historyItemsController arrangedObjects] objectAtIndex:rowIndex] equation];
  [aCell setBackgroundColor:[latexitEquation backgroundColor]];
  [aCell setRepresentedObject:latexitEquation];
}
//end tableView:willDisplayCell:forTableColumn:row:

#pragma mark drag'n drop

-(void) dragImage:(NSImage*)image at:(NSPoint)at offset:(NSSize)offset event:(NSEvent*)event
       pasteboard:(NSPasteboard*)pasteboard source:(id)object slideBack:(BOOL)slideBack
{
  [[[AppController appController] dragFilterWindowController] setWindowVisible:YES withAnimation:YES atPoint:
    [[self window] convertBaseToScreen:[event locationInWindow]]];
  [[[AppController appController] dragFilterWindowController] setDelegate:self];
  [super dragImage:image at:at offset:offset event:event pasteboard:pasteboard source:object slideBack:slideBack];
}
//end dragImage:at:offset:event:pasteboard:source:slideBack:

-(void) draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
  [[[AppController appController] dragFilterWindowController] setWindowVisible:NO withAnimation:YES];
  [[[AppController appController] dragFilterWindowController] setDelegate:nil];
  [super draggedImage:anImage endedAt:aPoint operation:operation];
}
//end draggedImage:endedAt:operation:

-(NSDragOperation) draggingEntered:(id<NSDraggingInfo>)sender
{
  NSDragOperation result = NSDragOperationNone;
  NSPasteboard* pboard = [sender draggingPasteboard];
  result = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]] ? NSDragOperationEvery : NSDragOperationNone;
  return result;
}
//end draggingEntered:

-(BOOL) prepareForDragOperation:(id<NSDraggingInfo>)sender
{
  BOOL result = NO;
  NSPasteboard* pboard = [sender draggingPasteboard];
  result = ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]] != nil);
  return result;
}
//end prepareForDragOperation:

-(BOOL) performDragOperation:(id<NSDraggingInfo>)sender
{
  BOOL result = NO;
  NSPasteboard* pboard = [sender draggingPasteboard];
  result = ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]] != nil);
  if (result)
  {
    NSPoint mouseLocation = [self convertPoint:[[self window] mouseLocationOutsideOfEventStream] fromView:nil];
    int row = [self rowAtPoint:mouseLocation];
    result = (row >= 0) && [self tableView:self acceptDrop:sender row:row dropOperation:NSTableViewDropOn];
    [self draggingExited:sender];//fixes a drop-ring-does-not-disappear bug
  }//end if (result)
  return result;
}
//end performDragOperation:

-(NSDragOperation) draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
  NSDragOperation result = isLocal ? NSDragOperationEvery : NSDragOperationCopy;
  return result;
}
//end draggingSourceOperationMaskForLocal:

-(void) dragFilterWindowController:(DragFilterWindowController*)dragFilterWindowController exportFormatDidChange:(export_format_t)exportFormat
{
  NSPasteboard* pasteBoard = [NSPasteboard pasteboardWithName:NSDragPboard];
  [self tableView:self writeRowsWithIndexes:[self selectedRowIndexes] toPasteboard:pasteBoard];
}
//end dragFilterWindowController:exportFormatDidChange:

-(BOOL) tableView:(NSTableView*)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
  BOOL result = YES;
  if ([rowIndexes count])
  {
    BOOL isChangePasteboardOnTheFly = ([pboard dataForType:NSFilesPromisePboardType] != nil);
    if (!isChangePasteboardOnTheFly)
      [pboard declareTypes:[NSArray array] owner:self];
    
    //promise file occur when drag'n dropping to the finder. The files will be created in tableview:namesOfPromisedFiles:...
    if (!isChangePasteboardOnTheFly)
    {
      [pboard addTypes:[NSArray arrayWithObject:NSFilesPromisePboardType] owner:self];
      [pboard setPropertyList:[NSArray arrayWithObjects:@"pdf", @"eps", @"tiff", @"jpeg", @"png", nil] forType:NSFilesPromisePboardType];
    }

    //stores the array of selected history items in the HistoryItemsPboardType
    NSArray* selectedHistoryItems = [[self->historyItemsController arrangedObjects] objectsAtIndexes:rowIndexes];
    NSMutableArray* selectedLatexitEquations = [NSMutableArray arrayWithCapacity:[selectedHistoryItems count]];
    NSEnumerator* enumerator = [selectedHistoryItems objectEnumerator];
    HistoryItem* historyItem = nil;
    while((historyItem = [enumerator nextObject]))
      [selectedLatexitEquations addObject:[historyItem equation]];

    [pboard addTypes:[NSArray arrayWithObject:LatexitEquationsPboardType] owner:self];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:selectedLatexitEquations] forType:LatexitEquationsPboardType];
    
    //Get the last selected item
    historyItem = [selectedHistoryItems lastObject];
    
    //bonus : we can also feed other pasteboards with one of the selected items
    //The pasteboard (PDF, PostScript, TIFF... will depend on the user's preferences
    [historyItem writeToPasteboard:pboard isLinkBackRefresh:NO lazyDataProvider:nil];
  }//end if ([rowIndexes count])
  return result;
}
//end tableView:writeRowsWithIndexes:toPasteboard:

//triggered when dropping to the finder. It will create the files and return the filenames
-(NSArray*) tableView:(NSTableView*)tableView namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination
                                                             forDraggedRowsWithIndexes:(NSIndexSet *)indexSet
{
  NSMutableArray* names = [NSMutableArray arrayWithCapacity:1];
  
  NSString* dropPath = [dropDestination path];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  
  //the problem will be to avoid overwritting files when they already exist
  NSString* filePrefix = @"latex-image";
  export_format_t exportFormat = [[PreferencesController sharedController] exportFormatCurrentSession];
  NSString* extension = nil;
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
      extension = @"pdf";
      break;
    case EXPORT_FORMAT_EPS:
      extension = @"eps";
      break;
    case EXPORT_FORMAT_TIFF:
      extension = @"tiff";
      break;
    case EXPORT_FORMAT_PNG:
      extension = @"png";
      break;
    case EXPORT_FORMAT_JPEG:
      extension = @"jpeg";
      break;
  }
  
  NSString* fileName = nil;
  NSString* filePath = nil;
  
  //To avoid overwritting, and not bother the user with a dialog box, a number will be added to the filename.
  //this number is <i>. It will begin at 1 and will be increased as long as we do not find a "free" file name.
  NSUInteger i = 1;
  NSUInteger index = [indexSet firstIndex]; //we will have to do that for each item of the pasteboard
  while (index != NSNotFound) 
  {
    do
    {
      fileName = [NSString stringWithFormat:@"%@-%u.%@", filePrefix, i++, extension];
      filePath = [dropPath stringByAppendingPathComponent:fileName];
    } while (i && [fileManager fileExistsAtPath:filePath]);
    
    //now, we may have found a proper filename to save our data
    if (![fileManager fileExistsAtPath:filePath])
    {
      HistoryItem* historyItem = [[self->historyItemsController arrangedObjects] objectAtIndex:index];
      NSData* pdfData = [[historyItem equation] pdfData];
      
      PreferencesController* preferencesController = [PreferencesController sharedController];
      NSColor*  color = [preferencesController exportJpegBackgroundColor];
      CGFloat quality = [preferencesController exportJpegQualityPercent];
      NSData* data = [[LaTeXProcessor sharedLaTeXProcessor]
        dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality scaleAsPercent:[preferencesController exportScalePercent]
             compositionConfiguration:[preferencesController compositionConfigurationDocument]];
      [fileManager createFileAtPath:filePath contents:data attributes:nil];
      [fileManager changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt'] forKey:NSFileHFSCreatorCode]
                                 atPath:filePath];
      NSColor* backgroundColor = (exportFormat == EXPORT_FORMAT_JPEG) ? color : nil;
      [[NSWorkspace sharedWorkspace] setIcon:[[LaTeXProcessor sharedLaTeXProcessor] makeIconForData:[[historyItem equation] pdfData] backgroundColor:backgroundColor]
                                     forFile:filePath options:NSExclude10_4ElementsIconCreationOption];
      [names addObject:fileName];
    }//end if (![fileManager fileExistsAtPath:filePath])
    index = [indexSet indexGreaterThanIndex:index]; //now, let's do the same for the next item
  }//end while (index != NSNotFound) 
  return names;
}
//end tableView:namesOfPromisedFilesDroppedAtDestinationforDraggedRowsWithIndexes:

//we can drop a color on a history item cell, to change its background color
-(NSDragOperation)tableView:(NSTableView*)tableView validateDrop:(id<NSDraggingInfo>)info
                proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  NSDragOperation result = NSDragOperationNone;
  NSPasteboard* pboard = [info draggingPasteboard];
  //we only accept drops on items, not above them.
  BOOL ok = pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]] &&
            [pboard propertyListForType:NSColorPboardType] &&
            (operation == NSTableViewDropOn);
  result = ok ? NSDragOperationEvery : NSDragOperationNone;
  return result;
}
//end tableView:validateDrop:proposedRow:proposedDropOperation:

//accepts dropping a color on an element
-(BOOL) tableView:(NSTableView*)tableView acceptDrop:(id<NSDraggingInfo>)info row:(int)row dropOperation:(NSTableViewDropOperation)operation
{
  BOOL ok = NO;
  NSPasteboard* pboard = [info draggingPasteboard];
  ok = pboard && [pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]] &&
                 [pboard propertyListForType:NSColorPboardType] && (operation == NSTableViewDropOn);
  if (ok)
  {
    NSUndoManager* undoManager = [[HistoryManager sharedManager] undoManager];
    NSColor* color = [NSColor colorFromPasteboard:pboard];
    HistoryItem* historyItem = [[self->historyItemsController arrangedObjects] objectAtIndex:row];
    [[historyItem equation] setBackgroundColor:color];
    [undoManager setActionName:NSLocalizedString(@"Change History item background color", @"Change History item background color")];
  }//end if (ok)
  return ok;
}
//end tableView:acceptDrop:row:dropOperation:

@end
