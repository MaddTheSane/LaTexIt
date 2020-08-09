//
//  NSDictionaryCompositionConfiguration.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "NSDictionaryCompositionConfiguration.h"

#import "PreferencesController.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSDictionary (CompositionConfiguration)

-(composition_mode_t) compositionConfigurationCompositionMode
             {return (composition_mode_t)[[self objectForKey:CompositionConfigurationCompositionModeKey] integerValue];}

-(NSString*) compositionConfigurationProgramPathPdfLaTeX
             {return [self compositionConfigurationProgramPathForKey:CompositionConfigurationPdfLatexPathKey];}
-(NSString*) compositionConfigurationProgramPathXeLaTeX
             {return [self compositionConfigurationProgramPathForKey:CompositionConfigurationXeLatexPathKey];}
-(NSString*) compositionConfigurationProgramPathLuaLaTeX
             {return [self compositionConfigurationProgramPathForKey:CompositionConfigurationLuaLatexPathKey];}
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
  NSString* result = self[key];
  return result;
}
//end compositionConfigurationProgramPathForKey:

-(NSArray*) compositionConfigurationProgramArgumentsPdfLaTeX
            {return [self compositionConfigurationProgramArgumentsForKey:CompositionConfigurationPdfLatexPathKey];}
-(NSArray*) compositionConfigurationProgramArgumentsXeLaTeX
            {return [self compositionConfigurationProgramArgumentsForKey:CompositionConfigurationXeLatexPathKey];}
-(NSArray*) compositionConfigurationProgramArgumentsLuaLaTeX
            {return [self compositionConfigurationProgramArgumentsForKey:CompositionConfigurationLuaLatexPathKey];}
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
  NSArray* result = self[CompositionConfigurationProgramArgumentsKey][key];
  if (!result) result = @[];
  return result;
}
//end compositionConfigurationProgramArgumentsForKey:

-(NSDictionary*) compositionConfigurationAdditionalProcessingScripts
                 {return self[CompositionConfigurationAdditionalProcessingScriptsKey];}
-(NSDictionary*) compositionConfigurationAdditionalProcessingScriptsPreProcessing
                 {return [self compositionConfigurationAdditionalProcessingScriptsForKey:[@(SCRIPT_PLACE_PREPROCESSING) stringValue]];}
-(NSDictionary*) compositionConfigurationAdditionalProcessingScriptsMiddleProcessing
                 {return [self compositionConfigurationAdditionalProcessingScriptsForKey:[@(SCRIPT_PLACE_MIDDLEPROCESSING) stringValue]];}
-(NSDictionary*) compositionConfigurationAdditionalProcessingScriptsPostProcessing
                 {return [self compositionConfigurationAdditionalProcessingScriptsForKey:[@(SCRIPT_PLACE_POSTPROCESSING) stringValue]];}
-(NSDictionary*) compositionConfigurationAdditionalProcessingScriptsForKey:(NSString*)key
                 {return [self compositionConfigurationAdditionalProcessingScripts][key];}

-(BOOL)          compositionConfigurationUseLoginShell
                 {return [self[CompositionConfigurationUseLoginShellKey] boolValue];}

@end
