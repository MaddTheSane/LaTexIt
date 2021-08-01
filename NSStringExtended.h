//
//  NSStringExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.

//this file is an extension of the NSWorkspace class

#import <Cocoa/Cocoa.h>

#define USE_REGEXKITLITE 0

#if defined(USE_REGEXKITLITE) && USE_REGEXKITLITE
#import "RegexKitLite.h"
#else
typedef NS_OPTIONS(uint32_t, RKLRegexOptions) {
  RKLNoOptions             = 0,
  RKLCaseless              = 2,
  RKLComments              = 4,
  RKLDotAll                = 32,
  RKLMultiline             = 8,
  RKLUnicodeWordBoundaries = 256
};

FOUNDATION_EXTERN NSRegularExpressionOptions convertRKLOptions(RKLRegexOptions options);

@interface NSString (RegexKitLiteExtension)
-(BOOL) isMatchedByRegex:(NSString*)pattern;
-(BOOL) isMatchedByRegex:(NSString*)pattern options:(RKLRegexOptions)options inRange:(NSRange)range error:(NSError**)error;
-(NSRange) rangeOfRegex:(NSString*)pattern options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError**)error;
-(NSString*) stringByReplacingOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement;
-(NSString*) stringByReplacingOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement options:(RKLRegexOptions)options range:(NSRange)searchRange error:(NSError**)error;
-(NSString*) stringByMatching:(NSString*)pattern options:(RKLRegexOptions)options inRange:(NSRange)range capture:(NSInteger)capture error:(NSError**)error;
-(NSArray<NSString*>*) componentsMatchedByRegex:(NSString*)pattern;
-(NSArray<NSString*>*) componentsMatchedByRegex:(NSString*)pattern options:(RKLRegexOptions)options range:(NSRange)searchRange capture:(NSInteger)capture error:(NSError**)error;
-(NSArray<NSString*>*) captureComponentsMatchedByRegex:(NSString*)pattern options:(RKLRegexOptions)options range:(NSRange)range error:(NSError**)error;
@end

@interface NSMutableString (RegexKitLiteExtension)
-(NSInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement;
-(NSInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement options:(RKLRegexOptions)options range:(NSRange)searchRange error:(NSError**)error;
@end

#endif

@interface NSString (Extended)

//a similar method exists on Tiger, but does not work as I expect; this is a wrapper plus some additions
+(id) stringWithContentsOfFile:(NSString*)path guessEncoding:(NSStringEncoding*)enc error:(NSError**)error;
+(id) stringWithContentsOfURL:(NSURL*)url guessEncoding:(NSStringEncoding*)enc error:(NSError**)error;
+(BOOL) isNilOrEmpty:(NSString*)string;

-(NSRange) range;
-(NSString*) string;//useful for binding
-(NSString*)trim;
-(BOOL) startsWith:(NSString*)substring options:(unsigned)mask;
-(BOOL) endsWith:(NSString*)substring options:(unsigned)mask;
-(const char*) cStringUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(BOOL)flag;
-(NSString*) filteredStringForLatex;
-(NSString*) replaceYenSymbol;

@end
