//
//  PreferencesWindow.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/08/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PreferencesWindow : NSWindow

-(id) initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation;
-(id) initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation screen:(NSScreen *)screen;

@end