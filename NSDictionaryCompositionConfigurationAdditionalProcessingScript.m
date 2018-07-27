//
//  NSDictionaryCompositionConfigurationAdditionalProcessingScript.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "NSDictionaryCompositionConfigurationAdditionalProcessingScript.h"

#import "PreferencesController.h"

@implementation NSDictionary (CompositionConfigurationAdditionalProcessingScript)

-(BOOL) compositionConfigurationAdditionalProcessingScriptEnabled
        {return [[self objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue];}
-(script_source_t) compositionConfigurationAdditionalProcessingScriptSource
        {return (script_source_t)[[self objectForKey:CompositionConfigurationAdditionalProcessingScriptTypeKey] intValue];}
-(NSString*) compositionConfigurationAdditionalProcessingScriptFilePath
        {return [self objectForKey:CompositionConfigurationAdditionalProcessingScriptPathKey];}
-(NSString*) compositionConfigurationAdditionalProcessingScriptShell
        {return [self objectForKey:CompositionConfigurationAdditionalProcessingScriptShellKey];}
-(NSString*) compositionConfigurationAdditionalProcessingScriptBody
        {return [self objectForKey:CompositionConfigurationAdditionalProcessingScriptContentKey];}

@end
