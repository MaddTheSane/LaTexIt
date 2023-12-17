//
//  NSAttributedStringExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/08/06.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import "NSAttributedStringExtended.h"

#import "NSObjectExtended.h"

@implementation NSAttributedString (Extended)

-(NSRange) range
{
  NSRange result = NSMakeRange(0, [self length]);
  return result;
}
//end range

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

#if defined(USE_REGEXKITLITE) && USE_REGEXKITLITE
#else

@implementation NSMutableAttributedString (RegexKitLiteExtension)

-(NSInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement options:(RKLRegexOptions)options range:(NSRange)searchRange error:(NSError **)error
{
  NSInteger result = 0;
  NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:convertRKLOptions(options) error:error];
  NSArray* matches = [regex matchesInString:self.string options:0 range:self.range];
  for(NSUInteger i = 0, count = matches.count ; i<count ; ++i)
  {
    NSUInteger i_reversed = count-i-1;
    NSTextCheckingResult* match = [[matches objectAtIndex:i_reversed] dynamicCastToClass:[NSTextCheckingResult class]];
    NSRange matchRange = [match range];
    [self replaceCharactersInRange:matchRange withString:replacement];
  }//end for each match
  return result;
}
//end replaceOccurrencesOfRegex:withString:options:range:error:

@end

#endif

