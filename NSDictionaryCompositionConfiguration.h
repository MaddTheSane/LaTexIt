//
//  NSDictionaryCompositionConfiguration.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@interface NSDictionary (CompositionConfiguration)

@property (readonly) composition_mode_t compositionConfigurationCompositionMode;
@property (readonly, copy) NSString *compositionConfigurationProgramPathPdfLaTeX;
@property (readonly, copy) NSString *compositionConfigurationProgramPathXeLaTeX;
@property (readonly, copy) NSString *compositionConfigurationProgramPathLuaLaTeX;
@property (readonly, copy) NSString *compositionConfigurationProgramPathLaTeX;
@property (readonly, copy) NSString *compositionConfigurationProgramPathDviPdf;
@property (readonly, copy) NSString *compositionConfigurationProgramPathGs;
@property (readonly, copy) NSString *compositionConfigurationProgramPathPsToPdf;
-(NSString*)          compositionConfigurationProgramPathForKey:(NSString*)key;
@property (readonly, copy) NSArray *compositionConfigurationProgramArgumentsPdfLaTeX;
@property (readonly, copy) NSArray *compositionConfigurationProgramArgumentsXeLaTeX;
@property (readonly, copy) NSArray *compositionConfigurationProgramArgumentsLuaLaTeX;
@property (readonly, copy) NSArray *compositionConfigurationProgramArgumentsLaTeX;
@property (readonly, copy) NSArray *compositionConfigurationProgramArgumentsDviPdf;
@property (readonly, copy) NSArray *compositionConfigurationProgramArgumentsGs;
@property (readonly, copy) NSArray *compositionConfigurationProgramArgumentsPsToPdf;
-(NSArray*)           compositionConfigurationProgramArgumentsForKey:(NSString*)key;
@property (readonly, copy) NSDictionary *compositionConfigurationAdditionalProcessingScripts;
@property (readonly, copy) NSDictionary *compositionConfigurationAdditionalProcessingScriptsPreProcessing;
@property (readonly, copy) NSDictionary *compositionConfigurationAdditionalProcessingScriptsMiddleProcessing;
@property (readonly, copy) NSDictionary *compositionConfigurationAdditionalProcessingScriptsPostProcessing;
-(NSDictionary*)      compositionConfigurationAdditionalProcessingScriptsForKey:(NSString*)key;
@property (readonly) BOOL compositionConfigurationUseLoginShell;

@end
