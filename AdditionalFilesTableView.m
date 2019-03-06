//
//  AdditionalFilesTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "AdditionalFilesTableView.h"

#import "AdditionalFilesController.h"
#import "AdditionalFilesWindowController.h"
#import "BoolTransformer.h"
#import "ComposedTransformer.h"
#import "FileExistsTransformer.h"
#import "NSArrayControllerExtended.h"
#import "PreferencesController.h"

@interface AdditionalFilesTableView (PrivateAPI)
-(NSArrayController*) filesController;
-(void) openPanelDidEnd:(NSOpenPanel*)panel returnCode:(int)returnCode contextInfo:(void*)contextInfo;
@end

@implementation AdditionalFilesTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  self->previousDefaultsFiles = [[NSMutableArray alloc] init];
  [self setDelegate:(id)self];
  [self setDataSource:(id)self];
  [self setIsDefaultTableView:YES];
  [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [[[PreferencesController sharedController] additionalFilesController] removeObserver:self forKeyPath:@"arrangedObjects"];
  [self->filesWithExtrasController release];
  [self->previousDefaultsFiles release];
  [super dealloc];
}
//end dealloc

-(BOOL) isDefaultTableView
{
  return self->isDefaultTableView;
}
//end isDefaultTableView

-(void) setIsDefaultTableView:(BOOL)value
{
  if (value != self->isDefaultTableView)
  {
    self->isDefaultTableView = value;
    if (self->isDefaultTableView)
    {
      [[[PreferencesController sharedController] additionalFilesController] addObserver:self forKeyPath:@"arrangedObjects" options:0 context:nil];//make sure it is an observer to avoid an exception

      [[[PreferencesController sharedController] additionalFilesController] removeObserver:self forKeyPath:@"arrangedObjects"];

      [[self tableColumnWithIdentifier:@"filepath"] bind:NSValueBinding toObject:[[PreferencesController sharedController] additionalFilesController]
        withKeyPath:@"arrangedObjects.lastPathComponent" options:nil];
      [[self tableColumnWithIdentifier:@"filepath"] bind:NSTextColorBinding toObject:[[PreferencesController sharedController] additionalFilesController]
        withKeyPath:@"arrangedObjects.self"
            options:[NSDictionary dictionaryWithObjectsAndKeys:
              [ComposedTransformer transformerWithValueTransformer:[FileExistsTransformer transformerWithDirectoryAllowed:YES]
                additionalValueTransformer:[BoolTransformer transformerWithFalseValue:[NSColor redColor] trueValue:[NSColor blackColor]]
                         additionalKeyPath:nil], NSValueTransformerBindingOption, nil]];
    }
    else//if (!self->isDefaultTableView)
    {
      if (!self->filesWithExtrasController)
      {
        self->filesWithExtrasController = [[NSArrayController alloc] initWithContent:[NSMutableArray array]];
        [self->filesWithExtrasController setPreservesSelection:YES];
        [self->filesWithExtrasController setAutomaticallyPreparesContent:NO];
        [self->filesWithExtrasController addObjects:[[PreferencesController sharedController] additionalFilesPaths]];
      }
      [self bind:NSContentBinding toObject:self->filesWithExtrasController withKeyPath:@"arrangedObjects" options:nil];
      [self bind:NSSelectionIndexesBinding toObject:self->filesWithExtrasController withKeyPath:@"selectionIndexes" options:nil];
      [[self tableColumnWithIdentifier:@"filepath"] bind:NSValueBinding toObject:self->filesWithExtrasController
        withKeyPath:@"arrangedObjects.lastPathComponent" options:nil];
      [[self tableColumnWithIdentifier:@"filepath"] bind:NSTextColorBinding toObject:self->filesWithExtrasController
        withKeyPath:@"arrangedObjects.self"
            options:[NSDictionary dictionaryWithObjectsAndKeys:
              [ComposedTransformer transformerWithValueTransformer:[FileExistsTransformer transformerWithDirectoryAllowed:YES]
                additionalValueTransformer:[BoolTransformer transformerWithFalseValue:[NSColor redColor] trueValue:[NSColor blackColor]]
                         additionalKeyPath:nil], NSValueTransformerBindingOption, nil]];
      [[[PreferencesController sharedController] additionalFilesController] addObserver:self forKeyPath:@"arrangedObjects"
        options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil];
      [self->filesWithExtrasController addObserver:self forKeyPath:@"arrangedObjects" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:nil];
    }//end if (!self->isDefaultTableView)
  }//end if (value != self->isDefaultTableView)
}
//end setIsDefaultTableView:

-(NSArrayController*) filesController
{
  NSArrayController* result = self->isDefaultTableView ?
    [[PreferencesController sharedController] additionalFilesController] : self->filesWithExtrasController;
  return result;
}
//end filesController

