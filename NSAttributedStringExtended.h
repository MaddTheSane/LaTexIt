//
//  NSAttributedStringExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/08/06.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include "NSStringExtended.h"

#if defined(USE_REGEXKITLITE) && USE_REGEXKITLITE
#else
@interface NSMutableAttributedString (RegexKitLiteExtension)

-(NSInteger) replaceOccurrencesOfRegex:(NSString*)pattern withString:(NSString*)replacement options:(RKLRegexOptions)options range:(NSRange)searchRange error:(NSError**)error;

@end
#endif

@interface NSAttributedString (Extended)

-(NSRange) range;
-(NSDictionary*) attachmentsOfType:(NSString*)type docAttributes:(NSDictionary*)docAttributes;

@end
