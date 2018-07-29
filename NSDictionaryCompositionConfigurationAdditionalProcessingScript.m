//
//  NSDictionaryCompositionConfigurationAdditionalProcessingScript.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSDictionaryCompositionConfigurationAdditionalProcessingScript.h"

#import "PreferencesController.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSDictionary (CompositionConfigurationAdditionalProcessingScript)

-(BOOL) compositionConfigurationAdditionalProcessingScriptEnabled
        {return [self[CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue];}
-(script_source_t) compositionConfigurationAdditionalProcessingScriptSource
        {return (script_source_t)[self[CompositionConfigurationAdditionalProcessingScriptTypeKey] intValue];}
-(NSString*) compositionConfigurationAdditionalProcessingScriptFilePath
        {return self[CompositionConfigurationAdditionalProcessingScriptPathKey];}
-(NSString*) compositionConfigurationAdditionalProcessingScriptShell
        {return self[CompositionConfigurationAdditionalProcessingScriptShellKey];}
-(NSString*) compositionConfigurationAdditionalProcessingScriptBody
        {return self[CompositionConfigurationAdditionalProcessingScriptContentKey];}

@end
