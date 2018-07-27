//
//  PreamblesTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

//EncapsulationTableView presents custom encapsulations from an encapsulation manager. I has user friendly capabilities

#import "PreamblesTableView.h"

NSString* PreamblesPboardType = @"PreamblesPboardType"; //pboard type for drag'n drop of tableviews rows

@implementation PreamblesTableView

-(void) awakeFromNib
{
  [self setDelegate:self];
  [self registerForDraggedTypes:[NSArray arrayWithObject:PreamblesPboardType]];
}

-(void) dealloc
{
  [super dealloc];
}

-(BOOL) acceptsFirstMouse:(NSEvent *)theEvent //using the tableview does not need to activate the window first
{
  NSPoint point = [self convertPoint:[theEvent locationInWindow] fromView:nil];
  int row = [self rowAtPoint:point];
  [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
  return YES;
}

-(void) keyDown:(NSEvent*)theEvent
{
  [super interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
  if (([theEvent keyCode] == 36) || ([theEvent keyCode] == 52) || ([theEvent keyCode] == 49))//Enter, space or ?? What did I do ???
    [self edit:self];
}

//edit selected row
-(IBAction) edit:(id)sender
{
  int selectedRow = [self selectedRow];
  if (selectedRow >= 0)
    [self editColumn:0 row:selectedRow withEvent:nil select:YES];
}

@end
