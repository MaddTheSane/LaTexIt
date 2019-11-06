//
//  NSWorkspaceExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/07/05.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

//this file is an extension of the NSWorkspace class

#import "NSWorkspaceExtended.h"

#import "NSFileManagerExtended.h"
#import "Utils.h"

@interface BlankNoUseClass : NSObject
@end

@implementation BlankNoUseClass
@end

@implementation NSWorkspace (Extended)

-(NSString*) applicationName
{
  NSString* result = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[BlankNoUseClass class]];//use bundleForClass because the Automator action would otherwise return info for Automator
  result = [[bundle infoDictionary] objectForKey:@"AMName"];
  if (!result)
    result = [[bundle infoDictionary] objectForKey:(NSString*)kCFBundleExecutableKey];
  return result;
}
//end applicationName

-(NSString*) applicationVersion
{
  NSString* result = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[BlankNoUseClass class]];//use bundleForClass because the Automator action would otherwise return info for Automator
  result = [[bundle infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
  return result;
}
//end applicationVersion

-(NSString*) applicationBundleIdentifier
{
  NSString* result = nil;
  NSBundle* bundle = [NSBundle bundleForClass:[BlankNoUseClass class]];//use bundleForClass because the Automator action would otherwise return info for Automator
  result = [[bundle infoDictionary] objectForKey:(NSString*)kCFBundleIdentifierKey];
  return result;
}
//end applicationName

-(BOOL) closeApplicationWithBundleIdentifier:(NSString*)bundleIdentifier
{
  BOOL result = NO;
    NSArray<NSRunningApplication*>* runningApplications =
      [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    for (NSRunningApplication *runningApplication in runningApplications)
    {
      [runningApplication terminate];
      result = YES;
    }
  return result;
}
//end closeApplicationWithBundleIdentifier:

-(NSString*) temporaryDirectory
{
  NSString* thisVersion = [self applicationVersion];
  if (!thisVersion)
    thisVersion = @"";
  NSArray* components = [thisVersion componentsSeparatedByString:@" "];
  if (components && components.count)
    thisVersion = components[0];

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
