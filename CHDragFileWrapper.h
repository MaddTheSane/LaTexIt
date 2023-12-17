//
//  CHDragFileWrapper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/11/13.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CHDragFileWrapper : NSObject <NSPasteboardWriting> {
  NSString* fileName;
  NSString* uti;
}

+(instancetype) dragFileWrapperWithFileName:(NSString*)filename uti:(NSString*)uti;

-(id) initWithFileName:(NSString*)filename uti:(NSString*)uti;
@property (readonly, copy) NSString *fileName;
@property (readonly, copy) NSString *uti;

@end
