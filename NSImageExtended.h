//
//  NSImageExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/07/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (Extended)

-(NSBitmapImageRep*) bitmapImageRepresentation;
-(NSBitmapImageRep*) bitmapImageRepresentationWithMaxSize:(NSSize)maxSize;
-(CGImageRef) CGImageRetained;

@end
