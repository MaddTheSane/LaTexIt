//
//  NSImageExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/07/09.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (Extended)

-(NSBitmapImageRep*) bitmapImageRepresentation;
-(NSBitmapImageRep*) bitmapImageRepresentationWithMaxSize:(NSSize)maxSize;
-(NSPDFImageRep*)    pdfImageRepresentation;
-(NSImageRep*)       bestImageRepresentationInContext:(NSGraphicsContext*)context;

@end
