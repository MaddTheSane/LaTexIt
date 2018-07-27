//
//  PreferencesWindow.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/08/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "PreferencesWindow.h"

#import "Utils.h"

@implementation PreferencesWindow

-(id) initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
  if (!isMacOS10_5OrAbove())
    windowStyle = windowStyle & ~NSUnifiedTitleAndToolbarWindowMask;//fixes a Tiger bug with segmented controls
  if (!((self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation])))
    return nil;
  return self;
}
//end initWithContentRect:styleMask:backing:defer:screen:

-(id) initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation screen:(NSScreen *)screen
{
  if (!isMacOS10_5OrAbove())
    windowStyle = windowStyle & ~NSUnifiedTitleAndToolbarWindowMask;//fixes a Tiger bug with segmented controls
  if (!((self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation screen:screen])))
    return nil;
  return self;
}
//end initWithContentRect:styleMask:backing:defer:screen:

@end
