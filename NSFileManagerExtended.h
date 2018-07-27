//
//  NSFileManagerExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/03/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSFileManager (Extended)

-(BOOL) createDirectoryPath:(NSString*)path attributes:(NSDictionary*)attributes;
-(NSString*) localizedPath:(NSString*)path;
-(NSFileHandle*) temporaryFileWithTemplate:(NSString*)templateString extension:(NSString*)extension outFilePath:(NSString**)outFilePath workingDirectory:(NSString*)workingDirectory;
-(BOOL) createLinkInDirectory:(NSString*)directoryPath toTarget:(NSString*)targetPath linkName:(NSString*)linkName outLinkPath:(NSString**)outLinkPath;

-(void) removeAllCreatedTemporaryPaths;
    
@end

@interface NSFileManager (Bridge10_5)
-(BOOL) bridge_createSymbolicLinkAtPath:(NSString*)path withDestinationPath:(NSString*)destPath error:(NSError**)error;
-(NSString*) bridge_destinationOfSymbolicLinkAtPath:(NSString*)path error:(NSError**)error;
-(NSArray*) bridge_contentsOfDirectoryAtPath:(NSString *)path error:(NSError**)error;
@end

