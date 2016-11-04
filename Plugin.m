//
//  Plugin.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import "Plugin.h"

@implementation Plugin

-(id) initWithPath:(NSString*)path
{
  if (!(self = [super init]))
    return nil;
  self->bundle = [[NSBundle alloc] initWithPath:path];
  if (!self->bundle)
  {
    [self release];
    return nil;
  }//end if (!self->bundle)
  return self;
}
//end initWithPath:

-(void) dealloc
{
  [self->cachedImage release];
  [self->principalClassInstance release];
  [self->bundle release];
  [super dealloc];
}
//end dealloc

-(NSBundle*) bundle
{
  return self->bundle;
}
//end bundle

-(NSString*) localizedName
{
  NSString* result = [self->bundle objectForInfoDictionaryKey:@"CFBundleName"];
  return !result ? @"" : result;
}
//end localizedName

-(void) load
{
  if ([self->bundle load])
  {
    Class bundlePrincipalClass = [self->bundle principalClass];
    if ([bundlePrincipalClass conformsToProtocol:@protocol(LaTeXiTPluginProtocol)])
      self->principalClassInstance = [[bundlePrincipalClass alloc] init];
  }//end if ([self->bundle load])
}
//end load

#pragma mark LaTeXiTPluginProtocol

-(NSImage*) icon
{
  if (!self->cachedImage)
  {
    @synchronized(self)
    {
      if (!self->cachedImage)
        self->cachedImage = [[self->principalClassInstance icon] retain];
      if (!self->cachedImage)
        self->cachedImage = [[[NSWorkspace sharedWorkspace] iconForFile:[self->bundle bundlePath]] retain];
    }//end @synchronized(self)
  }//end if (!self->cachedImage)
  return self->cachedImage;
}
//end icon

-(void) importConfigurationPanelIntoView:(NSView*)view
{
  [self->principalClassInstance importConfigurationPanelIntoView:view];
}
//end importConfigurationPanelIntoView

-(void) dropConfigurationPanel
{
  [self->principalClassInstance dropConfigurationPanel];
}
//end dropConfigurationPanel

@end
