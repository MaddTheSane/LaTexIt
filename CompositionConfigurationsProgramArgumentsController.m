//
//  CompositionConfigurationsProgramArgumentsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationsProgramArgumentsController.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation CompositionConfigurationsProgramArgumentsController

-(id) selection
{
  id result = self.selectedObjects.lastObject;
  return result;
}
//end selection

@end
