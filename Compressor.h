//  Compressor.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 17/02/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//This file is useful to zip-[un]compress NSData

#import <Cocoa/Cocoa.h>

@interface Compressor : NSObject {
}

+(NSData*) zipcompressDeprecated:(NSData*)data;
+(NSData*) zipuncompressDeprecated:(NSData*)data;
+(NSData*) zipcompress:(NSData*)data;
+(NSData*) zipuncompress:(NSData*)data;

@end
