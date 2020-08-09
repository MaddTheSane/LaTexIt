//
//  FileExistsTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FileExistsTransformer : NSValueTransformer {
  BOOL directoryAllowed;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithDirectoryAllowed:(BOOL)directoryAllowed;
-(instancetype) initWithDirectoryAllowed:(BOOL)directoryAllowed NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;
@end
