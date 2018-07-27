//
//  NSDataExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/11/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSData (Extended)

+(instancetype) dataWithBase64:(NSString*)base64;
+(instancetype) dataWithBase64:(NSString*)base64 encodedWithNewlines:(BOOL)encodedWithNewlines;
-(NSString*) encodeBase64;
-(NSString*) encodeBase64WithNewlines:(BOOL)encodeWithNewlines;
-(NSString*) sha1Base64;
@end
