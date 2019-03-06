//
//  NSImageExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/07/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (Extended)

-(void)              removeRepresentationsOfClass:(Class)representationClass;
-(NSBitmapImageRep*) bitmapImageRepresentation;
-(NSBitmapImageRep*) newBitmapImageRepresentation;
-(NSBitmapImageRep*) bitmapImageRepresentationWithMaxSize:(NSSize)maxSize;
-(NSPDFImageRep*)    pdfImageRepresentation;
-(NSImageRep*)       bestImageRepresentationInContext:(NSGraphicsContext*)context;
-(NSImage*) imageWithBackground:(NSColor*)color rounded:(CGFloat)rounded;

@end
