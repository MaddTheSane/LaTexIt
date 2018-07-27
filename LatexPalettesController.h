//  LatexPalettesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/04/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The LatexPalettesController controller is responsible for loading and initializing the latex palettes

#import <Cocoa/Cocoa.h>

@interface LatexPalettesController : NSWindowController
{
  IBOutlet NSMatrix* greekMatrix;
  IBOutlet NSMatrix* lettersMatrix;
  IBOutlet NSMatrix* relationsMatrix;
  IBOutlet NSMatrix* binaryOperatorsMatrix;
  IBOutlet NSMatrix* otherOperatorsMatrix;
  IBOutlet NSMatrix* arrowsMatrix;
  IBOutlet NSMatrix* decorationsMatrix;
}

-(id) init;

//triggered when the user clicks on a palette; must insert the latex code of the selected symbol in the body of the document
-(IBAction) latexPalettesClick:(id)sender;

@end
