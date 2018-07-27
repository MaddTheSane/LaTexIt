//
//  NSStringExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.

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

@end
