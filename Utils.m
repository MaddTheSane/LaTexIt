//
//  Utils.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 15/03/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "Utils.h"

latex_mode_t validateLatexMode(latex_mode_t mode)
{
  return (mode >= LATEX_MODE_DISPLAY) && (mode <= LATEX_MODE_EQNARRAY) ? mode : LATEX_MODE_DISPLAY;
}

int indexOfLatexMode(latex_mode_t mode)
{
  int index = 0;
  switch(mode)
  {
    case LATEX_MODE_EQNARRAY:index=0;break;
    case LATEX_MODE_DISPLAY :index=1;break;
    case LATEX_MODE_INLINE  :index=2;break;
    case LATEX_MODE_TEXT    :index=3;break;
  }
  return index;
}

latex_mode_t latexModeForIndex(int index)
{
  int mode = LATEX_MODE_DISPLAY;
  switch(index)
  {
    case 0:mode = LATEX_MODE_EQNARRAY;break;
    case 1:mode = LATEX_MODE_DISPLAY ;break;
    case 2:mode = LATEX_MODE_INLINE  ;break;
    case 3:mode = LATEX_MODE_TEXT    ;break;
    default:mode = LATEX_MODE_DISPLAY ;break;
  }
  return mode;
}
