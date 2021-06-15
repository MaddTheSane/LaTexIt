//
//  ActionViewController.h
//  LaTeXiT_AppExtension
//
//  Created by Pierre Chatelier on 01/10/2020.
//

#import <Cocoa/Cocoa.h>

@class LatexitEquation;

@interface ActionViewController : NSViewController {
  NSData* originalData;
  NSString* originalUTI;
  NSData* pdfData;
  NSData* exportedData;
  NSString* exportedUTI;
  LatexitEquation* equation;
  NSXPCConnection* connectionToService;
}

@end
