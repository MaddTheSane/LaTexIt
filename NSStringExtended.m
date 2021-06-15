//
//  NSStringExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSWorkspace class

#import "NSStringExtended.h"

#import "NSObjectExtended.h"

#import "Utils.h"

@implementation NSString (Extended)

//a similar method exists on Tiger, but does not work as I expect; this is a wrapper plus some additions
+(id) stringWithContentsOfFile:(NSString*)path guessEncoding:(NSStringEncoding*)enc error:(NSError**)error
{
  NSString* string = nil;
  string = [NSString stringWithContentsOfFile:path usedEncoding:enc error:error];
  if (!string)
  {
    if (error)
      *error = nil;
    NSStringEncoding usedEncoding = NSUTF8StringEncoding;
    NSData* data = !path ? nil : [NSData dataWithContentsOfFile:path options:NSUncachedRead error:nil];
    if (!string)
    {
      usedEncoding = NSUTF8StringEncoding;
      string = [[NSString alloc] initWithData:data encoding:usedEncoding];
    }
    if (!string)
    {
      usedEncoding = NSMacOSRomanStringEncoding;
      string = [[NSString alloc] initWithData:data encoding:usedEncoding];
    }
    if (!string)
    {
      usedEncoding = NSISOLatin1StringEncoding;
      string = [[NSString alloc] initWithData:data encoding:usedEncoding];
    }
    if (!string)
    {
      usedEncoding = NSASCIIStringEncoding;
      string = [[NSString alloc] initWithData:data encoding:usedEncoding];
    }
    if (enc)
      *enc = usedEncoding;
    #ifdef ARC_ENABLED
    #else
    [string autorelease];
    #endif
  }
  return string;
}
//end stringWithContentsOfFile:guessEncoding:error:

+(id) stringWithContentsOfURL:(NSURL*)url guessEncoding:(NSStringEncoding*)enc error:(NSError**)error
{
  NSString* string = nil;
  string = [NSString stringWithContentsOfURL:url usedEncoding:enc error:error];
  if (!string)
  {
    if (error)
      *error = nil;
    NSStringEncoding usedEncoding = NSUTF8StringEncoding;
    NSData* data = [NSData dataWithContentsOfURL:url];
    if (!string)
    {
      usedEncoding = NSUTF8StringEncoding;
      string = [[NSString alloc] initWithData:data encoding:usedEncoding];
    }
    if (!string)
    {
      usedEncoding = NSMacOSRomanStringEncoding;
      string = [[NSString alloc] initWithData:data encoding:usedEncoding];
    }
    if (!string)
    {
      usedEncoding = NSISOLatin1StringEncoding;
      string = [[NSString alloc] initWithData:data encoding:usedEncoding];
    }
    if (!string)
    {
      usedEncoding = NSASCIIStringEncoding;
      string = [[NSString alloc] initWithData:data encoding:usedEncoding];
    }
    if (enc)
      *enc = usedEncoding;
    #ifdef ARC_ENABLED
    #else
    [string autorelease];
    #endif
  }
  return string;
}
//end stringWithContentsOfURL:guessEncoding:error:

+(BOOL) isNilOrEmpty:(NSString*)string
{
  BOOL result = !string || [string isEqualToString:@""];
  return result;
}
//enc isNilOrEmpty;

-(NSRange) range
{
  return NSMakeRange(0, self.length);
}
//end range

-(NSString*) string
{
  return self;
}
//end string

