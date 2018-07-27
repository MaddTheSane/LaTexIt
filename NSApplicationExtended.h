//  NSApplicationExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSApplication class

#import <Cocoa/Cocoa.h>

@interface NSApplication (Extended)

//returns the application name as specified in the main bundle
-(NSString*) applicationName;

@end
