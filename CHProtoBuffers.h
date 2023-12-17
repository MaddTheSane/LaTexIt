//
//  CHProtoBuffers.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 11/11/13.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define USE_PROTOBUFFERS 0

@interface CHProtoBuffers : NSObject

+(void) parseData:(NSData*)data outPdfFileName:(NSString**)outPdfFileName outUUID:(NSString**)outUUID;

@end
