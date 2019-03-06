//
//  BodyTemplatesTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.

#import "BodyTemplatesTableView.h"

#import "NSArrayControllerExtended.h"
#import "BodyTemplatesController.h"
#import "PreferencesController.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

static NSPasteboardType const BodyTemplatesPboardType = @"BodyTemplatesPboardType"; //pboard type for drag'n drop of tableviews rows

@implementation BodyTemplatesTableView

-(void) awakeFromNib
{
  self.delegate = self;
  self.dataSource = self;
  [self setAllowsMultipleSelection:NO];
  [self.tableColumns.lastObject bind:NSValueBinding toObject:[[PreferencesController sharedController] bodyTemplatesController]
    withKeyPath:@"arrangedObjects.name" options:nil];
  [self registerForDraggedTypes:@[BodyTemplatesPboardType]];
}
//end awakeFromNib:

-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:theEvent.locationInWindow fromView:nil];
  NSInteger row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}
//end acceptsFirstMouse:

-(void) keyDown:(NSEvent*)theEvent
{
  [super interpretKeyEvents:@[theEvent]];
  if ((theEvent.keyCode == 36) || (theEvent.keyCode == 52) || (theEvent.keyCode == 49))//Enter, space or ?? What did I do ???
    [self edit:self];
}
//end keyDown:

//edit selected row
-(IBAction) edit:(id)sender
{
  NSInteger selectedRow = self.selectedRow;
  if (selectedRow >= 0)
    [self editColumn:0 row:selectedRow withEvent:nil select:YES];
}
//end edit:

-(void) deleteBackward:(id)sender
{
  [[[PreferencesController sharedController] bodyTemplatesController] remove:sender];
}
//end deleteBackward:

#pragma mark dummy datasource (real datasource is a binding, just avoid warnings)

-(NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView {return 0;}
-(id)   tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex {return nil;}
-(void) tableView:(NSTableView*)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex {}

#pragma mark drag'n drop
//drag'n drop for moving rows

-(NSIndexSet*) _draggedRowIndexes //utility method to access draggedItems when working with pasteboard sender
{
  return self->draggedRowIndexes;
}
//end _draggedRowIndexes

-(BOOL) tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
  //we put the moving rows in pasteboard
  self->draggedRowIndexes = rowIndexes;
  BodyTemplatesController* bodyTemplatesController = [[PreferencesController sharedController] bodyTemplatesController];
  NSArray* bodyTemplatesSelected = bodyTemplatesController.selectedObjects;
  [pboard declareTypes:@[BodyTemplatesPboardType] owner:self];  
  [pboard setPropertyList:[NSKeyedArchiver archivedDataWithRootObject:bodyTemplatesSelected] forType:BodyTemplatesPboardType];
  return YES;
}
//end tableView:writeRowsWithIndexes:toPasteboard:

-(NSDragOperation) tableView:(NSTableView*)tableView validateDrop:(id<NSDraggingInfo>)info
                 proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  //we only accept moving inside the table (not between different ones)
  NSPasteboard* pboard = [info draggingPasteboard];
  NSIndexSet* indexSet =  [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  BOOL ok = (tableView == [info draggingSource]) && pboard &&
            [pboard availableTypeFromArray:@[BodyTemplatesPboardType]] &&
            [pboard propertyListForType:BodyTemplatesPboardType] &&
            (operation == NSTableViewDropAbove) &&
            indexSet && (indexSet.firstIndex != (NSUInteger)row) && (indexSet.firstIndex+1 != (NSUInteger)row);
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}
//end tableView:validateDrop:proposedRow:proposedDropOperation:

-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
  BodyTemplatesController* bodyTemplatesController = [[PreferencesController sharedController] bodyTemplatesController];
  NSIndexSet* indexSet = [(id)[[info draggingSource] dataSource] _draggedRowIndexes];
  [bodyTemplatesController moveObjectsAtIndices:indexSet toIndex:row];
  self->draggedRowIndexes = nil;
  return YES;
}
//end tableView:acceptDrop:row:dropOperation:

@end
