//
//  NSImageExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/07/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (Extended)

-(NSBitmapImageRep*) bitmapImageRepresentation;
-(NSBitmapImageRep*) bitmapImageRepresentationWithMaxSize:(NSSize)maxSize;
-(CGImageRef) CGImageRetained;

@end
