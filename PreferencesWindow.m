//
//  PreferencesWindow.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/08/09.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "PreferencesWindow.h"

#import "Utils.h"

@implementation PreferencesWindow

-(id) initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
  if (!((self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation])))
    return nil;
  return self;
}
//end initWithContentRect:styleMask:backing:defer:screen:

-(id) initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation screen:(NSScreen *)screen
{
  if (!((self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation screen:screen])))
    return nil;
  return self;
}
//end initWithContentRect:styleMask:backing:defer:screen:

@end
