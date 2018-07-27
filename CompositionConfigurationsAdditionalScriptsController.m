//
//  CompositionConfigurationsAdditionalScriptsController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import "CompositionConfigurationsAdditionalScriptsController.h"

#import "PreferencesController.h"
#import "NSStringExtended.h"

@implementation CompositionConfigurationsAdditionalScriptsController

-(id) selection
{
  id result = [[self selectedObjects] lastObject];
  return result;
}
//end selection

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  if ([keyPath startsWith:@"value." options:0])
  {
    //for some reason, needed to trigger observation on all controllers
    [[[PreferencesController sharedController] compositionConfigurationsController]
      setValue:[object valueForKeyPath:@"enabled"]
      forKeyPath:[NSString stringWithFormat:@"selection.%@.selection.enabled", CompositionConfigurationAdditionalProcessingScriptsKey]];
  }
}

@end
