//
//  LaTeXiTPluginProtocol.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/09/10.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol LaTeXiTPluginProtocol

-(NSImage*) icon;
-(void) importConfigurationPanelIntoView:(NSView*)view;
-(void) dropConfigurationPanel;

@end
