//
//  NSWorkspaceExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/07/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

//this file is an extension of the NSWorkspace class

#import <Cocoa/Cocoa.h>

@interface NSWorkspace (Extended)

@property (readonly, copy) NSString *applicationName;
@property (readonly, copy) NSString *applicationVersion;
@property (readonly, copy) NSString *applicationBundleIdentifier;
@property (readonly, copy) NSString *temporaryDirectory;
-(NSString*) getBestStandardPast:(NSSearchPathDirectory)searchPathDirectory domain:(NSSearchPathDomainMask)domain defaultValue:(NSString*)defaultValue;
-(BOOL)      closeApplicationWithBundleIdentifier:(NSString*)bundleIdentifier;
@end
