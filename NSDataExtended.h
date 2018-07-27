//
//  NSDataExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/11/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSData (Extended)

+(id) dataWithBase64:(NSString*)base64;
+(id) dataWithBase64:(NSString*)base64 encodedWithNewlines:(BOOL)encodedWithNewlines;
-(NSString*) encodeBase64;
-(NSString*) encodeBase64WithNewlines:(BOOL)encodeWithNewlines;

@end
