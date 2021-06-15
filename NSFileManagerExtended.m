//
//  NSFileManagerExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/03/08.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "NSFileManagerExtended.h"

#include <unistd.h>

static NSMutableSet* createdTemporaryPaths = nil;

@interface NSFileManager (Extended_Private)
-(void) registerTemporaryPath:(NSString*)path;
@end

@implementation NSFileManager (Extended)

-(NSSet*) createdTemporaryPaths
{
  return createdTemporaryPaths;
}
//end createdTemporaryPaths

-(NSString*) localizedPath:(NSString*)path
{
  NSMutableArray* localizedPathComponents = [NSMutableArray array];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSArray* components = [path pathComponents];
  components = components ? components : [NSArray array];
  NSUInteger i = 0;
  for(i = 1 ; (i <= [components count]) ; ++i)
  {
    NSString* subPath = [NSString pathWithComponents:[components subarrayWithRange:NSMakeRange(0, i)]];
    [localizedPathComponents addObject:[fileManager displayNameAtPath:subPath]];
  }//end for each subPath
  return [NSString pathWithComponents:localizedPathComponents];
}
//end localizedPath:

-(NSFileHandle*) temporaryFileWithTemplate:(NSString*)templateString extension:(NSString*)extension outFilePath:(NSString**)outFilePath workingDirectory:(NSString*)workingDirectory
{
  NSFileHandle* fileHandle = nil;
  if (templateString && ![templateString isEqualToString:@""])
  {
    NSString* fileNameWithExtension = (extension && ![extension isEqualToString:@""])
                                        ? [templateString stringByAppendingPathExtension:extension] : templateString;
    NSString* tempFilenameTemplate = [workingDirectory stringByAppendingPathComponent:fileNameWithExtension];
    NSUInteger length = [tempFilenameTemplate lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    char* tmpString = (char*)calloc(length+1, sizeof(char));
    memcpy(tmpString, [tempFilenameTemplate UTF8String], length); 
    int fd = mkstemps(tmpString, (int)([fileNameWithExtension length]-[templateString length]));
    if (fd != -1)
      fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];

    NSString* createdPath = [NSString stringWithUTF8String:tmpString];
    if (createdPath)
      [self registerTemporaryPath:createdPath];
    if (outFilePath)
      *outFilePath = createdPath;
    free(tmpString);
  }
  #ifdef ARC_ENABLED
  return fileHandle;
  #else
  return [fileHandle autorelease];
  #endif
}
//end temporaryFileWithTemplate:extension:outFilePath:

-(BOOL) createLinkInDirectory:(NSString*)directoryPath toTarget:(NSString*)targetPath linkName:(NSString*)linkName outLinkPath:(NSString**)outLinkPath
{
  BOOL result = NO;
  NSString* linkPath = [directoryPath stringByAppendingPathComponent:(linkName ? linkName : [targetPath lastPathComponent])];
  if (![self fileExistsAtPath:linkPath])
    result = [self createSymbolicLinkAtPath:linkPath withDestinationPath:targetPath error:nil];
  else
  {
    NSDictionary* attributes = [self attributesOfItemAtPath:linkPath error:nil];
    if ([[attributes objectForKey:NSFileType] isEqualToString:NSFileTypeSymbolicLink])
      result = [[self destinationOfSymbolicLinkAtPath:linkPath error:nil] isEqualToString:targetPath];
    if (!result)
      result = [self removeItemAtPath:linkPath error:nil] &&
               [self createLinkInDirectory:directoryPath toTarget:targetPath linkName:linkName outLinkPath:outLinkPath];
  }
  if (outLinkPath)
    *outLinkPath = !result ? nil : linkPath;
  return result;
}
//end createLinkInDirectory:toTarget:linkName:outLinkPath:

-(void) registerTemporaryPath:(NSString*)path
{
  if (!createdTemporaryPaths)
  {
    @synchronized(self)
    {
      if (!createdTemporaryPaths)
        createdTemporaryPaths = [[NSMutableSet alloc] init];
    }//end @synchronized(self)
  }//end if (!createdTemporaryPaths)
  if (path && createdTemporaryPaths)
  {
    @synchronized(self)
    {
      [createdTemporaryPaths addObject:path];
    }//end @synchronized(self)
  }//end if (createdTemporaryPaths)
}
//end registerTemporaryPath

-(void) unregisterTemporaryPath:(NSString*)path
{
  if (path && createdTemporaryPaths)
  {
    @synchronized(self)
    {
      [createdTemporaryPaths removeObject:path];
    }//end @synchronized(self)
  }//end if (createdTemporaryPaths)
}
//end unregisterTemporaryPath:

-(void) removeAllCreatedTemporaryPaths
{
  @synchronized(self)
  {
    NSEnumerator* enumerator = [createdTemporaryPaths objectEnumerator];
    NSString* filePath = nil;
    while((filePath = [enumerator nextObject]))
      [self removeItemAtPath:filePath error:nil];
    [createdTemporaryPaths removeAllObjects];
  }//end @synchronized(self)
}
//end removeAllCreatedTemporaryPaths

-(NSString*) UTIFromPath:(NSString*)path
{
  NSString* result = nil;
  if (path)
    [[NSURL fileURLWithPath:path] getResourceValue:&result forKey:NSURLTypeIdentifierKey error:nil];
  return result;
};
//end UTIFromPath:

-(NSString*) UTIFromURL:(NSURL*)url
{
  NSString* result = nil;
  [url getResourceValue:&result forKey:NSURLTypeIdentifierKey error:nil];
  return result;
};
//end UTIFromURL:

-(NSString*) getUnusedFilePathFromPrefix:(NSString*)filePrefix extension:(NSString*)extension folder:(NSString*)folder startSuffix:(NSUInteger)startSuffix
{
  NSString* result = nil;
  NSString* fileName = nil;
  NSString* filePath = nil;
  NSUInteger suffix = startSuffix;
  do
  {
    fileName = [NSString stringWithFormat:@"%@%@",
                 filePrefix,
                 !suffix ? @"" : [NSString stringWithFormat:@"-%lu", (unsigned long)suffix]];
    ++suffix;
    fileName = [fileName stringByAppendingPathExtension:extension];
    filePath = [folder stringByAppendingPathComponent:fileName];
  } while ((suffix != NSNotFound) && [self fileExistsAtPath:filePath]);
  result = filePath;
  return result;
}
//end getUnusedFilePathFromPrefix:folder:startSuffix:

@end
