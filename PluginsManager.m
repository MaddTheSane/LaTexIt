//
//  PluginsManager.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.
//

#import "PluginsManager.h"

#import "Plugin.h"
#import "NSFileManagerExtended.h"
#import "NSWorkspaceExtended.h"

@interface PluginsManager ()
-(void) loadPlugins;
@end

@implementation PluginsManager

static PluginsManager* sharedManagerInstance = nil; //the (private) singleton

+(PluginsManager*) sharedManager //access the unique instance of PluginsManager
{
  if (!sharedManagerInstance)
  {
    @synchronized(self)
    {
      if (!sharedManagerInstance)
        sharedManagerInstance = [[self  alloc] init];
    }//end @synchronized(self)
  }//end if (!sharedManagerInstance)
  return sharedManagerInstance;
}
//end sharedManager

+(id) allocWithZone:(NSZone *)zone
{
  @synchronized(self)
  {
    if (!sharedManagerInstance)
       return [super allocWithZone:zone];
  }
  return sharedManagerInstance;
}
//end allocWithZone:

-(id) copyWithZone:(NSZone *)zone
{
  return self;
}
//end copyWithZone:

-(id) retain
{
  return self;
}
//end retain

-(NSUInteger) retainCount
{
  return UINT_MAX;  //denotes an object that cannot be released
}
//end retainCount

-(oneway void) release
{
}
//end release

-(id) autorelease
{
  return self;
}
//end autorelease

//The init method can be called several times, it will only be applied once on the singleton
-(id) init
{
  if (self && (self != sharedManagerInstance))  //do not recreate an instance
  {
    if ((!(self = [super init])))
      return nil;
    sharedManagerInstance = self;
    self->plugins = [[NSMutableArray alloc] init];
    if (!self->plugins)
    {
      [self release];
      return nil;
    }//end if (!self->plugins)
    [self loadPlugins];
  }//end if (self && (self != sharedManagerInstance))  //do not recreate an instance
  return self;
}
//end init

-(void) dealloc
{
  [self->plugins release];
  [super dealloc];
}
//end dealloc

-(NSArray*) plugins
{
  return [[self->plugins copy] autorelease];
}
//end plugins

-(void) loadPlugins
{
  NSFileManager* fileManager        =  [NSFileManager defaultManager];                           
  NSMutableArray* allPluginsEntries = [NSMutableArray array];
  NSEnumerator* domainPathsEnumerator = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask , YES) objectEnumerator];
  NSString* domainPath = nil;
  while((domainPath = [domainPathsEnumerator nextObject]))
  {
    NSString* domainName = domainPath;
    NSArray* pathComponents = [NSArray arrayWithObjects:domainPath, @"Application Support", [[NSWorkspace sharedWorkspace] applicationName], @"PlugIns", nil];
    NSString* directoryPath = [NSString pathWithComponents:pathComponents];
    NSArray* pluginsPath  = [fileManager bridge_contentsOfDirectoryAtPath:directoryPath error:0];
    NSMutableArray* pluginsFullPaths = [NSMutableArray arrayWithCapacity:[pluginsPath count]];
    NSEnumerator* pluginsEnumerator = [pluginsPath objectEnumerator];
    NSString* file = nil;
    while((file = [pluginsEnumerator nextObject]))
    {
      file = [directoryPath stringByAppendingPathComponent:file];
      BOOL isDirectory = NO;
      if ([fileManager fileExistsAtPath:file isDirectory:&isDirectory] && isDirectory &&
          ([[file pathExtension] caseInsensitiveCompare:@"latexitplugin"] == NSOrderedSame))
        [pluginsFullPaths addObject:file];
    }//end for each latexpalette subfolder
    
    if (domainName)
      [allPluginsEntries addObject:
        [NSDictionary dictionaryWithObjectsAndKeys:domainName, @"domainName", pluginsFullPaths, @"paths", nil]];
  }//end for each domain
  
  //we got all the palettes
  NSEnumerator* pluginsEntriesEnumerator = [allPluginsEntries objectEnumerator];
  NSDictionary* pluginEntry = nil;
  while((pluginEntry = [pluginsEntriesEnumerator nextObject]))
  {
    //NSString* domainName = [pluginEntry objectForKey:@"domainName"];
    NSEnumerator* pluginsPathEnumerator = [[pluginEntry objectForKey:@"paths"] objectEnumerator];
    NSString* pluginFilePath = nil;
    while((pluginFilePath = [pluginsPathEnumerator nextObject]))
    {
      Plugin* plugin = [[Plugin alloc] initWithPath:pluginFilePath];
      if (plugin)
        [self->plugins addObject:plugin];
      [plugin release];
    }//end for each pluginFilePath
  }//end for each pluginEntry
  
  [self->plugins makeObjectsPerformSelector:@selector(load)];
}
//end loadPlugins:

@end
