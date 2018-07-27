//
//  NSStringExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSWorkspace class

#import <Cocoa/Cocoa.h>

@interface NSString (Extended)

//a similar method exists on Tiger, but does not work as I expect; this is a wrapper plus some additions
+(id) stringWithContentsOfFile:(NSString *)path guessEncoding:(NSStringEncoding *)enc error:(NSError **)error;

-(BOOL) startsWith:(NSString*)substring options:(unsigned)mask;
-(BOOL) endsWith:(NSString*)substring options:(unsigned)mask;
-(const char*) cStringUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(BOOL)flag;
@end
