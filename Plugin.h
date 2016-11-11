//
//  Plugin.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTPluginProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface Plugin : NSObject<LaTeXiTPluginProtocol> {
  NSBundle* bundle;
  NSImage*  cachedImage;
  id<NSObject,LaTeXiTPluginProtocol> principalClassInstance;
}

-(nullable instancetype) initWithPath:(NSString*)path;

@property (readonly, retain) NSBundle *bundle;
-(void)      load;
@property (readonly, copy) NSString *localizedName;

#pragma mark LaTeXiTPluginProtocol
-(nullable NSImage*) icon;
-(void) importConfigurationPanelIntoView:(NSView*)view;
-(void) dropConfigurationPanel;

@end

NS_ASSUME_NONNULL_END
