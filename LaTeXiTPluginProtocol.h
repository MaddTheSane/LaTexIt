//
//  LaTeXiTPluginProtocol.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/09/10.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol LaTeXiTPluginProtocol <NSObject>

-(nullable NSImage*) icon;
-(void) importConfigurationPanelIntoView:(nonnull NSView*)view;
-(void) dropConfigurationPanel;

@end
