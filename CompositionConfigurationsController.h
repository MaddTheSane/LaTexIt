//
//  CompositionConfigurationsController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class CompositionConfigurationsAdditionalScriptsController;
@class CompositionConfigurationsProgramArgumentsController;
@interface CompositionConfigurationsController : NSArrayController {
  CompositionConfigurationsAdditionalScriptsController* currentConfigurationScriptsController;
  NSMutableDictionary*  currentConfigurationProgramArgumentsControllerDictionary;
}

+(NSMutableDictionary*) defaultCompositionConfigurationDictionary;

-(void) ensureDefaultCompositionConfiguration;

-(id)   newObject; //redefined
-(BOOL) canRemove; //redefined
-(void) add:(id)sender; //redefined

-(CompositionConfigurationsAdditionalScriptsController*) currentConfigurationScriptsController;

-(NSArray*)                                              currentConfigurationProgramArgumentsPdfLaTeX;
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsPdfLaTeXController;
-(NSArray*)                                              currentConfigurationProgramArgumentsXeLaTeX;
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsXeLaTeXController;
-(NSArray*)                                              currentConfigurationProgramArgumentsLaTeX;
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsLaTeXController;
-(NSArray*)                                              currentConfigurationProgramArgumentsDviPdf;
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsDviPdfController;
-(NSArray*)                                              currentConfigurationProgramArgumentsGs;
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsGsController;
-(NSArray*)                                              currentConfigurationProgramArgumentsPsToPdf;
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsPsToPdfController;
-(NSArray*)                                              currentConfigurationProgramArgumentsForKey:(NSString*)key;
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsControllerForKey:(NSString*)key;

@end
