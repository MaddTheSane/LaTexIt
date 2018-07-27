//  LatexPalettesController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/04/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The LatexPalettesController controller is responsible for loading and initializing the palette

#import "LatexPalettesController.h"

#import "AppController.h"

@interface LatexPalettesController (PrivateAPI)
-(void) _initMatrices;
@end

@implementation LatexPalettesController

-(id) init
{
  self = [super initWithWindowNibName:@"LatexPalettes"];
  if (self)
  {
  }
  return self;
}

-(void) windowDidLoad
{
  [[self window] setFrameAutosaveName:@"LatexPalettes"];
  [[self window] setAspectRatio:[[self window] frame].size];
  [self _initMatrices];
  [[self window] setDelegate:self];
}

//triggered when the user clicks on a palette; must insert the latex code of the selected symbol in the body of the document
-(IBAction) latexPalettesClick:(id)sender
{
  [[AppController appController] latexPalettesClick:sender];
}

-(void) _initMatrices
{
  NSArray* matrices =
    [NSArray arrayWithObjects:greekMatrix,lettersMatrix,relationsMatrix,
                              binaryOperatorsMatrix,otherOperatorsMatrix,
                              arrowsMatrix,decorationsMatrix,nil];
  NSEnumerator* matricesEnumerator = [matrices objectEnumerator];
  NSMatrix* matrix = [matricesEnumerator nextObject];
  while(matrix)
  {
    //for each matrix, we are doing a little work adding a tooltip according the each cell content
    [matrix setAutosizesCells:YES];
    NSArray* cells = [matrix cells];
    NSEnumerator* cellsEnumerator = [cells objectEnumerator];
    NSButtonCell* cell = [cellsEnumerator nextObject];
    while(cell)
    {
      //some cells represents latex functions, taking an argument inside braces
      //to make the difference, I have used the cells' tags.
      NSString* string = cell ? [cell alternateTitle] : nil;
      if (!string || ![string length]) string = cell ? [cell title] : nil;

      //increase the font size to make it more readable
      NSFont* oldFont = [cell font];
      NSFont* newFont = [NSFont fontWithName:@"OpenSymbol" size:[oldFont pointSize]+4];
      [cell setFont:newFont];

      NSString* help = [cell tag] ? [NSString stringWithFormat:@"%@{...}",string] : string;
      [matrix setToolTip:help forCell:cell];
      cell = [cellsEnumerator nextObject];
    }
    matrix = [matricesEnumerator nextObject];
  }
}

@end
