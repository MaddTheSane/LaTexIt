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
@property (readonly, copy) NSBitmapImageRep *bitmapImageRepresentation;
@property (readonly, copy) NSBitmapImageRep *newBitmapImageRepresentation;
-(NSBitmapImageRep*) bitmapImageRepresentationWithMaxSize:(NSSize)maxSize;
@property (readonly, copy) NSPDFImageRep *pdfImageRepresentation;
-(NSImageRep*)       bestImageRepresentationInContext:(NSGraphicsContext*)context;

@end
