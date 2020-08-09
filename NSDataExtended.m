//
//  NSDataExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/11/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "NSDataExtended.h"

#import "Utils.h"
#include <CommonCrypto/CommonDigest.h>

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif
#define OPENSSL_AVAILABLE 0

#ifdef ARC_ENABLED
#if OPENSSL_AVAILABLE
#import <openssl/bio.h>
#import <openssl/ssl.h>
#import <openssl/sha.h>
#endif
#elif defined(__clang__)
#if OPENSSL_AVAILABLE
#import <openssl/bio.h>
#import <openssl/ssl.h>
#import <openssl/sha.h>
#endif
#include <CommonCrypto/CommonDigest.h>
#else
#import </Developer/SDKs/MacOSX10.5.sdk/usr/include/openssl/bio.h>//specific to avoid compatibility problem prior MacOS 10.5
#import </Developer/SDKs/MacOSX10.5.sdk/usr/include/openssl/ssl.h>//specific to avoid compatibility problem prior MacOS 10.5
#import </Developer/SDKs/MacOSX10.5.sdk/usr/include/openssl/sha.h>//specific to avoid compatibility problem prior MacOS 10.5
#endif

@implementation NSData (Extended)

+(instancetype) dataWithBase64:(NSString*)base64
{
  return [self dataWithBase64:base64 encodedWithNewlines:YES];
}
//end initWithBase64:

+(instancetype) dataWithBase64:(NSString*)base64 encodedWithNewlines:(BOOL)encodedWithNewlines
{
  id result = [[self alloc] initWithBase64EncodedString:base64 options:0];
  
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
  #if OPENSSL_AVAILABLE
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
  #else
  if ([self respondsToSelector:@selector(base64EncodedStringWithOptions:)])
   result = [self base64EncodedStringWithOptions:(encodeWithNewlines ? (NSDataBase64Encoding64CharacterLineLength|NSDataBase64EncodingEndLineWithLineFeed) : 0)];
  #endif
  return result;
}
//end encodeBase64WithNewlines:

-(NSString*) sha1Base64
{
  NSString* result = nil;
  #if OPENSSL_AVAILABLE
  unsigned char sha[SHA_DIGEST_LENGTH] = {0};
  SHA1([self bytes], [self length], sha);
  NSData* wrapper = [[NSData alloc] initWithBytesNoCopy:sha length:SHA_DIGEST_LENGTH freeWhenDone:NO];
  result = [wrapper encodeBase64WithNewlines:NO];
  #ifdef ARC_ENABLED
  #else
  [wrapper release];
  #endif
  #else
  unsigned char digest[CC_SHA1_DIGEST_LENGTH] = {0};
  if (CC_SHA1([self bytes], (int)[self length], digest))
  {
    NSData* wrapper = [[NSData alloc] initWithBytesNoCopy:digest length:CC_SHA1_DIGEST_LENGTH freeWhenDone:NO];
    result = [wrapper encodeBase64WithNewlines:NO];
    #ifdef ARC_ENABLED
    #else
    [wrapper release];
    #endif
  }//end if (CC_SHA1([self bytes], [self length], digest))
  #endif
  return result;
}
//end sha1Base64

@end
