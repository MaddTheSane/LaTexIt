//
//  NSDictionaryCompositionConfigurationAdditionalProcessingScript.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@interface NSDictionary (CompositionConfigurationAdditionalProcessingScript)

@property (readonly) BOOL compositionConfigurationAdditionalProcessingScriptEnabled;
@property (readonly) script_source_t compositionConfigurationAdditionalProcessingScriptSource;
@property (readonly, copy) NSString *compositionConfigurationAdditionalProcessingScriptFilePath;
@property (readonly, copy) NSString *compositionConfigurationAdditionalProcessingScriptShell;
@property (readonly, copy) NSString *compositionConfigurationAdditionalProcessingScriptBody;

@end
