//
//  NSFileManagerExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/03/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <Bridge10_5/Bridge10_5.h>

@interface NSFileManager (Extended)

-(BOOL) createDirectoryPath:(NSString*)path attributes:(NSDictionary*)attributes;
-(NSString*) localizedPath:(NSString*)path;
-(NSFileHandle*) temporaryFileWithTemplate:(NSString*)templateString extension:(NSString*)extension outFilePath:(NSString**)outFilePath workingDirectory:(NSString*)workingDirectory;
-(BOOL) createLinkInDirectory:(NSString*)directoryPath toTarget:(NSString*)targetPath linkName:(NSString*)linkName;
    
@end
