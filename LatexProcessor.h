//
//  LatexProcessor.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/09/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@interface LatexProcessor : NSObject {

}

+(NSData*) annotatePdfDataInLEEFormat:(NSData*)data preamble:(NSString*)preamble source:(NSString*)source color:(NSColor*)color
                                 mode:(mode_t)mode magnification:(double)magnification baseline:(double)baseline
                                 backgroundColor:(NSColor*)backgroundColor title:(NSString*)title;
+(NSString*) insertColorInPreamble:(NSString*)thePreamble color:(NSColor*)theColor isColorStyAvailable:(BOOL)isColorStyAvailable;
+(NSString*) latexiseWithPreamble:(NSString*)preamble body:(NSString*)body color:(NSColor*)color mode:(latex_mode_t)latexMode 
                    magnification:(double)magnification compositionMode:(composition_mode_t)compositionMode
                    workingDirectory:(NSString*)workingDirectory uniqueIdentifier:(NSString*)uniqueIdentifier
                    additionalFilepaths:(NSArray*)additionalFilepaths
                    fullEnvironment:(NSDictionary*)fullEnvironment
                    useLoginShell:(BOOL)useLoginShell
                    pdfLatexPath:(NSString*)pdfLatexPath xeLatexPath:(NSString*)xeLatexPath latexPath:(NSString*)latexPath
                    dviPdfPath:(NSString*)dviPdfPath gsPath:(NSString*)gsPath ps2PdfPath:(NSString*)ps2PdfPath
                    leftMargin:(float)leftMargin rightMargin:(float)rightMargin
                    topMargin:(float)topMargin bottomMargin:(float)bottomMargin
                    backgroundColor:(NSColor*)backgroundColor
                    additionalProcessingScripts:(NSDictionary*)additionalProcessingScripts
                    outFullLog:(NSString**)outFullLog outErrors:(NSArray**)outErrors outPdfData:(NSData**)outPdfData;
+(NSRect)    computeBoundingBox:(NSString*)filePath workingDirectory:(NSString*)directory
               fullEnvironment:(NSDictionary*)fullEnvironment useLoginShell:(BOOL)useLoginShell
                     dviPdfPath:(NSString*)dviPdfPath gsPath:(NSString*)gsPath;
+(NSData*) composeLaTeX:(NSString*)filePath customLog:(NSString**)customLog
                                             stdoutLog:(NSString**)stdoutLog stderrLog:(NSString**)stderrLog
                                       compositionMode:(composition_mode_t)compositionMode
           pdfLatexPath:(NSString*)pdfLatexPath xeLatexPath:(NSString*)xeLatexPath latexPath:(NSString*)latexPath
           dviPdfPath:(NSString*)dviPdfPath
           fullEnvironment:(NSDictionary*)fullEnvironment useLoginShell:(BOOL)useLoginShell;
+(NSArray*) filterLatexErrors:(NSString*)fullErrorLog shiftLinesBy:(int)errorLineShift;
+(BOOL) crop:(NSString*)inoutPdfFilePath to:(NSString*)outputPdfFilePath extraArguments:(NSArray*) extraArguments
  useLoginShell:(BOOL)useLoginShell workingDirectory:(NSString*)workingDirectory environment:(NSDictionary*)environment
     outPdfData:(NSData**)outPdfData;
+(NSString*) descriptionForScript:(NSDictionary*)script;
+(void) executeScript:(NSDictionary*)script setEnvironment:(NSDictionary*)environment logString:(NSMutableString*)logString
     workingDirectory:(NSString*)directory uniqueIdentifier:(NSString*)uniqueIdentifier useLoginShell:(BOOL)useLoginShell;

//returns a file icon to represent the given PDF data; if not specified (nil), the backcground color will be half-transparent
+(NSImage*) makeIconForData:(NSData*)pdfData backgroundColor:(NSColor*)backgroundColor;

@end
