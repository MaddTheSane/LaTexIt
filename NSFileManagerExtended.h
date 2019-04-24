//
//  NSFileManagerExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/03/08.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSFileManager (Extended)

-(NSString*) localizedPath:(NSString*)path;
-(NSFileHandle*) temporaryFileWithTemplate:(NSString*)templateString extension:(NSString*)extension outFilePath:(NSString**)outFilePath workingDirectory:(NSString*)workingDirectory;
-(BOOL) createLinkInDirectory:(NSString*)directoryPath toTarget:(NSString*)targetPath linkName:(NSString*)linkName outLinkPath:(NSString**)outLinkPath;

-(void) registerTemporaryPath:(NSString*)path;
-(void) unregisterTemporaryPath:(NSString*)path;
-(void) removeAllCreatedTemporaryPaths;

-(NSString*) UTIFromPath:(NSString*)path /* __OSX_AVAILABLE_BUT_DEPRECATED_MSG(__MAC_10_4, __MAC_10_10, __IPHONE_NA, __IPHONE_NA, "Use the URL resource property kCFURLTypeIdentifierKey or NSURLTypeIdentifierKey instead.") */ ;
-(NSString*) UTIFromURL:(NSURL*)url /* __OSX_AVAILABLE_BUT_DEPRECATED_MSG(__MAC_10_4, __MAC_10_10, __IPHONE_NA, __IPHONE_NA, "Use the URL resource property kCFURLTypeIdentifierKey or NSURLTypeIdentifierKey instead.") */ ;

-(NSString*) getUnusedFilePathFromPrefix:(NSString*)filePrefix extension:(NSString*)extension folder:(NSString*)folder startSuffix:(NSUInteger)startSuffix;

@end

