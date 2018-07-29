//
//  NSStringExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSWorkspace class

#import <Cocoa/Cocoa.h>

@interface NSString (Extended)

///a similar method exists on Tiger, but does not work as I expect; this is a wrapper plus some additions
+(NSString*) stringWithContentsOfFile:(NSString*)path guessEncoding:(NSStringEncoding*)enc error:(NSError**)error;
+(NSString*) stringWithContentsOfURL:(NSURL*)url guessEncoding:(NSStringEncoding*)enc error:(NSError**)error;

@property (readonly) NSRange range;
@property (readonly, copy) NSString *string;//useful for binding
@property (readonly, copy) NSString *trim;
-(BOOL) startsWith:(NSString*)substring options:(NSStringCompareOptions)mask;
-(BOOL) endsWith:(NSString*)substring options:(NSStringCompareOptions)mask;
-(const char*) cStringUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(BOOL)flag NS_RETURNS_INNER_POINTER;
@property (readonly, copy) NSString *stringWithFilteredStringForLatex;
@property (readonly, copy) NSString *stringByReplacingYenSymbol;
-(NSString*) filteredStringForLatex DEPRECATED_ATTRIBUTE;
@property (readonly, copy) NSString *replaceYenSymbol NS_UNAVAILABLE;

@end

@interface NSMutableString (Extended)
- (void)replaceYenSymbol;
@end
