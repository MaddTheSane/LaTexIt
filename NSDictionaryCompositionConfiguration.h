//
//  NSDictionaryCompositionConfiguration.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@interface NSDictionary (CompositionConfiguration)

-(composition_mode_t) compositionConfigurationCompositionMode;
-(NSString*)          compositionConfigurationProgramPathPdfLaTeX;
-(NSString*)          compositionConfigurationProgramPathXeLaTeX;
-(NSString*)          compositionConfigurationProgramPathLaTeX;
-(NSString*)          compositionConfigurationProgramPathDviPdf;
-(NSString*)          compositionConfigurationProgramPathGs;
-(NSString*)          compositionConfigurationProgramPathPsToPdf;
-(NSString*)          compositionConfigurationProgramPathForKey:(NSString*)key;
-(NSArray*)           compositionConfigurationProgramArgumentsPdfLaTeX;
-(NSArray*)           compositionConfigurationProgramArgumentsXeLaTeX;
-(NSArray*)           compositionConfigurationProgramArgumentsLaTeX;
-(NSArray*)           compositionConfigurationProgramArgumentsDviPdf;
-(NSArray*)           compositionConfigurationProgramArgumentsGs;
-(NSArray*)           compositionConfigurationProgramArgumentsPsToPdf;
-(NSArray*)           compositionConfigurationProgramArgumentsForKey:(NSString*)key;
-(NSDictionary*)      compositionConfigurationAdditionalProcessingScripts;
-(NSDictionary*)      compositionConfigurationAdditionalProcessingScriptsPreProcessing;
-(NSDictionary*)      compositionConfigurationAdditionalProcessingScriptsMiddleProcessing;
-(NSDictionary*)      compositionConfigurationAdditionalProcessingScriptsPostProcessing;
-(NSDictionary*)      compositionConfigurationAdditionalProcessingScriptsForKey:(NSString*)key;
-(BOOL)               compositionConfigurationUseLoginShell;

@end
