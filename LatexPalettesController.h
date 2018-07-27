//  LatexPalettesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/04/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//The LatexPalettesController controller is responsible for loading and initializing the latex palettes

#import <Cocoa/Cocoa.h>

@class PaletteView;

@interface LatexPalettesController : NSWindowController
{
  IBOutlet NSBox*         matrixBox;
  IBOutlet NSPopUpButton* matrixChoicePopUpButton;
  IBOutlet NSMatrix*      matrix;
  IBOutlet NSButton*      detailsButton;

  IBOutlet NSBox*       detailsBox;
  IBOutlet NSTextField* authorTextField;
  IBOutlet NSImageView* detailsImageView;
  IBOutlet NSTextField* detailsLatexCodeTextField;
  IBOutlet NSTextField* detailsRequiresTextField;
  
  NSMutableArray* orderedPalettes;
}

-(void) reloadPalettes;

-(IBAction) changeGroup:(id)sender;
-(IBAction) openOrHideDetails:(id)sender;

//triggered when the user clicks on a palette; must insert the latex code of the selected symbol in the body of the document
-(IBAction) latexPalettesClick:(id)sender;
-(IBAction) latexPalettesSelect:(id)sender;

@end
