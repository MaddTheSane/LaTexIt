//
//  NSWorkspaceExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/07/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

//this file is an extension of the NSWorkspace class

#import "NSWorkspaceExtended.h"

#import "NSFileManagerExtended.h"
#import "NDProcess.h"
#import "Utils.h"

@implementation NSWorkspace (Extended)

-(NSString*) applicationName
{
  NSString* result = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[NDProcess class]];//use bundleForClass because the Automator action would otherwise return info for Automator
  result = [[bundle infoDictionary] objectForKey:@"AMName"];
  if (!result)
    result = [[bundle infoDictionary] objectForKey:(NSString*)kCFBundleExecutableKey];
  return result;
}
//end applicationName

-(NSString*) applicationVersion
{
  NSString* result = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[NDProcess class]];//use bundleForClass because the Automator action would otherwise return info for Automator
  result = [[bundle infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
  return result;
}
//end applicationVersion

-(NSString*) applicationBundleIdentifier
{
  NSString* result = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[NDProcess class]];//use bundleForClass because the Automator action would otherwise return info for Automator
  result = [[bundle infoDictionary] objectForKey:(NSString*)kCFBundleIdentifierKey];
  return result;
}
//end applicationName

-(BOOL) closeApplicationWithBundleIdentifier:(NSString*)bundleIdentifier
{
  BOOL result = NO;
  id runningApplicationClass = NSClassFromString(@"NSRunningApplication");//10.6 only
  if (runningApplicationClass)
  {
    NSArray* runningApplications =
      [runningApplicationClass performSelector:@selector(runningApplicationsWithBundleIdentifier:) withObject:bundleIdentifier];
    NSEnumerator* enumerator = [runningApplications objectEnumerator];
    id runningApplication = nil;
    while((runningApplication = [enumerator nextObject]))
    {
      SEL terminateSelector = NSSelectorFromString(@"terminate");
      [runningApplication performSelector:terminateSelector];
      result |= YES;
    }
  }//end if (runningApplicationClass)
  else//if (!runningApplicationClass)
  {
    NSArray* runningApplications = [self runningApplications];
    NSEnumerator* enumerator = [runningApplications objectEnumerator];
    id application = nil;
    id applicationFound = nil;
    while((application = [enumerator nextObject]))
    {
      NSString* candidateBundleIdentifier = [application objectForKey:@"NSApplicationBundleIdentifier"];
      if ([candidateBundleIdentifier isEqualToString:bundleIdentifier])
      {
        applicationFound = application;
        break;
      }//end if ([candidateBundleIdentifier isEqualToString:bundleIdentifier])
    }//end for each application
    if (applicationFound)
    {
      NSNumber* processId = [application objectForKey:@"NSApplicationProcessIdentifier"];
      if (processId)
      {
        kill([processId intValue], SIGKILL);
        result = YES;
      }
    }//end if (applicationFound)
    else//if (!applicationFound)
    {
      NSString* applicationPath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:bundleIdentifier];
      NDProcess* process = [NDProcess processForApplicationPath:applicationPath];
      if (process)
      {
        kill([process processID], SIGKILL);
        result = YES;
      }
      else
      {
        NSArray* processes = [NDProcess everyProcessNamed:@"LaTeXiT Helper"];
        NSEnumerator* enumerator = [processes objectEnumerator];
        NDProcess* process = nil;
        while((process = [enumerator nextObject]))
        {
          kill([process processID], SIGKILL);
          result = YES;
        }//end for each process
      }//end if (!process)
    }//end if (!applicationFound)
  }//end if (!runningApplicationClass)
  return result;
}
//end closeApplicationWithBundleIdentifier:

-(NSString*) temporaryDirectory
{
  NSString* thisVersion = [self applicationVersion];
  if (!thisVersion)
    thisVersion = @"";
  NSArray* components = [thisVersion componentsSeparatedByString:@" "];
  if (components && [components count])
    thisVersion = [components objectAtIndex:0];

  NSString* temporaryPath =
    [NSTemporaryDirectory() stringByAppendingPathComponent:
      [NSString stringWithFormat:@"%@-%@", [self applicationName], thisVersion]];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  BOOL exists = [fileManager fileExistsAtPath:temporaryPath isDirectory:&isDirectory];
  if (exists && !isDirectory)
  {
    [fileManager removeItemAtPath:temporaryPath error:0];
    exists = NO;
  }
  if (!exists)
    [fileManager createDirectoryAtPath:temporaryPath withIntermediateDirectories:YES attributes:nil error:0];
  return temporaryPath;
}
//end temporaryDirectory

-(NSString*) getBestStandardPast:(NSSearchPathDirectory)searchPathDirectory domain:(NSSearchPathDomainMask)domain defaultValue:(NSString*)defaultValue
{
  NSString* result = nil;
  NSArray*  candidates = NSSearchPathForDirectoriesInDomains(searchPathDirectory, domain, YES);
  NSFileManager* fileManager = [NSFileManager defaultManager];
  BOOL isDirectory = YES;
  NSEnumerator* enumerator = [candidates objectEnumerator];
  NSString*     candidate  = nil;
  while(!result && ((candidate = [enumerator nextObject])))
  {
    if ([fileManager fileExistsAtPath:candidate isDirectory:&isDirectory] && isDirectory)
      result = candidate;
  }//else for each candidate
  
  if (!result)
    result = defaultValue;
  
  return result;
}
//end getBestStandardPast:domain:defaultValue:

@end
