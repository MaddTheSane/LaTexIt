//
//  LatexitEquation.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/10/08.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h" //for latex_mode_t

extern NSString* LatexitEquationsPboardType;

@class CHExportPrefetcher;

@interface LatexitEquation : NSManagedObject <NSCopying, NSCoding> {
  //NSData*             pdfData;     //pdf data representing the image. It may contain advanced PDF features like meta-data keywords, creator...
  //NSAttributedString* preamble;    //the user preamble of the latex source code
  //NSAttributedString* sourceText;  //the user body of the latex source code
  //NSColor*            color;       //the color chosen for the equation
  //double              pointSize;   //the point size chosen
  //NSDate*             date;        //the date the equation was computed
  //latex_mode_t        mode;        //the mode (ALIGN, EQNARRAY, DISPLAY(\[...\]), INLINE($...$) or TEXT(text))
  
  //NSImage*            pdfCachedImage; //a cached image to display the pdf data  

  //NSColor* backgroundColor;//not really background of the image, just useful when previewing, to prevent text to blend with the background
  //NSString* title;
  int updateLevel;
  BOOL annotateDataDirtyState;
  NSImage* pdfCachedImage;
  BOOL isModelPrior250;
  
  CHExportPrefetcher* exportPrefetcher;
}

+(NSEntityDescription*) entity;

+(void) pushManagedObjectContext:(NSManagedObjectContext*)context;
+(NSManagedObjectContext*) currentManagedObjectContext;
+(NSManagedObjectContext*) popManagedObjectContext;

//
+(NSDictionary*) metaDataFromPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults outPdfData:(NSData**)outPdfData;

//constructors
+(BOOL) latexitEquationPossibleWithUTI:(NSString*)uti;
+(BOOL) latexitEquationPossibleWithData:(NSData*)data sourceUTI:(NSString*)sourceUTI;
+(NSArray*) latexitEquationsWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults;
+(id) latexitEquationWithMetaData:(NSDictionary*)someData useDefaults:(BOOL)useDefaults;
+(id) latexitEquationWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults;
+(id) latexitEquationWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults;
+(id) latexitEquationWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                     color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)date mode:(latex_mode_t)aMode
                     backgroundColor:(NSColor*)backgroundColor;
-(id) initWithMetaData:(NSDictionary*)metaData useDefaults:(BOOL)useDefaults;
-(id) initWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults;
-(id) initWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults;
-(id) initWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                                           color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)date
                                            mode:(latex_mode_t)aMode backgroundColor:(NSColor*)backgroundColor;
-(void) dispose;

//accessors
-(NSData*) pdfData;
-(void) setPdfData:(NSData*)value;
-(NSAttributedString*) preamble;
-(void) setPreamble:(NSAttributedString*)value;
-(NSAttributedString*) sourceText;
-(void) setSourceText:(NSAttributedString*)value;
-(NSColor*) color;
-(void) setColor:(NSColor*)value;
-(double) baseline;
-(void) setBaseline:(double)value;
-(double) pointSize;
-(void) setPointSize:(double)value;
-(NSDate*) date;
-(void) setDate:(NSDate*)value;
-(latex_mode_t) mode;
-(void) setMode:(latex_mode_t)value;
-(NSColor*) backgroundColor;
-(void) setBackgroundColor:(NSColor*)value;
-(NSString*) title;
-(void) setTitle:(NSString*)value;

//transient
-(NSImage*) pdfCachedImage;
-(void) resetPdfCachedImage;

//on the fly
+(NSString*)    latexModeToString:(latex_mode_t)mode;
+(latex_mode_t) latexModeFromString:(NSString*)modeAsString;
-(NSString*) modeAsString;
-(NSString*) string;
-(NSAttributedString*) encapsulatedSource;//the body, with \[...\], $...$ or nothing according to the mode

//utils
-(void) beginUpdate;
-(void) endUpdate;
-(void) checkAndMigrateAlign;
//+(double) baselineFromData:(NSData*)someData;
-(NSString*) titleAuto;
-(NSData*) annotatedPDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords;
-(void) reannotatePDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords;
-(void) writeToPasteboard:(NSPasteboard *)pboard exportFormat:(export_format_t)exportFormat isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider;
-(id) plistDescription;
-(id) initWithDescription:(id)description;
-(CHExportPrefetcher*) exportPrefetcher;

@end
