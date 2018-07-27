//  Compressor.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 17/02/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This file is useful to zip-[un]compress NSData

#import "Compressor.h"
#import <zlib.h>

@implementation Compressor

// compress the data of an NSData object.
// Needs a buffer 0.1% + 12 bytes larger than the source file.
// Encodes the original size of the data as the first 4 bytes.
+(NSData*) zipcompress:(NSData*)data
{
  NSData *result = nil;
  if( data )
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
    }
    [compData release];
  }
  return [result autorelease];
}

// decompress into a buffer the size in the first 4 bytes of the object (see above).
+(NSData*) zipuncompress:(NSData*)data
{
  NSData *result = nil;
  if (data)
  {
    //I made a mistake = getBytes and appendBytes do not behave the same on MacIntels.
    //I must make ugly code to read data that is not know to be from PPC or x86
    uLongf unswappedDestLen = 0;
    [data getBytes:&unswappedDestLen length:sizeof(uLong)];
    unswappedDestLen = CFSwapInt32BigToHost(unswappedDestLen);
    
    uLongf swappedDestLen = CFSwapInt32(unswappedDestLen);
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
        NSLog(@"Error while decompressing data : data seems corrupted");
        break;
      default:
        NSLog(@"Error while decompressing data : Insufficient memory" );
        break;
    }
    if (error != Z_OK)
    {
      [decompData release];
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
          NSLog(@"Error while decompressing data : data seems corrupted");
          break;
        default:
          NSLog(@"Error while decompressing data : Insufficient memory" );
          break;
      }
    }
    [decompData release];
  }
  return [result autorelease];
}

@end
