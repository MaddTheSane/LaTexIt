//
//  NSDataExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/11/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSDataExtended.h"

#import "Utils.h"

#ifdef ARC_ENABLED
#import <openssl/bio.h>
#import <openssl/ssl.h>
#import <openssl/sha.h>
#elif defined(__clang__)
#import <openssl/bio.h>
#import <openssl/ssl.h>
#import <openssl/sha.h>
#else
#import </Developer/SDKs/MacOSX10.5.sdk/usr/include/openssl/bio.h>//specific to avoid compatibility problem prior MacOS 10.5
#import </Developer/SDKs/MacOSX10.5.sdk/usr/include/openssl/ssl.h>//specific to avoid compatibility problem prior MacOS 10.5
#import </Developer/SDKs/MacOSX10.5.sdk/usr/include/openssl/sha.h>//specific to avoid compatibility problem prior MacOS 10.5
#endif

@implementation NSData (Extended)

+(id) dataWithBase64:(NSString*)base64
{
  return [self dataWithBase64:base64 encodedWithNewlines:YES];
}
//end initWithBase64:

+(id) dataWithBase64:(NSString*)base64 encodedWithNewlines:(BOOL)encodedWithNewlines
{
  NSMutableData* result = [NSMutableData data];
  #if defined(__clang__)
  #else
  const char* utf8String = [base64 UTF8String];
  NSUInteger utf8Length = [base64 lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
  BIO* mem = BIO_new_mem_buf((void*)utf8String, utf8Length);
  BIO* b64 = BIO_new(BIO_f_base64());
  if (!encodedWithNewlines)
    BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
  BIO_push(b64, mem);

  // Decode into an NSMutableData
  char inbuf[512] = {0};
  int inlen = 0;
  while ((inlen = BIO_read(b64, inbuf, MIN(utf8Length, sizeof(inbuf)))) > 0)
    [result appendBytes:inbuf length:inlen];
    
  //Clean up and go home
  BIO_free_all(b64);
  #endif
  
  return result;
}
//end dataWithBase64:encodedWithNewlines:

-(NSString*) encodeBase64
{
  NSString* result = [self encodeBase64WithNewlines:YES];
  return result;
}
//end encodeBase64

-(NSString*) encodeBase64WithNewlines:(BOOL)encodeWithNewlines
{
  NSString* result = nil;
  #if defined(__clang__)
  #else
  BIO* mem = BIO_new(BIO_s_mem());
  BIO* b64 = BIO_new(BIO_f_base64());
  if (!encodeWithNewlines)
    BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
  mem = BIO_push(b64, mem);
  BIO_write(mem, [self bytes], [self length]);
  int error = BIO_flush(mem);
  if (error != 1)
    DebugLog(0, @"BIO_flush : %d", error);
  char* base64Pointer = 0;
  long base64Length = BIO_get_mem_data(mem, &base64Pointer);
  #ifdef ARC_ENABLED
  result = [[NSString alloc] initWithBytes:base64Pointer length:base64Length encoding:NSUTF8StringEncoding];
  #else
  result = [[[NSString alloc] initWithBytes:base64Pointer length:base64Length encoding:NSUTF8StringEncoding] autorelease];
  #endif
  BIO_free_all(mem);
  #endif
  return result;
}
//end encodeBase64WithNewlines:

-(NSString*) sha1Base64
{
  NSString* result = nil;
  unsigned char sha[SHA_DIGEST_LENGTH] = {0};
  SHA1([self bytes], [self length], sha);
  NSData* wrapper = [[NSData alloc] initWithBytesNoCopy:sha length:SHA_DIGEST_LENGTH freeWhenDone:NO];
  result = [wrapper encodeBase64WithNewlines:NO];
  #ifdef ARC_ENABLED
  #else
  [wrapper release];
  #endif
  return result;
}
//end sha1Base64

-(NSRange) bridge_rangeOfData:(NSData*)dataToFind options:(NSDataSearchOptions)mask range:(NSRange)searchRange
{
  NSRange result = NSMakeRange(NSNotFound, 0);
  if (isMacOS10_6OrAbove())
    result = [self rangeOfData:dataToFind options:mask range:searchRange];
  else if (searchRange.length && dataToFind)
  {
    NSUInteger stackLength = [self length];
    NSUInteger needleLength = [dataToFind length];
    if ((searchRange.location+searchRange.length <= stackLength) && (needleLength <= searchRange.length))
    {
      const unsigned char* haystackBegin = [self bytes]+searchRange.location;
      const unsigned char* haystackEnd = haystackBegin+searchRange.length;
      const unsigned char* needleBegin = [dataToFind bytes];
      if (mask & NSDataSearchAnchored)
      {
        if (mask & NSDataSearchBackwards)
        {
          if (!memcmp(haystackEnd-needleLength, needleBegin, needleLength))
            result = NSMakeRange(searchRange.location+searchRange.length-needleLength, needleLength);
        }//end if (mask & NSDataSearchBackwards)
        else//if (!(mask & NSDataSearchBackwards))
        {
          if (!memcmp(haystackBegin, needleBegin, needleLength))
            result = NSMakeRange(searchRange.location, needleLength);
        }//end if (!(mask & NSDataSearchBackwards))
      }//end if (mask & NSDataSearchAnchored)
      else if (mask & NSDataSearchBackwards)
      {
        const unsigned char* test = haystackEnd-needleLength;
        BOOL found = NO;
        while(!found && (test >= haystackBegin))
        {
          found = !memcmp(test, needleBegin, needleLength);
          if (!found)
            --test;
        }//end while(!found && (test >= stackBegin))
        if (found)
          result = NSMakeRange(searchRange.location+(test-haystackBegin), needleLength);
      }//end if (mask & NSDataSearchBackwards)
      else
      {
        const unsigned char* test = haystackBegin;
        BOOL found = NO;
        while(!found && (test <= haystackEnd-needleLength))
        {
          found = !memcmp(test, needleBegin, needleLength);
          if (!found)
            ++test;
        }//end while(!found && (test >= stackBegin))
        if (found)
          result = NSMakeRange(searchRange.location+(test-haystackBegin), needleLength);
      }
    }//end if ((searchRange.location+searchRange.length <= stackLength) && (needleLength <= searchRange.length))
  }//end if (searchRange.length && dataToFind && ([dataToFind length]<= [self length]))

  return result;
}
//end bridge_rangeOfData:options:range:

@end
