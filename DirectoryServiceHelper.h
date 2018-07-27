//
//  DirectoryServiceHelper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/09/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include <DirectoryService/DirectoryService.h>

@interface DirectoryServiceHelper : NSObject {
  tDirReference gDirRef;
  tDirNodeReference nodeRef;
}

-(NSString*) valueForKey:(const char*)key andUser:(NSString*)userName;

@end
