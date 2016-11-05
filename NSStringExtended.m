//
//  NSStringExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSWorkspace class

#import "NSStringExtended.h"

#import "RegexKitLite.h"
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
  return [[self alloc] initWithString:string];
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
  return [[self alloc] initWithString:string];
}
//end stringWithContentsOfURL:guessEncoding:error:

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

-(BOOL) startsWith:(NSString*)substring options:(NSStringCompareOptions)mask
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

-(BOOL) endsWith:(NSString*)substring options:(NSStringCompareOptions)mask
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
  NSString* softbreakString = @"\u2028";
  NSString* unbreakableSpaceString = @"\u00A0";
  NSMutableString* string = [NSMutableString stringWithString:self];
  [string replaceOccurrencesOfString:softbreakString withString:@"\n" options:0 range:NSMakeRange(0, [string length])];
  [string replaceOccurrencesOfString:unbreakableSpaceString withString:@" " options:0 range:NSMakeRange(0, [string length])];
  return string;
}
//end filteredStringForLatex

//in Japanese environment, we should replace the Yen symbol by a backslash
//You can read http://www.xs4all.nl/~msneep/articles/japanese.html to know more about that problem
-(NSString*) replaceYenSymbol
{
  NSMutableString* stringWithBackslash = [NSMutableString stringWithString:self];
  [stringWithBackslash replaceOccurrencesOfRegex:@"¥([[:space:]]+)"
                                      withString:@"\\\\yen{}$1" options:RKLCaseless|RKLMultiline
                                           range:NSMakeRange(0, [stringWithBackslash length]) error:nil];
  [stringWithBackslash replaceOccurrencesOfRegex:@"¥¥"
                                      withString:@"\\\\\\\\" options:RKLCaseless|RKLMultiline
                                           range:NSMakeRange(0, [stringWithBackslash length]) error:nil];
  [stringWithBackslash replaceOccurrencesOfRegex:@"¥([^[[:space:]]0-9])"
                                      withString:@"\\\\$1" options:RKLCaseless|RKLMultiline
                                           range:NSMakeRange(0, [stringWithBackslash length]) error:nil];
  [stringWithBackslash replaceOccurrencesOfRegex:@"¥"
                                      withString:@"\\\\yen{}" options:RKLCaseless|RKLMultiline
                                           range:NSMakeRange(0, [stringWithBackslash length]) error:nil];
#ifdef ARC_ENABLED
  return [stringWithBackslash copy];
#else
	return [[stringWithBackslash copy] autorelease];
#endif
}
//end replaceYenSymbol

@end
