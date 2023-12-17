//
//  LaTeXiTPluginProtocol.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/09/10.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol LaTeXiTPluginProtocol <NSObject>

-(NSImage*) icon;
@property (readonly, copy) NSImage *icon;
-(void) importConfigurationPanelIntoView:(NSView*)view;
-(void) dropConfigurationPanel;

@end
