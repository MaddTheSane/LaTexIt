//
//  NSFileManagerExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/03/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "NSFileManagerExtended.h"

#include <unistd.h>

@implementation NSFileManager (Extended)

-(BOOL) createDirectoryPath:(NSString*)path attributes:(NSDictionary*)attributes
{
  BOOL ok = YES;
  BOOL isDirectory = NO;
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSArray* components = [path pathComponents];
  components = components ? components : [NSArray array];
  unsigned int i = 0;
  for(i = 1 ; ok && (i <= [components count]) ; ++i)
  {
    NSString* subPath = [NSString pathWithComponents:[components subarrayWithRange:NSMakeRange(0, i)]];
    ok &= ([fileManager fileExistsAtPath:subPath isDirectory:&isDirectory] && isDirectory) ||
           [fileManager createDirectoryAtPath:subPath attributes:attributes];
  }//end for each subPath
  return ok;
}
//end createDirectoryPath:attributes:

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
    #ifdef PANTHER
    unsigned int length = [tempFilenameTemplate length];
    #else
    unsigned int length = [tempFilenameTemplate lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    #endif
    char* tmpString = (char*)calloc(length+1, sizeof(char));
    memcpy(tmpString, [tempFilenameTemplate UTF8String], length); 
    int fd = mkstemps(tmpString, [fileNameWithExtension length]-[templateString length]);
    if (fd != -1)
      fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd closeOnDealloc:YES];
    if (outFilePath)
      *outFilePath = [NSString stringWithUTF8String:tmpString];
    free(tmpString);
  }
  return [fileHandle autorelease];
}
//end temporaryFileWithTemplate:extension:outFilePath:

-(BOOL) createLinkInDirectory:(NSString*)directoryPath toTarget:(NSString*)targetPath linkName:(NSString*)linkName
{
  BOOL result = NO;
  NSString* linkPath = [directoryPath stringByAppendingPathComponent:(linkName ? linkName : [targetPath lastPathComponent])];
  if (![self fileExistsAtPath:linkPath])
    result = [self createSymbolicLinkAtPath:linkPath withDestinationPath:targetPath error:nil];
  else
  {
    NSDictionary* attributes = [self fileAttributesAtPath:linkPath traverseLink:NO];
    if ([[attributes objectForKey:NSFileType] isEqualToString:NSFileTypeSymbolicLink])
      result = [[self destinationOfSymbolicLinkAtPath:linkPath error:nil] isEqualToString:targetPath];
    if (!result)
      result = [self removeFileAtPath:linkPath handler:nil] &&
               [self createLinkInDirectory:directoryPath toTarget:targetPath linkName:linkName];
  }
  return result;
}
//end createLinkInDirectory:toTarget:linkName:

@end