-(NSString*) trim
{
  return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
//end trim

-(BOOL) startsWith:(NSString*)substring options:(unsigned)mask
{
  BOOL ok = NO;
  NSUInteger selfLength = [self length];
  NSUInteger subLength = [substring length];
  if (selfLength >= subLength)
  {
    NSRange rangeOfBegin = NSMakeRange(0, subLength);
    ok = ([[self substringWithRange:rangeOfBegin] compare:substring options:mask] == NSOrderedSame);
  }
  return ok;
}
//end startsWith:options:

-(BOOL) endsWith:(NSString*)substring options:(unsigned)mask
{
  BOOL ok = NO;
  NSUInteger selfLength = [self length];
  NSUInteger subLength = [substring length];
  if (selfLength >= subLength)
  {
    NSRange rangeOfEnd = NSMakeRange(selfLength-subLength, subLength);
    ok = ([[self substringWithRange:rangeOfEnd] compare:substring options:mask] == NSOrderedSame);
  }
  return ok;
}
//end endsWith:options:

-(const char*) cStringUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(BOOL)flag
{
  NSMutableData* data = [NSMutableData dataWithData:[self dataUsingEncoding:encoding allowLossyConversion:flag]];
  const unichar zero = 0;
  [data appendBytes:&zero length:sizeof(zero)];
  return [data bytes];
}
//end cStringUsingEncoding:allowLossyConversion:

-(NSString*) filteredStringForLatex
{
  unichar softbreak = 0x2028;
  NSString* softbreakString = [NSString stringWithCharacters:&softbreak length:1];
  unichar unbreakableSpace = 0x00A0;
  NSString* unbreakableSpaceString = [NSString stringWithCharacters:&unbreakableSpace length:1];
  NSMutableString* string = [NSMutableString stringWithString:self];
  [string replaceOccurrencesOfString:softbreakString withString:@"\n" options:0 range:string.range];
  [string replaceOccurrencesOfString:unbreakableSpaceString withString:@" " options:0 range:string.range];
  return string;
}
//end filteredStringForLatex

//in Japanese environment, we should replace the Yen symbol by a backslash
//You can read http://www.xs4all.nl/~msneep/articles/japanese.html to know more about that problem
-(NSString*) replaceYenSymbol
{
  NSMutableString* stringWithBackslash = [NSMutableString stringWithString:self];
  static NSString* yenString = nil;
  if (!yenString)
  {
    unichar yenChar = 0x00a5;
    yenString = [[NSString alloc] initWithCharacters:&yenChar length:1]; //the yen symbol as a string
  }
  [stringWithBackslash replaceOccurrencesOfRegex:[NSString stringWithFormat:@"%@([[:space:]]+)", yenString]
                                      withString:@"\\\\yen{}$1" options:RKLCaseless|RKLMultiline
                                           range:stringWithBackslash.range error:nil];
  [stringWithBackslash replaceOccurrencesOfRegex:[NSString stringWithFormat:@"%@%@", yenString, yenString]
                                      withString:@"\\\\\\\\" options:RKLCaseless|RKLMultiline
                                           range:stringWithBackslash.range error:nil];
  [stringWithBackslash replaceOccurrencesOfRegex:[NSString stringWithFormat:@"%@([^[[:space:]]0-9])", yenString]
                                      withString:@"\\\\$1" options:RKLCaseless|RKLMultiline
                                           range:stringWithBackslash.range error:nil];
  [stringWithBackslash replaceOccurrencesOfRegex:yenString
                                      withString:@"\\\\yen{}" options:RKLCaseless|RKLMultiline
                                           range:stringWithBackslash.range error:nil];
  #ifdef ARC_ENABLED
  return [stringWithBackslash copy];
  #else
  return [[stringWithBackslash copy] autorelease];
  #endif
}
//end replaceYenSymbol

@end

#if defined(USE_REGEXKITLITE) && USE_REGEXKITLITE
#else

NSRegularExpressionOptions convertRKLOptions(RKLRegexOptions options)
{
  NSRegularExpressionOptions result = 0;
  if ((options & RKLCaseless) != 0)
    result |= NSRegularExpressionCaseInsensitive;
  if ((options & RKLComments) != 0)
    result |= NSRegularExpressionAllowCommentsAndWhitespace;
  if ((options & RKLDotAll) != 0)
    result |= NSRegularExpressionDotMatchesLineSeparators;
  if ((options & RKLMultiline) != 0)
    result |= NSRegularExpressionAnchorsMatchLines;
  if ((options & RKLUnicodeWordBoundaries) != 0)
    result |= NSRegularExpressionUseUnicodeWordBoundaries;
  return result;
}
//end convertRKLOptions()

@implementation NSString (RegexKitLiteExtension)

-(BOOL) isMatchedByRegex:(NSString*)pattern
{
  BOOL result = [self isMatchedByRegex:pattern options:0 inRange:self.range error:nil];
  return result;
}
//end isMatchedByRegex:

-(BOOL) isMatchedByRegex:(NSString*)pattern options:(RKLRegexOptions)options inRange:(NSRange)range error:(NSError**)error
{
  BOOL result = false;
  NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:convertRKLOptions(options) error:error];
  result = ([regex numberOfMatchesInString:self options:0 range:range] > 0);
  return result;
}
//end isMatchedByRegex:options:inRange:error:

