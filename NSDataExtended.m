//
//  NSDataExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/11/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSDataExtended.h"

#import "Utils.h"
#include <CommonCrypto/CommonDigest.h>

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
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
  result = [[self alloc] initWithBase64EncodedString:base64 options:0];
  
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
  result = [self base64EncodedStringWithOptions:0];
  return result;
}
//end encodeBase64WithNewlines:

-(NSString*) sha1Base64
{
  NSString* result = nil;
  unsigned char sha[CC_SHA1_DIGEST_LENGTH] = {0};
  CC_SHA1([self bytes], (CC_LONG)[self length], sha);
  NSData* wrapper = [[NSData alloc] initWithBytesNoCopy:sha length:CC_SHA1_DIGEST_LENGTH freeWhenDone:NO];
  result = [wrapper encodeBase64WithNewlines:NO];
  return result;
}
//end sha1Base64

@end
