//
//  CHDragFileWrapper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/11/13.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CHDragFileWrapper : NSObject <NSPasteboardWriting> {
  NSString* fileName;
  NSString* uti;
}

+(instancetype) dragFileWrapperWithFileName:(NSString*)filename uti:(NSString*)uti;

-(instancetype) initWithFileName:(NSString*)filename uti:(NSString*)uti NS_DESIGNATED_INITIALIZER;
-(instancetype) init UNAVAILABLE_ATTRIBUTE;
@property (readonly, copy) NSString *fileName;
@property (readonly, copy) NSString *uti;

@end
