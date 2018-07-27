//
//  NSDataExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/11/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "NSDataExtended.h"

#import "Utils.h"

#import </Developer/SDKs/MacOSX10.5.sdk/usr/include/openssl/bio.h>//specific to avoid compatibility problem prior MacOS 10.5
#import </Developer/SDKs/MacOSX10.5.sdk/usr/include/openssl/ssl.h>//specific to avoid compatibility problem prior MacOS 10.5
#import </Developer/SDKs/MacOSX10.5.sdk/usr/include/openssl/sha.h>//specific to avoid compatibility problem prior MacOS 10.5

@implementation NSData (Extended)

+(id) dataWithBase64:(NSString*)base64
{
  return [self dataWithBase64:base64 encodedWithNewlines:YES];
}
//end initWithBase64:

+(id) dataWithBase64:(NSString*)base64 encodedWithNewlines:(BOOL)encodedWithNewlines
{
  NSMutableData* result = [NSMutableData data];

  BIO* mem = BIO_new_mem_buf((void*)[base64 UTF8String], [base64 lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
  BIO* b64 = BIO_new(BIO_f_base64());
  if (!encodedWithNewlines)
    BIO_set_flags(b64, BIO_FLAGS_BASE64_NO_NL);
  mem = BIO_push(b64, mem);
   
  // Decode into an NSMutableData
  char inbuf[512] = {0};
  int inlen = 0;
  while ((inlen = BIO_read(mem, inbuf, sizeof(inbuf))) > 0)
    [result appendBytes:inbuf length:inlen];
    
  //Clean up and go home
  BIO_free_all(mem);
  
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
  result = [[[NSString alloc] initWithBytes:base64Pointer length:base64Length encoding:NSUTF8StringEncoding] autorelease];
  BIO_free_all(mem);
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
  [wrapper release];
  return result;
}
//end sha1Base64

@end