-(NSRange) rangeOfRegex:(NSString*)pattern options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError**)error
{
  NSRange result = NSMakeRange(0, 0);
  NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:convertRKLOptions(options) error:error];
  NSTextCheckingResult* match = [regex firstMatchInString:self options:0 range:range];
  result = [match rangeAtIndex:capture];
  return result;
}
//end rangeOfRegex::options:inRange:capture:error:

-(NSString*) stringByReplacingOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement
{
  NSString* result = [self stringByReplacingOccurrencesOfRegex:pattern withString:replacement options:0 range:self.range error:nil];
  return result;
}
//end stringByReplacingOccurrencesOfRegex::withgString:

-(NSString*) stringByReplacingOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement options:(RKLRegexOptions)options range:(NSRange)searchRange error:(NSError**)error
{
  NSString* result = self;
  NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:convertRKLOptions(options) error:error];
  result = [regex stringByReplacingMatchesInString:self options:0 range:searchRange withTemplate:replacement];
  return result;
}
//end stringByReplacingOccurrencesOfRegex:withString:options:range:error:

-(NSString*) stringByMatching:(NSString*)pattern options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError**)error
{
  NSString* result = self;
  NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:convertRKLOptions(options) error:nil];
  NSTextCheckingResult* match = [regex firstMatchInString:self options:0 range:range];
  NSRange matchRange = [match rangeAtIndex:capture];
  result = (matchRange.location == NSNotFound) || !matchRange.length ? nil : [self substringWithRange:matchRange];
  return result;
}
//end stringByMatching:options:inRange:capture:

-(NSArray*) componentsMatchedByRegex:(NSString*)pattern
{
  NSArray* result = [self componentsMatchedByRegex:pattern options:0 range:self.range capture:0 error:nil];
  return result;
}
//end componentsMatchedByRegex

-(NSArray*) componentsMatchedByRegex:(NSString*)pattern options:(RKLRegexOptions)options range:(NSRange)searchRange capture:(NSInteger)capture error:(NSError**)error
{
  NSMutableArray* result = nil;
  NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:convertRKLOptions(options) error:error];
  NSArray* matches = [regex matchesInString:self options:0 range:searchRange];
  result = [NSMutableArray arrayWithCapacity:matches.count];
  for(NSUInteger i = 0, count = matches.count ; i<count ; ++i)
  {
    NSTextCheckingResult* match = [[matches objectAtIndex:i] dynamicCastToClass:[NSTextCheckingResult class]];
    NSRange matchRange = [match rangeAtIndex:capture];
    NSString* component = (matchRange.location == NSNotFound) || !matchRange.length ? @"" : [self substringWithRange:matchRange];
    if (component != nil)
      [result addObject:component];
  }//end for each match
  return [[result copy] autorelease];
}
//end componentsMatchedByRegex:options:range:capture:error:

-(NSArray*) captureComponentsMatchedByRegex:(NSString*)pattern options:(RKLRegexOptions)options range:(NSRange)range error:(NSError**)error
{
  NSMutableArray* result = nil;
  NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:convertRKLOptions(options) error:error];
  NSTextCheckingResult* match = [regex firstMatchInString:self options:0 range:range];
  result = [NSMutableArray arrayWithCapacity:match.numberOfRanges];
  for(NSUInteger i = 0, count = match.numberOfRanges ; i<count ; ++i)
  {
    NSRange matchRange = [match rangeAtIndex:i];
    NSString* captureComponent = (matchRange.location == NSNotFound) || !matchRange.length ? @"" : [self substringWithRange:matchRange];
    if (captureComponent != nil)
      [result addObject:captureComponent];
  }//end for each match
  return [[result copy] autorelease];
}
//end componentsMatchedByRegex:options:range:error:

@end

@implementation NSMutableString (RegexKitLiteExtension)

-(NSInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement
{
  NSInteger result = [self replaceOccurrencesOfRegex:pattern withString:replacement options:0 range:self.range error:nil];
  return result;
}
//end replaceOccurrencesOfRegex:withString:options:range:error:

-(NSInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement options:(RKLRegexOptions)options range:(NSRange)searchRange error:(NSError **)error
{
  NSInteger result = 0;
  NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:pattern options:convertRKLOptions(options) error:error];
  [self setString:[regex stringByReplacingMatchesInString:self options:0 range:self.range withTemplate:replacement]];
  return result;
}
//end replaceOccurrencesOfRegex:withString:options:range:error:

@end

#endif

