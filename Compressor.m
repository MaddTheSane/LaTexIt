//  Compressor.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 17/02/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.

//This file is useful to zip-[un]compress NSData

#import "Compressor.h"
#import <zlib.h>

#import "Utils.h"

@implementation Compressor

// compress the data of an NSData object.
// Needs a buffer 0.1% + 12 bytes larger than the source file.
// Encodes the original size of the data as the first 4 bytes.
+(NSData*) zipcompressDeprecated:(NSData*)data
{
  NSData* result = nil;
  if (data)
  {
    uLong srcLength = [data length];
    uLongf buffLength = srcLength * 1.001 + 12;
    NSMutableData* compData = [[NSMutableData alloc] initWithCapacity:buffLength+sizeof(uLong)];
    uLong swappedSrclength = CFSwapInt32HostToBig(srcLength);
    [compData appendBytes:&swappedSrclength length:sizeof(uLong)];
    [compData increaseLengthBy:buffLength];
    int error=compress([compData mutableBytes]+sizeof(uLong),&buffLength,[data bytes],srcLength);
    switch(error)
    {
      case Z_OK:
        [compData setLength:buffLength+sizeof(uLong)];
        result = [compData copy];
        break;
      default:
        NSCAssert( YES, @"Error while compressing data: Insufficient memory" );
        break;
    }//end switch(error)
    #ifdef ARC_ENABLED
    #else
    [compData release];
    #endif
  }//end if (data)
  #ifdef ARC_ENABLED
  #else
  [result autorelease];
  #endif
  return result;
}
//end zipcompressDeprecated:

// compress the data of an NSData object.
// Encodes the original size of the data as the first 4 bytes.
+(NSData*) zipcompress:(NSData*)data
{
  return [self zipcompress:data level:-1];
}
//end zipcompress:

+(NSData*) zipcompress:(NSData*)data level:(int)level
{
  NSData* result = nil;
  if (data)
  {
    uLongf sourceLen = [data length];
    uLongf destLen   = compressBound(sourceLen);
    NSMutableData* compData = [[NSMutableData alloc] initWithCapacity:sizeof(unsigned int)+destLen];
    unsigned int bigSourceLen = EndianUI_NtoB((unsigned int)sourceLen);
    [compData appendBytes:&bigSourceLen length:sizeof(unsigned int)];
    [compData increaseLengthBy:destLen];
    int error = compress2([compData mutableBytes]+sizeof(unsigned int), &destLen, [data bytes], sourceLen, level);
    switch(error)
    {
      case Z_OK:
        [compData setLength:sizeof(unsigned int)+destLen];
        result = [compData copy];
        break;
      default:
        DebugLog(0, @"Error while compressing data");
        break;
    }//end switch(error)
    #ifdef ARC_ENABLED
    #else
    [compData release];
    #endif
  }//end if (data)
  #ifdef ARC_ENABLED
  #else
  [result autorelease];
  #endif
  return result;
}
//end zipcompress:level:

// decompress into a buffer the size in the first 4 bytes of the object (see above).
+(NSData*) zipuncompressDeprecated:(NSData*)data
{
  NSData *result = nil;
  if (data)
  {
    //I made a mistake = getBytes and appendBytes do not behave the same on MacIntels.
    //I must make ugly code to read data that is not know to be from PPC or x86
    uLongf unswappedDestLen = 0;
    [data getBytes:&unswappedDestLen length:sizeof(uLong)];
    unswappedDestLen = CFSwapInt32BigToHost((uint32_t)unswappedDestLen);
    
    uLongf swappedDestLen = CFSwapInt32((uint32_t)unswappedDestLen);
    uLongf destLen = MIN(swappedDestLen, unswappedDestLen);
    NSMutableData* decompData = [[NSMutableData alloc] initWithLength:destLen];
    int error = uncompress( [decompData mutableBytes], &destLen,
                            [data bytes]+sizeof(uLong), [data length]-sizeof(uLong) );
    switch(error)
    {
      case Z_OK:
        result = [decompData copy];
        break;
      case Z_DATA_ERROR:
        DebugLog(0, @"Error while decompressing data : data seems corrupted");
        break;
      default:
        DebugLog(0, @"Error while decompressing data : Insufficient memory" );
        break;
    }//end switch(error)
    if (error != Z_OK)
    {
      #ifdef ARC_ENABLED
      #else
      [decompData release];
      #endif
      destLen = MAX(swappedDestLen, unswappedDestLen);
      void* test = malloc(destLen);
      BOOL ok = (test != 0);
      if (test)
        free(test);
      decompData = ok ? [[NSMutableData alloc] initWithLength:destLen] : nil;
      error = !decompData ? -1 : uncompress( [decompData mutableBytes], &destLen,
                                             [data bytes]+sizeof(uLong), [data length]-sizeof(uLong) );
      switch(error)
      {
        case Z_OK:
          result = [decompData copy];
          break;
        case Z_DATA_ERROR:
          DebugLog(0, @"Error while decompressing data : data seems corrupted");
          break;
        default:
          DebugLog(0, @"Error while decompressing data : Insufficient memory" );
          break;
      }//end switch(error)
    }//end if (error != Z_OK)
    #ifdef ARC_ENABLED
    #else
    [decompData release];
    #endif
  }//end if (data)
  #ifdef ARC_ENABLED
  #else
  [result autorelease];
  #endif
  return result;
}
//end zipuncompressDeprecated:

// decompress into a buffer the size in the first 4 bytes of the object (see above).
+(NSData*) zipuncompress:(NSData*)data
{
  NSData* result = nil;
  if (data)
  {
    unsigned int bigDestLen = 0;
    [data getBytes:&bigDestLen length:sizeof(unsigned int)];
    unsigned int destLen = EndianUI_BtoN(bigDestLen);
    uLongf destLenf = destLen;
    NSMutableData* decompData = [[NSMutableData alloc] initWithLength:destLen];
    int error = uncompress([decompData mutableBytes], &destLenf,
                           [data bytes]+sizeof(unsigned int), [data length]-sizeof(unsigned int));
    switch(error)
    {
      case Z_OK:
        result = [decompData copy];
        break;
      case Z_DATA_ERROR:
        DebugLog(0, @"Error while decompressing data : data seems corrupted");
        break;
      default:
        DebugLog(0, @"Error while decompressing data : Insufficient memory" );
        break;
    }//end switch(error)
    #ifdef ARC_ENABLED
    #else
    [decompData release];
    #endif
  }//end if (data)
  #ifdef ARC_ENABLED
  #else
  [result autorelease];
  #endif
  return result;
}
//end zipuncompress:

@end
