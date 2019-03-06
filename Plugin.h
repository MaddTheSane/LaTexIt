//
//  Plugin.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTPluginProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface Plugin : NSObject<LaTeXiTPluginProtocol> {
  NSBundle* bundle;
  NSImage*  cachedImage;
  id<LaTeXiTPluginProtocol> principalClassInstance;
}

-(instancetype)init UNAVAILABLE_ATTRIBUTE;
-(nullable instancetype) initWithPath:(NSString*)path NS_DESIGNATED_INITIALIZER;

@property (readonly, retain) NSBundle *bundle;
-(void)      load;
@property (readonly, copy) NSString *localizedName;

#pragma mark LaTeXiTPluginProtocol
@property (readonly, copy) NSImage * _Nullable icon;
-(void) importConfigurationPanelIntoView:(NSView*)view;
-(void) dropConfigurationPanel;

@end

NS_ASSUME_NONNULL_END
