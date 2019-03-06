/*
 *  CGPDFExtras.m
 *  LaTeXiT
 *
 *  Created by Pierre Chatelier on 06/06/11.
 *  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
 *
 */

#include "CGPDFExtras.h"
#import "Utils.h"

#import <QuartzCore/QuartzCore.h>

static void arrayCallback(CGPDFScannerRef inScanner, void* userInfo)
{
  NSMutableString* string = (CHBRIDGE NSMutableString*)userInfo;
  CGPDFArrayRef array = 0;
  bool success = CGPDFScannerPopArray(inScanner, &array);
  size_t index = 0;
  size_t count = CGPDFArrayGetCount(array);
  for(index = 0 ; index<count ; index += 2)
  {
    CGPDFStringRef pdfString = 0;
    success = CGPDFArrayGetString(array, index, &pdfString);
    if (success)
    {
      CFStringRef cfStringPart = CGPDFStringCopyTextString(pdfString);
      #ifdef ARC_ENABLED
      NSString* stringPart = !cfStringPart ? nil : (CHBRIDGE NSString*)cfStringPart;
      [string appendString:stringPart];
      #else
      NSString* stringPart = !cfStringPart ? nil : (NSString*)CFMakeCollectable(cfStringPart);
      [string appendString:stringPart];
      [stringPart release];
      #endif
    }//end if (success)
  }//end for each array item
}
//end arrayCallback()

static void stringCallback(CGPDFScannerRef inScanner, void *userInfo)
{
  NSMutableString* string = (CHBRIDGE NSMutableString*)userInfo;
  CGPDFStringRef pdfString = 0;
  bool success = CGPDFScannerPopString(inScanner, &pdfString);
  if (success)
  {
    CFStringRef cfStringPart = CGPDFStringCopyTextString(pdfString);
    #ifdef ARC_ENABLED
    NSString* stringPart = !cfStringPart ? nil : (CHBRIDGE NSString*)cfStringPart;
    [string appendString:stringPart];
    #else
    NSString* stringPart = !cfStringPart ? nil : (NSString*)CFMakeCollectable(cfStringPart);
    [string appendString:stringPart];
    [stringPart release];
    #endif
  }//end if (success)
}
//end stringCallback()

BOOL CGPDFDocumentPossibleFromData(NSData* data)
{
  BOOL result = NO;
  CGDataProviderRef dataProvider = !data ? 0 : CGDataProviderCreateWithCFData((CFDataRef)data);
  CGPDFDocumentRef pdfDocument = !dataProvider ? 0 : CGPDFDocumentCreateWithProvider(dataProvider);
  result = (pdfDocument != 0);
  if (pdfDocument)
    CGPDFDocumentRelease(pdfDocument);
  if (dataProvider)
    CGDataProviderRelease(dataProvider);
  return result;
}
//end CGPDFDocumentPossibleFromData()

NSString* CGPDFDocumentCreateStringRepresentationFromData(NSData* pdfData)
{
  NSString* result = nil;
  CGDataProviderRef dataProvider = !pdfData ? 0 : CGDataProviderCreateWithCFData((CFDataRef)pdfData);
  CGPDFDocumentRef pdfDocument = !dataProvider ? 0 : CGPDFDocumentCreateWithProvider(dataProvider);
  result = CGPDFDocumentCreateStringRepresentation(pdfDocument);
  if (pdfDocument)
    CGPDFDocumentRelease(pdfDocument);
  if (dataProvider)
    CGDataProviderRelease(dataProvider);
  return result;
}
//end CGPDFDocumentCreateStringRepresentationFromData()

NSString* CGPDFDocumentCreateStringRepresentation(CGPDFDocumentRef pdfDocument)
{
  NSString* result = nil;
  
  NSMutableString* stringRepresentation = [[NSMutableString alloc] init];

  CGPDFOperatorTableRef callbacksTable = CGPDFOperatorTableCreate();
  CGPDFOperatorTableSetCallback(callbacksTable, "TJ", arrayCallback);
  CGPDFOperatorTableSetCallback(callbacksTable, "Tj", stringCallback);

  size_t pageNumber = 0;
  size_t pagesCount = CGPDFDocumentGetNumberOfPages(pdfDocument);
  for(pageNumber = 1 ; pageNumber <= pagesCount ; ++pageNumber)
  {
    CGPDFPageRef pdfPage = CGPDFDocumentGetPage(pdfDocument, pageNumber);
    CGPDFContentStreamRef contentStream = !pdfPage ? 0 : CGPDFContentStreamCreateWithPage(pdfPage);
    CGPDFScannerRef scanner = !contentStream ? 0 : CGPDFScannerCreate(contentStream, callbacksTable, (CHBRIDGE void*)stringRepresentation);
    if (scanner)
      CGPDFScannerScan(scanner);
    if (scanner)
      CGPDFScannerRelease(scanner);
    if (contentStream)
      CGPDFContentStreamRelease(contentStream);
  }//end for each page
  
  CGPDFOperatorTableRelease(callbacksTable);
  
  if (stringRepresentation)
    result = [NSString stringWithString:stringRepresentation];
  #ifdef ARC_ENABLED
  #else
  [stringRepresentation release];
  #endif
  return result;
}
//end CGPDFDocumentCreateStringRepresentation()
