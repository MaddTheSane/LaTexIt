//
//  Utils.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "AppController.h"

#import <Cocoa/Cocoa.h>

latex_mode_t validateLatexMode(latex_mode_t mode);
int indexOfLatexMode(latex_mode_t mode);
latex_mode_t latexModeForIndex(int index);
