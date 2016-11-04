//
//  NSAttributedStringExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/08/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import "NSAttributedStringExtended.h"


@implementation NSAttributedString (Extended)

-(NSDictionary*) attachmentsOfType:(NSString*)type docAttributes:(NSDictionary*)docAttributes
{
  NSFileWrapper* fileWrapper = [self RTFDFileWrapperFromRange:NSMakeRange(0, [self length]) documentAttributes:docAttributes];
  NSDictionary* fileWrappers = [fileWrapper fileWrappers];
  NSArray* fileWrappersKeys = [fileWrappers allKeys];
  NSMutableDictionary* fileWrappersOfMatchingType = [NSMutableDictionary dictionaryWithCapacity:[fileWrappersKeys count]];
  NSEnumerator* enumerator = [fileWrappersKeys objectEnumerator];
  NSString* key = nil;
  while((key = [enumerator nextObject]))
  {
    if ([[key pathExtension] caseInsensitiveCompare:type] == NSOrderedSame)
      [fileWrappersOfMatchingType setObject:[fileWrappers objectForKey:key] forKey:key];
  }
  return fileWrappersOfMatchingType;
}

@end
