//
//  NSStringExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSWorkspace class

#import "NSStringExtended.h"

@implementation NSString (Extended)

//a similar method exists on Tiger, but does not work as I expect; this is a wrapper plus some additions
+(id) stringWithContentsOfFile:(NSString *)path guessEncoding:(NSStringEncoding *)enc error:(NSError **)error;
{
  NSString* string = nil;
  #ifndef PANTHER
  string = [NSString stringWithContentsOfFile:path usedEncoding:enc error:error];
  #endif
  if (!string)
  {
    if (error)
      *error = nil;
    NSStringEncoding usedEncoding = NSUTF8StringEncoding;
    NSData* data = [NSData dataWithContentsOfFile:path];
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

-(const char*) cStringUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(BOOL)flag
{
  NSMutableData* data = [NSMutableData dataWithData:[self dataUsingEncoding:encoding allowLossyConversion:flag]];
  const unichar zero = 0;
  [data appendBytes:&zero length:sizeof(zero)];
  return [data bytes];
}

@end
