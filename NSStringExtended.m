//
//  NSStringExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/05.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSWorkspace class

#import "NSStringExtended.h"

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
    [string autorelease];
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
    [string autorelease];
  }
  return string;
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

-(BOOL) startsWith:(NSString*)substring options:(unsigned)mask
{
  BOOL ok = NO;
  unsigned int selfLength = [self length];
  unsigned int subLength = [substring length];
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
  unsigned int selfLength = [self length];
  unsigned int subLength = [substring length];
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
  static NSString* yenString = nil;
  if (!yenString)
  {
    unichar yenChar = 0x00a5;
    yenString = [[NSString alloc] initWithCharacters:&yenChar length:1]; //the yen symbol as a string
  }
  [stringWithBackslash replaceOccurrencesOfString:yenString withString:@"\\"
                                          options:NSLiteralSearch range:NSMakeRange(0, [stringWithBackslash length])];
  return stringWithBackslash;
}
//end replaceYenSymbol

@end