-(NSArray*) additionalFilesPaths
{
  NSArray* result = [[[[self filesController] arrangedObjects] mutableCopy] autorelease];
  return result;
}
//end filePaths

-(IBAction) openSelection:(id)sender
{
  NSArray* selection = [[self filesController] selectedObjects];
  NSMutableArray* urls = [NSMutableArray arrayWithCapacity:[selection count]];
  NSEnumerator* enumerator = [selection objectEnumerator];
  NSString* filepath = nil;
  while((filepath = [enumerator nextObject]))
    [urls addObject:[NSURL fileURLWithPath:filepath]];
  [[NSWorkspace sharedWorkspace] openURLs:urls withAppBundleIdentifier:nil options:NSWorkspaceLaunchDefault
           additionalEventParamDescriptor:nil launchIdentifiers:nil];
}
//end openSelection:

-(IBAction) remove:(id)sender
{
  if (self->isDefaultTableView)
    [[self filesController] remove:sender];
  else//if (self->isDefaultTableView)
  {
    NSSet* defaultsFiles = [NSSet setWithArray:[[[PreferencesController sharedController] additionalFilesController] arrangedObjects]];
    NSMutableSet* selectedFiles =  [NSMutableSet setWithArray:[[self filesController] selectedObjects]];
    [selectedFiles minusSet:defaultsFiles];
    [[self filesController] removeObjects:[selectedFiles allObjects]];
  }//end if (self->isDefaultTableView)
}
//end remove:

#pragma mark bindings

-(BOOL) canAdd
{
  BOOL result = [[self filesController] canAdd];
  return result;
}
//end canAdd

-(BOOL) canRemove
{
  BOOL result = [[self filesController] canRemove];
  if (!self->isDefaultTableView && result)
  {
    NSSet* defaultsFiles = [NSSet setWithArray:[[[PreferencesController sharedController] additionalFilesController] arrangedObjects]];
    NSMutableSet* selectedFiles =  [NSMutableSet setWithArray:[[self filesController] selectedObjects]];
    [selectedFiles minusSet:defaultsFiles];
    result &= ([selectedFiles count] > 0);
  }//end if (result)
  return result;
}
//end canRemove

#pragma mark observer

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if (!self->isDefaultTableView &&
      (object == [[PreferencesController sharedController] additionalFilesController]) &&
      [keyPath isEqualToString:@"arrangedObjects"])
  {
    NSArray* defaultsOld = self->previousDefaultsFiles;
    NSArray* defaultsNew = [[[PreferencesController sharedController] additionalFilesController] arrangedObjects];
    NSMutableArray* brandNewDefaults = [NSMutableArray arrayWithArray:defaultsNew];
    [brandNewDefaults removeObjectsInArray:defaultsOld];
    NSMutableArray* disappearedDefaults = [NSMutableArray arrayWithArray:defaultsOld];
    [disappearedDefaults removeObjectsInArray:defaultsNew];
    [self->previousDefaultsFiles setArray:defaultsNew];
    NSMutableArray* current = [NSMutableArray arrayWithArray:[self->filesWithExtrasController arrangedObjects]];
    [current removeObjectsInArray:disappearedDefaults];
    [current removeObjectsInArray:brandNewDefaults];
    [current insertObjects:brandNewDefaults atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [brandNewDefaults count])]];
    [self->filesWithExtrasController setContent:current];
  }//end if (!self->isDefaultTableView)
  else if (object == self->filesWithExtrasController)
  {
    [self willChangeValueForKey:@"canAdd"];
    [self didChangeValueForKey:@"canAdd"];
    [self willChangeValueForKey:@"canRemove"];
    [self didChangeValueForKey:@"canRemove"];
  }
}
//end observeValueForKeyPath:ofObject:change:context:

#pragma mark events

-(BOOL) acceptsFirstMouse:(NSEvent*)event //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
  int row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}
//end acceptsFirstMouse:

-(void) mouseDown:(NSEvent*)event
{
  [super mouseDown:event];
  if ([event clickCount] == 2)
    [self openSelection:self];
}
//end mouseDown:

-(void) keyDown:(NSEvent*)event
{
  [super interpretKeyEvents:[NSArray arrayWithObject:event]];
  if (([event keyCode] == 36) || ([event keyCode] == 52) || ([event keyCode] == 49))//Enter, space or ?? What did I do ???
    [self openSelection:self];
}
//end keyDown:

-(void) deleteBackward:(id)sender
{
  [self remove:sender];
}
//end deleteBackward:

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

#pragma mark add files

