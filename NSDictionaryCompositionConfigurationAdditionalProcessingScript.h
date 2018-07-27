//
//  NSDictionaryCompositionConfigurationAdditionalProcessingScript.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@interface NSDictionary (CompositionConfigurationAdditionalProcessingScript)

-(BOOL)            compositionConfigurationAdditionalProcessingScriptEnabled;
-(script_source_t) compositionConfigurationAdditionalProcessingScriptSource;
-(NSString*)       compositionConfigurationAdditionalProcessingScriptFilePath;
-(NSString*)       compositionConfigurationAdditionalProcessingScriptShell;
-(NSString*)       compositionConfigurationAdditionalProcessingScriptBody;

@end
