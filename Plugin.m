//
//  Plugin.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "Plugin.h"

@implementation Plugin
@synthesize bundle;

-(instancetype) initWithPath:(NSString*)path
{
  if (!(self = [super init]))
    return nil;
  bundle = [[NSBundle alloc] initWithPath:path];
  if (!bundle)
  {
    return nil;
  }//end if (!self->bundle)
  return self;
}
//end initWithPath:

-(NSString*) localizedName
{
  NSString* result = [self->bundle objectForInfoDictionaryKey:@"CFBundleName"];
  return !result ? @"" : result;
}
//end localizedName

-(void) load
{
  if ([bundle load])
  {
    Class bundlePrincipalClass = bundle.principalClass;
    if ([bundlePrincipalClass conformsToProtocol:@protocol(LaTeXiTPluginProtocol)])
      principalClassInstance = [[bundlePrincipalClass alloc] init];
  }//end if ([self->bundle load])
}
//end load

#pragma mark LaTeXiTPluginProtocol

-(NSImage*) icon
{
  if (!cachedImage)
  {
    @synchronized(self)
    {
      if (!cachedImage)
        cachedImage = [principalClassInstance icon];
      if (!cachedImage)
        cachedImage = [[NSWorkspace sharedWorkspace] iconForFile:bundle.bundlePath];
    }//end @synchronized(self)
  }//end if (!self->cachedImage)
  return cachedImage;
}
//end icon

-(void) importConfigurationPanelIntoView:(NSView*)view
{
  [principalClassInstance importConfigurationPanelIntoView:view];
}
//end importConfigurationPanelIntoView

-(void) dropConfigurationPanel
{
  [principalClassInstance dropConfigurationPanel];
}
//end dropConfigurationPanel

@end
