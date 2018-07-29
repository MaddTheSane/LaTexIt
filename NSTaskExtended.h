//  NSTaskExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSTask class

#import <Cocoa/Cocoa.h>

@interface NSTask (Extended)

//returns a string containing the equivalent command line of the NSTask
@property (readonly, copy) NSString *commandLine;

@end
