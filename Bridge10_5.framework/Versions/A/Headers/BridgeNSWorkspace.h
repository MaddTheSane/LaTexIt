//
//  BridgeNSWorkspace.h
//  Bridge10_5
//
//  Created by Pierre Chatelier on 26/09/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Bridge10_5.h"

@interface Bridge (NSWorkspace)
+(void) loadNSWorkspace;
-(BOOL) filenameExtension:(NSString*)filenameExtension isValidForType:(NSString *)typeName;
@end

@interface NSWorkspace (Bridge)
-(BOOL) filenameExtension:(NSString*)filenameExtension isValidForType:(NSString *)typeName;
@end
