//
//  FileExistsTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FileExistsTransformer : NSValueTransformer {
  BOOL directoryAllowed;
}

+(NSString*) name;

+(id) transformerWithDirectoryAllowed:(BOOL)directoryAllowed;
-(id) initWithDirectoryAllowed:(BOOL)directoryAllowed;

@end
