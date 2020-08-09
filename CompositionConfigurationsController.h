//
//  CompositionConfigurationsController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
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

@property (readonly, strong) CompositionConfigurationsAdditionalScriptsController *currentConfigurationScriptsController;

@property (readonly, copy) NSArray *currentConfigurationProgramArgumentsPdfLaTeX;
@property (readonly, strong) CompositionConfigurationsProgramArgumentsController *currentConfigurationProgramArgumentsPdfLaTeXController;
@property (readonly, copy) NSArray *currentConfigurationProgramArgumentsXeLaTeX;
@property (readonly, strong) CompositionConfigurationsProgramArgumentsController *currentConfigurationProgramArgumentsXeLaTeXController;
@property (readonly, copy) NSArray *currentConfigurationProgramArgumentsLuaLaTeX;
@property (readonly, strong) CompositionConfigurationsProgramArgumentsController *currentConfigurationProgramArgumentsLuaLaTeXController;
@property (readonly, copy) NSArray *currentConfigurationProgramArgumentsLaTeX;
@property (readonly, strong) CompositionConfigurationsProgramArgumentsController *currentConfigurationProgramArgumentsLaTeXController;
@property (readonly, copy) NSArray *currentConfigurationProgramArgumentsDviPdf;
@property (readonly, strong) CompositionConfigurationsProgramArgumentsController *currentConfigurationProgramArgumentsDviPdfController;
@property (readonly, copy) NSArray *currentConfigurationProgramArgumentsGs;
@property (readonly, strong) CompositionConfigurationsProgramArgumentsController *currentConfigurationProgramArgumentsGsController;
@property (readonly, copy) NSArray *currentConfigurationProgramArgumentsPsToPdf;
@property (readonly, strong) CompositionConfigurationsProgramArgumentsController *currentConfigurationProgramArgumentsPsToPdfController;
-(NSArray*)                                              currentConfigurationProgramArgumentsForKey:(NSString*)key;
-(CompositionConfigurationsProgramArgumentsController*)  currentConfigurationProgramArgumentsControllerForKey:(NSString*)key;

@end
