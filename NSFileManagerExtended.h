//
//  NSFileManagerExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/03/08.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSFileManager (Extended)

-(NSString*) localizedPath:(NSString*)path;
-(NSFileHandle*) temporaryFileWithTemplate:(NSString*)templateString extension:(NSString*)extension outFilePath:(NSString**)outFilePath workingDirectory:(NSString*)workingDirectory;
-(BOOL) createLinkInDirectory:(NSString*)directoryPath toTarget:(NSString*)targetPath linkName:(NSString*)linkName outLinkPath:(NSString**)outLinkPath;

-(void) registerTemporaryPath:(NSString*)path;
-(void) removeAllCreatedTemporaryPaths;

-(NSString*) UTIFromPath:(NSString*)path /* __OSX_AVAILABLE_BUT_DEPRECATED_MSG(__MAC_10_4, __MAC_10_10, __IPHONE_NA, __IPHONE_NA, "Use the URL resource property kCFURLTypeIdentifierKey or NSURLTypeIdentifierKey instead.") */ ;
-(NSString*) UTIFromURL:(NSURL*)url /* __OSX_AVAILABLE_BUT_DEPRECATED_MSG(__MAC_10_4, __MAC_10_10, __IPHONE_NA, __IPHONE_NA, "Use the URL resource property kCFURLTypeIdentifierKey or NSURLTypeIdentifierKey instead.") */ ;
    
@end

@interface NSFileManager (Bridge10_5)
-(BOOL)      bridge_createSymbolicLinkAtPath:(NSString*)path withDestinationPath:(NSString*)destPath error:(NSError**)error;
-(NSString*) bridge_destinationOfSymbolicLinkAtPath:(NSString*)path error:(NSError**)error;
-(BOOL)      bridge_createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary *)attributes error:(NSError **)error;
-(NSArray*)  bridge_contentsOfDirectoryAtPath:(NSString *)path error:(NSError**)error;
-(BOOL)      bridge_copyItemAtPath:(NSString*)srcPath toPath:(NSString*)dstPath error:(NSError**)error;
-(BOOL)      bridge_removeItemAtPath:(NSString*)path error:(NSError**)error;
-(BOOL)      bridge_moveItemAtPath:(NSString*)srcPath toPath:(NSString*)dstPath error:(NSError**)error;
-(NSDictionary *) bridge_attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error;
-(NSDictionary *) bridge_attributesOfItemAtPath:(NSString *)path error:(NSError **)error;
-(BOOL)      bridge_setAttributes:(NSDictionary *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error;
@end

