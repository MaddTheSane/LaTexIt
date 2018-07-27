//
//  BridgeNSFileManager.h
//  Bridge10_5
//
//  Created by Pierre Chatelier on 23/08/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Bridge10_5.h"

@interface Bridge (NSFileManager)
+(void) loadNSFileManager;
-(BOOL) createSymbolicLinkAtPath:(NSString*)path withDestinationPath:(NSString*)destPath error:(NSError**)error;
-(NSArray*) contentsOfDirectoryAtPath:(NSString *)path error:(NSError**)error;
@end

@interface NSFileManager (Bridge)
-(BOOL) createSymbolicLinkAtPath:(NSString*)path withDestinationPath:(NSString*)destPath error:(NSError**)error;
-(NSString*) destinationOfSymbolicLinkAtPath:(NSString*)path error:(NSError**)error;
-(NSArray*) contentsOfDirectoryAtPath:(NSString *)path error:(NSError**)error;
@end
