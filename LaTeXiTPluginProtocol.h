//
//  LaTeXiTPluginProtocol.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/09/10.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol LaTeXiTPluginProtocol <NSObject>

@property (readonly, copy) NSImage * _Nullable icon;
-(void) importConfigurationPanelIntoView:(nonnull NSView*)view;
-(void) dropConfigurationPanel;

@end
