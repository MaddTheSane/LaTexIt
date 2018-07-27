#ifndef __CGPDFEXTRAS_H__
#define __CGPDFEXTRAS_H__

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

BOOL      CGPDFDocumentPossibleFromData(NSData* data);
NSString* CGPDFDocumentCreateStringRepresentationFromData(NSData* pdfData);
NSString* CGPDFDocumentCreateStringRepresentation(CGPDFDocumentRef pdfDocument);

#endif
