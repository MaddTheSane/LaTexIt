//
//  NSFontExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/07/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSFont class

#import <Cocoa/Cocoa.h>

@interface NSFont (Extended)

//Unfortunately, so far, an NSFont does not know how to transform itself into data, or built itself with data
//We have to make that by hand
+(NSFont*) fontWithData:(NSData*)data;
@property (readonly, copy) NSData *data;

@property (readonly, copy) NSString *displayNameWithPointSize;

@end
