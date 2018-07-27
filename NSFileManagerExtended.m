//
//  NSFileManagerExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/03/08.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "NSFileManagerExtended.h"

#include <unistd.h>

static NSMutableSet* createdTemporaryPaths = nil;

@interface NSFileManager (Extended_Private)
-(void) registerTemporaryPath:(NSString*)path;
@end

@implementation NSFileManager (Bridge10_5)

-(BOOL) bridge_createSymbolicLinkAtPath:(NSString*)path withDestinationPath:(NSString*)destPath error:(NSError**)error;
{
  BOOL result = NO;
  if ([self respondsToSelector:@selector(createSymbolicLinkAtPath:withDestinationPath:error:)])
    result = [self createSymbolicLinkAtPath:path withDestinationPath:destPath error:error];
  else
    result = [self createSymbolicLinkAtPath:path pathContent:destPath] || !symlink([destPath UTF8String], [path UTF8String]);
  return result;
}
//end bridge_createSymbolicLinkAtPath:withDestinationPath:error:

-(NSString*) bridge_destinationOfSymbolicLinkAtPath:(NSString*)path error:(NSError**)error
{
  NSString* result = nil;
  if ([self respondsToSelector:@selector(destinationOfSymbolicLinkAtPath:error:)])
    result = [self destinationOfSymbolicLinkAtPath:path error:error];
  else
    result = [self pathContentOfSymbolicLinkAtPath:path];
  return result;
}
//end bridge_destinationOfSymbolicLinkAtPath:error:

-(BOOL) bridge_createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error
{
  BOOL result = NO;
  if ([self respondsToSelector:@selector(createDirectoryAtPath:withIntermediateDirectories:attributes:error:)])
    result = [self createDirectoryAtPath:path withIntermediateDirectories:createIntermediates attributes:attributes error:error];
  else if (!createIntermediates)
  {
    result = [self createDirectoryAtPath:path attributes:attributes];
  }//end if (!createIntermediates)
  else//if (createIntermediates)
  {
    result = YES;
    BOOL isDirectory = NO;
    NSArray* components = [path pathComponents];
    components = components ? components : [NSArray array];
    unsigned int i = 0;
    for(i = 1 ; result && (i <= [components count]) ; ++i)
    {
      NSString* subPath = [NSString pathWithComponents:[components subarrayWithRange:NSMakeRange(0, i)]];
      result &= ([self fileExistsAtPath:subPath isDirectory:&isDirectory] && isDirectory) ||
      [self createDirectoryAtPath:subPath attributes:attributes];
    }//end for each subPath
  }//end if (createIntermediates)
  return result;
}
//end bridge_createDirectoryAtPath:withIntermediateDirectories:attributes:

-(NSArray*) bridge_contentsOfDirectoryAtPath:(NSString *)path error:(NSError**)error
{
  NSArray* result = nil;
  if ([self respondsToSelector:@selector(contentsOfDirectoryAtPath:error:)])
    result = [self contentsOfDirectoryAtPath:path error:error];
  else
    result = [self directoryContentsAtPath:path];
  return result;
}
//end bridge_contentsOfDirectoryAtPath:error:

-(BOOL) bridge_copyItemAtPath:(NSString*)srcPath toPath:(NSString*)dstPath error:(NSError**)error
{
  BOOL result = NO;
  if ([self respondsToSelector:@selector(copyItemAtPath:toPath:error:)])
    result = [self copyItemAtPath:srcPath toPath:dstPath error:error];
  else
    result = [self copyPath:srcPath toPath:dstPath handler:0];
  return result;
}
//end bridge_copyItemAtPath:toPath:error:

-(BOOL) bridge_removeItemAtPath:(NSString*)path error:(NSError**)error
{
  BOOL result = NO;
  if ([self respondsToSelector:@selector(removeItemAtPath:error:)])
    result = [self removeItemAtPath:path error:error];
  else
    result = [self removeFileAtPath:path handler:0];
  return result;
}
//end bridge_removeItemAtPath:error:

-(BOOL) bridge_moveItemAtPath:(NSString*)srcPath toPath:(NSString*)dstPath error:(NSError**)error
{
  BOOL result = NO;
  if ([self respondsToSelector:@selector(moveItemAtPath:toPath:error:)])
    result = [self moveItemAtPath:srcPath toPath:dstPath error:error];
  else
    result = [self movePath:srcPath toPath:dstPath handler:0];
  return result;
}
//end bridge_moveItemAtPath:toPath:error:

