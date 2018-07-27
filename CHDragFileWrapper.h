//
//  CHDragFileWrapper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/11/13.
//  Copyright 2014 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CHDragFileWrapper : NSObject <NSPasteboardWriting> {
  NSString* fileName;
  NSString* uti;
}

+(id) dragFileWrapperWithFileName:(NSString*)filename uti:(NSString*)uti;

-(id) initWithFileName:(NSString*)filename uti:(NSString*)uti;
-(NSString*) fileName;
-(NSString*) uti;

@end
