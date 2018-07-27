//
//  CompositionConfigurationsProgramArgumentsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
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
