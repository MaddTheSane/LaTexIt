//
//  LatexitEquation.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/10/08.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h" //for latex_mode_t

extern const NSPasteboardType LatexitEquationsPboardType NS_SWIFT_NAME(latexitEquations);

@class CHExportPrefetcher;

@interface LatexitEquation : NSManagedObject <NSCopying, NSCoding, NSSecureCoding> {
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
  NSInteger updateLevel;
  BOOL annotateDataDirtyState;
  NSImage* pdfCachedImage;
  BOOL isModelPrior250;
  
  CHExportPrefetcher* exportPrefetcher;
}

+(NSEntityDescription*) entity;

+(NSSet<Class>*) allowedSecureDecodedClasses;
@property (readonly, copy, class) NSSet<Class> *allowedSecureDecodedClasses;

+(void) pushManagedObjectContext:(NSManagedObjectContext*)context;
+(NSManagedObjectContext*) currentManagedObjectContext;
+(NSManagedObjectContext*) popManagedObjectContext;

//
+(NSDictionary*) metaDataFromPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults outPdfData:(NSData**)outPdfData;
+(BOOL)          hasInvisibleGraphicCommandsInPDFData:(NSData*)someData;

//constructors
+(BOOL) latexitEquationPossibleWithUTI:(NSString*)uti;
+(BOOL) latexitEquationPossibleWithData:(NSData*)data sourceUTI:(NSString*)sourceUTI;
+(NSArray<LatexitEquation*>*) latexitEquationsWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults;
+(instancetype) latexitEquationWithMetaData:(NSDictionary*)someData useDefaults:(BOOL)useDefaults;
+(instancetype) latexitEquationWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults;
+(instancetype) latexitEquationWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults;
+(instancetype) latexitEquationWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                     color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)date mode:(latex_mode_t)aMode
                     backgroundColor:(NSColor*)backgroundColor
                     title:(NSString*)aTitle;
-(instancetype) initWithMetaData:(NSDictionary*)metaData useDefaults:(BOOL)useDefaults;
-(instancetype) initWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults;
-(instancetype) initWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults;
-(instancetype) initWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                                           color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)date
                                            mode:(latex_mode_t)aMode backgroundColor:(NSColor*)backgroundColor
                                            title:(NSString*)aTitle;
-(void) dispose;

//accessors
@property (nonatomic, copy) NSData *pdfData;
@property (nonatomic, copy) NSAttributedString *preamble;
@property (nonatomic, copy) NSAttributedString *sourceText;
@property (nonatomic, copy) NSColor *color;
@property (nonatomic) double baseline;
@property (nonatomic) double pointSize;
@property (nonatomic, copy) NSDate *date;
@property (nonatomic) latex_mode_t mode;
@property (nonatomic, copy) NSColor *backgroundColor;
@property (nonatomic, copy) NSString *title;

//transient
-(NSImage*) pdfCachedImage;
-(void) resetPdfCachedImage;

//on the fly
+(NSString*)    latexModeToString:(latex_mode_t)mode;
+(latex_mode_t) latexModeFromString:(NSString*)modeAsString;
@property (readonly, copy) NSString *modeAsString;
@property (readonly, copy) NSString *string;
-(NSAttributedString*) encapsulatedSource;//the body, with \[...\], $...$ or nothing according to the mode

//utils
-(void) beginUpdate;
-(void) endUpdate;
-(void) checkAndMigrateAlign;
//+(double) baselineFromData:(NSData*)someData;
-(NSString*) titleAuto;
-(NSData*) annotatedPDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords;
-(void) reannotatePDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords;
-(void) writeToPasteboard:(NSPasteboard *)pboard exportFormat:(export_format_t)exportFormat isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider options:(NSDictionary*)options;
-(id) plistDescription;
-(instancetype) initWithDescription:(id)description;
-(CHExportPrefetcher*) exportPrefetcher;

-(NSString*) computeFileName;
+(NSString*) computeFileNameFromContent:(NSString*)content;

@end
