//  HistoryItem.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//An HistoryItem is a useful structure to hold the info about the generated image
//It will typically contain the latex source code (preamble+body), the color, the mode (\[...\], $...$ or text)
//the date, the point size.

#import "MyDocument.h" //for latex_mode_t

#import <Cocoa/Cocoa.h>

extern NSString* HistoryItemDidChangeNotification;

@interface HistoryItem : NSObject <NSCoding, NSCopying> {
  NSData*             pdfData;     //pdf data representing the image. It may contain advanced PDF features like meta-data keywords, creator...
  NSAttributedString* preamble;    //the user preamble of the latex source code
  NSAttributedString* sourceText;  //the user body of the latex source code
  NSColor*            color;       //the color chosen for the equation
  double              pointSize;   //the point size chosen
  NSDate*             date;        //the date the equation was computed
  latex_mode_t        mode;        //the mode (EQNARRAY, DISPLAY(\[...\]), INLINE($...$) or TEXT(text))

  NSImage*     pdfCachedImage; //a cached image to display the pdf data  
  NSImage*     bitmapCachedImage; //a bitmap equivalent to allow faster display in some cases
  
  NSColor* backgroundColor;//not really background of the image, just useful when previewing, to prevent text to blend with the background
}

//constructors
+(id) historyItemWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults;
+(id) historyItemWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                     color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)date mode:(latex_mode_t)aMode
                     backgroundColor:(NSColor*)backgroundColor;
-(id) initWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults;
-(id) initWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                                           color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)date
                                            mode:(latex_mode_t)aMode backgroundColor:(NSColor*)backgroundColor;

//Accessors
-(NSImage*)            image;//triggered for tableView display : will return [self bitmapImage] get faster display than with [self pdfImage]
-(NSImage*)            bitmapImage;
-(NSImage*)            pdfImage;
-(NSData*)             pdfData;
-(NSAttributedString*) preamble;
-(NSAttributedString*) sourceText;
-(NSColor*)            color;
-(double)              pointSize;
-(NSDate*)             date;
-(latex_mode_t)        mode;
-(NSColor*)            backgroundColor;

-(void) setPreamble:(NSAttributedString*)text;
-(void) setBackgroundColor:(NSColor*)backgroundColor;

//latex source code (preamble+body) typed by the user. This WON'T add magnification, auto-bounding, coloring.
//It is a summary of what the user did effectively type.
-(NSString*) string;

//to feed a pasteboard. It needs a document, because there may be some temporary files needed for certain kind of data
//the lazyDataProvider, if not nil, is the one who will call [pasteboard:provideDataForType] *as needed* (to save time)
-(void) writeToPasteboard:(NSPasteboard *)pboard forDocument:(MyDocument*)document isLinkBackRefresh:(BOOL)isLinkBackRefresh
         lazyDataProvider:(id)lazyDataProvider;
         
//returns reannotated pdfData before returning it. Very rare. Only needed to resynchronize because of some backgroundColor change.
-(NSData*) annotatedPDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords;

@end
