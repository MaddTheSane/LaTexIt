#ifndef __CGPDFEXTRAS_H__
#define __CGPDFEXTRAS_H__

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

NS_ASSUME_NONNULL_BEGIN

BOOL      CGPDFDocumentPossibleFromData(NSData* data);
NSString* _Nullable CGPDFDocumentCreateStringRepresentationFromData(NSData* pdfData);
NSString* _Nullable CGPDFDocumentCreateStringRepresentation(CGPDFDocumentRef pdfDocument);

NS_ASSUME_NONNULL_END

#endif
