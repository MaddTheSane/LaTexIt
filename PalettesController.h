//  PalettesController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 4/04/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The palette controller is responsible for loading and initializing the palette

#import <Cocoa/Cocoa.h>

@interface PalettesController : NSWindowController
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
-(IBAction) paletteClick:(id)sender;

@end
