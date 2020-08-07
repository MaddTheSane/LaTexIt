//  LaTeXPalettesWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/04/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//The LaTeXPalettesWindowController controller is responsible for loading and initializing the latex palettes

#import <Cocoa/Cocoa.h>

@class PaletteView;

@interface LaTeXPalettesWindowController : NSWindowController
{
  IBOutlet NSBox*         matrixBox;
  IBOutlet NSPopUpButton* matrixChoicePopUpButton;
  IBOutlet NSScrollView*  scrollView;
  IBOutlet NSMatrix*      matrix;
  IBOutlet NSButton*      detailsButton;

  IBOutlet NSBox*       detailsBox;
  IBOutlet NSTextField* authorTextField;
  IBOutlet NSImageView* detailsImageView;
  IBOutlet NSTextField* detailsLabelTextField;
  IBOutlet NSTextField* detailsLatexCodeLabelTextField;
  IBOutlet NSTextField* detailsLatexCodeTextField;
  IBOutlet NSTextField* detailsRequiresLabelTextField;
  IBOutlet NSTextField* detailsRequiresTextField;
  
  NSMutableArray* orderedPalettes;
  NSSize smallWindowMinSize;
}

-(void) reloadPalettes;

-(IBAction) openOrHideDetails:(id)sender;

//triggered when the user clicks on a palette; must insert the latex code of the selected symbol in the body of the document
-(IBAction) latexPalettesDoubleClick:(id)sender;
-(IBAction) latexPalettesSelect:(id)sender;

@end
