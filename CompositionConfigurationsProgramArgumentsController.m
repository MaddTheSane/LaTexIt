//
//  CompositionConfigurationsProgramArgumentsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import "CompositionConfigurationsProgramArgumentsController.h"

@implementation CompositionConfigurationsProgramArgumentsController

-(id) selection
{
  id result = [[self selectedObjects] lastObject];
  return result;
}
//end selection

@end
