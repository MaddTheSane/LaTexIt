//
//  NSDictionaryCompositionConfiguration.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSDictionaryCompositionConfiguration.h"

#import "PreferencesController.h"

@implementation NSDictionary (CompositionConfiguration)

-(composition_mode_t) compositionConfigurationCompositionMode
             {return (composition_mode_t)[[self objectForKey:CompositionConfigurationCompositionModeKey] intValue];}

-(NSString*) compositionConfigurationProgramPathPdfLaTeX
             {return [self compositionConfigurationProgramPathForKey:CompositionConfigurationPdfLatexPathKey];}
-(NSString*) compositionConfigurationProgramPathXeLaTeX
             {return [self compositionConfigurationProgramPathForKey:CompositionConfigurationXeLatexPathKey];}
-(NSString*) compositionConfigurationProgramPathLaTeX
             {return [self compositionConfigurationProgramPathForKey:CompositionConfigurationLatexPathKey];}
-(NSString*) compositionConfigurationProgramPathDviPdf
             {return [self compositionConfigurationProgramPathForKey:CompositionConfigurationDviPdfPathKey];}
-(NSString*) compositionConfigurationProgramPathGs
             {return [self compositionConfigurationProgramPathForKey:CompositionConfigurationGsPathKey];}
-(NSString*) compositionConfigurationProgramPathPsToPdf
             {return [self compositionConfigurationProgramPathForKey:CompositionConfigurationPsToPdfPathKey];}
-(NSString*) compositionConfigurationProgramPathForKey:(NSString*)key
{
  NSString* result = [self objectForKey:key];
  return result;
}
//end compositionConfigurationProgramPathForKey:

-(NSArray*) compositionConfigurationProgramArgumentsPdfLaTeX
             {return [self compositionConfigurationProgramArgumentsForKey:CompositionConfigurationPdfLatexPathKey];}
-(NSArray*) compositionConfigurationProgramArgumentsXeLaTeX
             {return [self compositionConfigurationProgramArgumentsForKey:CompositionConfigurationXeLatexPathKey];}
-(NSArray*) compositionConfigurationProgramArgumentsLaTeX
             {return [self compositionConfigurationProgramArgumentsForKey:CompositionConfigurationLatexPathKey];}
-(NSArray*) compositionConfigurationProgramArgumentsDviPdf
             {return [self compositionConfigurationProgramArgumentsForKey:CompositionConfigurationDviPdfPathKey];}
-(NSArray*) compositionConfigurationProgramArgumentsGs
             {return [self compositionConfigurationProgramArgumentsForKey:CompositionConfigurationGsPathKey];}
-(NSArray*) compositionConfigurationProgramArgumentsPsToPdf
             {return [self compositionConfigurationProgramArgumentsForKey:CompositionConfigurationPsToPdfPathKey];}
-(NSArray*) compositionConfigurationProgramArgumentsForKey:(NSString*)key
{
  NSArray* result = [[self objectForKey:CompositionConfigurationProgramArgumentsKey] objectForKey:key];
  if (!result) result = [NSArray array];
  return result;
}
//end compositionConfigurationProgramArgumentsForKey:

-(NSDictionary*) compositionConfigurationAdditionalProcessingScripts
                 {return [self objectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];}
-(NSDictionary*) compositionConfigurationAdditionalProcessingScriptsPreProcessing
                 {return [self compositionConfigurationAdditionalProcessingScriptsForKey:[[NSNumber numberWithInt:SCRIPT_PLACE_PREPROCESSING] stringValue]];}
-(NSDictionary*) compositionConfigurationAdditionalProcessingScriptsMiddleProcessing
                 {return [self compositionConfigurationAdditionalProcessingScriptsForKey:[[NSNumber numberWithInt:SCRIPT_PLACE_MIDDLEPROCESSING] stringValue]];}
-(NSDictionary*) compositionConfigurationAdditionalProcessingScriptsPostProcessing
                 {return [self compositionConfigurationAdditionalProcessingScriptsForKey:[[NSNumber numberWithInt:SCRIPT_PLACE_POSTPROCESSING] stringValue]];}
-(NSDictionary*) compositionConfigurationAdditionalProcessingScriptsForKey:(NSString*)key
                 {return [[self compositionConfigurationAdditionalProcessingScripts] objectForKey:key];}

-(BOOL)          compositionConfigurationUseLoginShell
                 {return [[self objectForKey:CompositionConfigurationUseLoginShellKey] boolValue];}

@end
