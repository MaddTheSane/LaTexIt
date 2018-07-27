//
//  PaletteMatrix.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/12/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.
//

#import "PaletteMatrix.h"

#import "PaletteCell.h"

@implementation PaletteMatrix

-(BOOL) acceptsFirstResponder
{
  return YES;
}

-(void) scrollWheel:(NSEvent*)event
{
  [super scrollWheel:event];
  [[[self window] windowController] mouseMoved:event];
}

-(void) mouseDown:(NSEvent*)event
{
  [[self window] makeFirstResponder:self];
  NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
  int row =0;
  int column = 0;
  BOOL ok = [self getRow:&row column:&column forPoint:point];
  if (ok)
  {
    PaletteCell* cell = [self cellAtRow:row column:column];
    [cell setHighlighted:YES];
    [self selectCellAtRow:row column:column];
    [self sendAction:@selector(latexPalettesClick:) to:[self delegate]];
  }
}

-(void) keyDown:(NSEvent*)event
{
  NSCell* selectedCell = [self selectedCell];
  NSString* characters = [event charactersIgnoringModifiers];
  if (selectedCell && ![characters isEqualToString:@""])
  {
    int row = 0;
    int column = 0;
    [self getRow:&row column:&column ofCell:selectedCell];
    
    unichar c = [characters characterAtIndex:0];
    if ((c == NSUpArrowFunctionKey) || (c == NSRightArrowFunctionKey) ||
        (c == NSDownArrowFunctionKey) || (c == NSLeftArrowFunctionKey))
    {
      if (c == NSUpArrowFunctionKey)
        --row;
      else if (c == NSRightArrowFunctionKey)
        ++column;
      else if (c == NSDownArrowFunctionKey)
        ++row;
      else if (c == NSLeftArrowFunctionKey)
        --column;
      row    = MAX(MIN(row,    [self numberOfRows]   -1), 0);
      column = MAX(MIN(column, [self numberOfColumns]-1), 0);
      [self selectCellAtRow:row column:column];
      selectedCell = [self selectedCell];
      [selectedCell setHighlighted:YES];
      [self sendAction:@selector(latexPalettesSelect:) to:[self delegate]];
    }
    else if ((c == ' ') || (c == 13))//return
      [self sendAction:@selector(latexPalettesClick:) to:[self delegate]];
    else if ((c == '\t'))
    {
      [[self window] makeFirstResponder:[self nextKeyView]];
    }
  }
}

@end
