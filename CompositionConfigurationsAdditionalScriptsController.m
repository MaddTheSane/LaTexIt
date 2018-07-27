//
//  CompositionConfigurationsAdditionalScriptsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationsAdditionalScriptsController.h"

@implementation CompositionConfigurationsAdditionalScriptsController

-(id) selection
{
  id result = [[self selectedObjects] lastObject];
  return result;
}
//end selection

@end