-(IBAction) addFiles:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setAllowsMultipleSelection:YES];
  [openPanel setCanChooseDirectories:YES];
  [openPanel setCanChooseFiles:YES];
  [openPanel setCanCreateDirectories:NO];
  [openPanel setCanHide:YES];
  [openPanel setCanSelectHiddenExtension:YES];
  [openPanel setResolvesAliases:YES];
  [openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:[self window] modalDelegate:self
                     didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}
//end addFiles:

-(void) openPanelDidEnd:(NSOpenPanel*)panel returnCode:(int)returnCode contextInfo:(void*)contextInfo
{
  if (returnCode == NSOKButton)
  {
    NSArray* urls = [panel URLs];
    NSMutableArray* fileNames = [NSMutableArray arrayWithCapacity:[urls count]];
    NSEnumerator* enumerator = [urls objectEnumerator];
    NSURL* url = nil;
    while((url = [enumerator nextObject]))
      [fileNames addObject:[url path]];
    if (self->isDefaultTableView)
      [[[PreferencesController sharedController] additionalFilesController] addObjects:fileNames];
    else//if (!self->isDefaultTableView)
    {
      AdditionalFilesController* defaultAdditionalFilesController = [[PreferencesController sharedController] additionalFilesController];
      NSArray* filesInDefaultAdditionalFilesController = [defaultAdditionalFilesController arrangedObjects];
      NSMutableArray* filesToAdd = [NSMutableArray arrayWithArray:fileNames];
      [filesToAdd removeObjectsInArray:filesInDefaultAdditionalFilesController];
      NSEnumerator* enumerator = [filesToAdd objectEnumerator];
      id object = nil;
      while((object = [enumerator nextObject]))
        [self->filesWithExtrasController addObject:object];
    }//end if (!self->isDefaultTableView)
  }//end if (returnCode == NSOKButton)
}
//end openPanelDidEnd:returnCode:contextInfo:

#pragma mark delegate

-(void) tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex
{
  NSArray* objects = [[self filesController] arrangedObjects];
  NSString* filepath = (rowIndex >= 0) && ((unsigned)rowIndex < [objects count]) ? [objects objectAtIndex:rowIndex] : nil;
  [aCell setImage:[[NSWorkspace sharedWorkspace] iconForFile:filepath]];
  if (!self->isDefaultTableView)
  {
    AdditionalFilesController* defaultAdditionalFilesController = [[PreferencesController sharedController] additionalFilesController];
    if ([[defaultAdditionalFilesController arrangedObjects] containsObject:filepath])
      [aCell setTextColor:[[NSFileManager defaultManager] fileExistsAtPath:filepath] ? [NSColor grayColor] : [NSColor brownColor]];
  }
}
//end tableView:willDisplayCell:forTableColumn:row:

#pragma mark dummy datasource (real datasource is a binding, just avoid warnings)

-(NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView {return 0;}
-(id)        tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex {return nil;}
-(void)      tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex {}

#pragma mark drag'n drop

-(NSIndexSet*) _draggedRowIndexes //utility method to access draggedItems when working with pasteboard sender
{
  return self->draggedRowIndexes;
}
//end _draggedRowIndexes

-(BOOL) tableView:(NSTableView*)aTableView writeRowsWithIndexes:(NSIndexSet*)rowIndexes toPasteboard:(NSPasteboard*)pboard
{
  //we put the moving rows in pasteboard
  self->draggedRowIndexes = rowIndexes;
  NSArrayController* additionalFilesController = [[PreferencesController sharedController] additionalFilesController];
  NSArray* additionalFilesControllerSelected = [additionalFilesController selectedObjects];
  [pboard declareTypes:[NSArray arrayWithObject:NSFilenamesPboardType] owner:self];  
  [pboard setPropertyList:additionalFilesControllerSelected forType:NSFilenamesPboardType];
  return YES;
}
//end tableView:writeRowsWithIndexes:toPasteboard:

-(NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  NSPasteboard* pboard = [info draggingPasteboard];
  NSIndexSet* indexSet =  [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  BOOL ok = pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]] &&
            [pboard propertyListForType:NSFilenamesPboardType] &&
            (operation == NSTableViewDropAbove) &&
            (!indexSet || (indexSet && ([indexSet firstIndex] != (unsigned int)row) && ([indexSet firstIndex]+1 != (unsigned int)row)));
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}
//end tableView:validateDrop:proposedRow:proposedDropOperation:

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
  NSArrayController* additionalFilesController = [self filesController];
  NSIndexSet* indexSet = [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  if (indexSet)
    [additionalFilesController moveObjectsAtIndices:indexSet toIndex:row];
  else
  {
    NSPasteboard* pasteboard = [info draggingPasteboard];
    [additionalFilesController addObjects:[pasteboard propertyListForType:NSFilenamesPboardType]];
  }
  self->draggedRowIndexes = nil;
  return YES;
}
//end tableView:acceptDrop:row:dropOperation:

@end
