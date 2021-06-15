//
//  LaTeXiT_XPC_ServiceProtocol.h
//  LaTeXiT XPC Service
//
//  Created by Pierre Chatelier on 02/10/2020.
//

#import <Foundation/Foundation.h>

@protocol LaTeXiT_XPC_Service_Protocol

-(void) processTest:(NSString*)string withReply:(void (^)(NSString* string))reply;
-(void) processLaTeX:(id)plist exportUTI:(NSString*)exportUTI withReply:(void (^)(id plist))reply;
-(void) openWithLaTeXiT:(NSData*)data uti:(NSString*)uti;
    
@end
