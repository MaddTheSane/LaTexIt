//
//  NSWorkspaceExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/07/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

//this file is an extension of the NSWorkspace class

#import <Cocoa/Cocoa.h>

@interface NSWorkspace (Extended)

-(NSString*) applicationName;
-(NSString*) applicationVersion;
-(NSString*) applicationBundleIdentifier;
-(NSString*) temporaryDirectory;
-(NSString*) getBestStandardPast:(NSSearchPathDirectory)searchPathDirectory domain:(NSSearchPathDomainMask)domain defaultValue:(NSString*)defaultValue;
-(BOOL)      closeApplicationWithBundleIdentifier:(NSString*)bundleIdentifier;
@end
