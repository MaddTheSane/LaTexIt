//
//  CompositionConfigurationsAdditionalScriptsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2009 LAIC. All rights reserved.
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