-(NSDictionary *) bridge_attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error
{
  NSDictionary* result = nil;
  if ([self respondsToSelector:@selector(attributesOfFileSystemForPath:error:)])
    result = [self attributesOfFileSystemForPath:path error:error];
  else
    result = [self fileSystemAttributesAtPath:path];
  return result;
}
//end bridge_attributesOfFileSystemForPath:error:

-(BOOL) bridge_setAttributes:(NSDictionary *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error
{
  BOOL result = NO;
  if ([self respondsToSelector:@selector(setAttributes:ofItemAtPath:error:)])
    result = [self setAttributes:attributes ofItemAtPath:path error:error];
  else
    result = [self changeFileAttributes:attributes atPath:path];
  return result;
}
//end bridge_setAttributes:ofItemAtPath:error:

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
  unsigned int i = 0;
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
    unsigned int length = [tempFilenameTemplate lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    char* tmpString = (char*)calloc(length+1, sizeof(char));
    memcpy(tmpString, [tempFilenameTemplate UTF8String], length); 
    int fd = mkstemps(tmpString, [fileNameWithExtension length]-[templateString length]);
    if (fd != -1)
      fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];

    NSString* createdPath = [NSString stringWithUTF8String:tmpString];
    if (createdPath)
      [self registerTemporaryPath:createdPath];
    if (outFilePath)
      *outFilePath = createdPath;
    free(tmpString);
  }
  return [fileHandle autorelease];
}
//end temporaryFileWithTemplate:extension:outFilePath:

-(BOOL) createLinkInDirectory:(NSString*)directoryPath toTarget:(NSString*)targetPath linkName:(NSString*)linkName outLinkPath:(NSString**)outLinkPath
{
  BOOL result = NO;
  NSString* linkPath = [directoryPath stringByAppendingPathComponent:(linkName ? linkName : [targetPath lastPathComponent])];
  if (![self fileExistsAtPath:linkPath])
    result = [self bridge_createSymbolicLinkAtPath:linkPath withDestinationPath:targetPath error:nil];
  else
  {
    NSDictionary* attributes = [self fileAttributesAtPath:linkPath traverseLink:NO];
    if ([[attributes objectForKey:NSFileType] isEqualToString:NSFileTypeSymbolicLink])
      result = [[self bridge_destinationOfSymbolicLinkAtPath:linkPath error:nil] isEqualToString:targetPath];
    if (!result)
      result = [self removeFileAtPath:linkPath handler:nil] &&
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

-(void) removeAllCreatedTemporaryPaths
{
  @synchronized(self)
  {
    NSEnumerator* enumerator = [createdTemporaryPaths objectEnumerator];
    NSString* filePath = nil;
    while((filePath = [enumerator nextObject]))
      [self removeFileAtPath:filePath handler:0];
    [createdTemporaryPaths removeAllObjects];
  }//end @synchronized(self)
}
//end removeAllCreatedTemporaryPaths

-(NSString*) UTIFromPath:(NSString*)path
{
  NSString* result = nil;
  OSStatus error = 0;
  FSRef fsRef = {{0}};
  Boolean isDirectory = NO;
  error = FSPathMakeRefWithOptions((const UInt8*)[path fileSystemRepresentation], kFSPathMakeRefDefaultOptions, &fsRef, &isDirectory);
  if (!error && !isDirectory)
  {
    CFStringRef uti = 0;
    error = error ? error : LSCopyItemAttribute(&fsRef, kLSRolesAll, kLSItemContentType, (CFTypeRef*)&uti);
    result = [(NSString*)uti autorelease];
  }//end if (!error && !isDirectory)
  return result;
};
//end UTIFromPath:

-(NSString*) UTIFromURL:(NSURL*)url
{
  NSString* result = nil;
  OSStatus error = 0;
  FSRef fsRef = {{0}};
  Boolean ok = CFURLGetFSRef((CFURLRef)url, &fsRef);
  if (ok)
  {
    CFStringRef uti = 0;
    error = error ? error : LSCopyItemAttribute(&fsRef, kLSRolesAll, kLSItemContentType, (CFTypeRef*)&uti);
    result = [(NSString*)uti autorelease];
  }//end if (ok)
  return result;
};
//end UTIFromURL:

@end
