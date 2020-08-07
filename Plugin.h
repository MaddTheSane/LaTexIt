//
//  Plugin.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTPluginProtocol.h"

@interface Plugin : NSObject<LaTeXiTPluginProtocol> {
  NSBundle* bundle;
  NSImage*  cachedImage;
  id<NSObject,LaTeXiTPluginProtocol> principalClassInstance;
}

-(id) initWithPath:(NSString*)path;

-(NSBundle*) bundle;
-(void)      load;
-(NSString*) localizedName;

#pragma mark LaTeXiTPluginProtocol
-(NSImage*) icon;
-(void) importConfigurationPanelIntoView:(NSView*)view;
-(void) dropConfigurationPanel;

@end
