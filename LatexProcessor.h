//
//  LaTeXProcessor.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/09/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@interface LaTeXProcessor : NSObject {
  NSManagedObjectModel* managedObjectModel;
  NSMutableArray*       unixBins;
  NSMutableString*      globalEnvironmentPath;
  NSMutableDictionary*  globalFullEnvironment;
  NSMutableDictionary*  globalExtraEnvironment;
  BOOL                  environmentsInitialized;
}

+(LaTeXProcessor*) sharedLaTeXProcessor;

-(NSManagedObjectModel*) managedObjectModel;
-(NSArray*)      unixBins;
-(NSString*)     environmentPath;
-(NSDictionary*) fullEnvironment;
-(NSDictionary*) extraEnvironment;

-(void) addInEnvironmentPath:(NSString*)path;

-(NSData*) annotatePdfDataInLEEFormat:(NSData*)data preamble:(NSString*)preamble source:(NSString*)source color:(NSColor*)color
                                 mode:(mode_t)mode magnification:(double)magnification baseline:(double)baseline
                                 backgroundColor:(NSColor*)backgroundColor title:(NSString*)title;

-(NSString*) insertColorInPreamble:(NSString*)thePreamble color:(NSColor*)theColor isColorStyAvailable:(BOOL)isColorStyAvailable;

-(NSString*) latexiseWithPreamble:(NSString*)preamble body:(NSString*)body color:(NSColor*)color mode:(latex_mode_t)latexMode 
                    magnification:(double)magnification compositionConfiguration:(NSDictionary*)compositionConfiguration
                    backgroundColor:(NSColor*)backgroundColor
                    leftMargin:(CGFloat)leftMargin rightMargin:(CGFloat)rightMargin
                    topMargin:(CGFloat)topMargin bottomMargin:(CGFloat)bottomMargin
                    additionalFilesPaths:(NSArray*)additionalFilesPaths
                    workingDirectory:(NSString*)workingDirectory fullEnvironment:(NSDictionary*)fullEnvironment
                    uniqueIdentifier:(NSString*)uniqueIdentifier
                    outFullLog:(NSString**)outFullLog outErrors:(NSArray**)outErrors outPdfData:(NSData**)outPdfData;

-(NSRect) computeBoundingBox:(NSString*)filePath workingDirectory:(NSString*)workingDirectory
             fullEnvironment:(NSDictionary*)fullEnvironment compositionConfiguration:(NSDictionary*)compositionConfiguration;

-(NSData*) composeLaTeX:(NSString*)filePath customLog:(NSString**)customLog
              stdoutLog:(NSString**)stdoutLog stderrLog:(NSString**)stderrLog
              compositionConfiguration:(NSDictionary*)compositionConfiguration
              fullEnvironment:(NSDictionary*)fullEnvironment;

-(NSArray*) filterLatexErrors:(NSString*)fullErrorLog shiftLinesBy:(int)errorLineShift;
-(BOOL) crop:(NSString*)inoutPdfFilePath to:(NSString*)outputPdfFilePath canClip:(BOOL)canClip extraArguments:(NSArray*)extraArguments
        compositionConfiguration:(NSDictionary*)compositionConfiguration
        workingDirectory:(NSString*)workingDirectory
        environment:(NSDictionary*)environment
        outPdfData:(NSData**)outPdfData;

-(NSString*) descriptionForScript:(NSDictionary*)script;

-(void) executeScript:(NSDictionary*)script setEnvironment:(NSDictionary*)environment logString:(NSMutableString*)logString
        workingDirectory:(NSString*)workingDirectory uniqueIdentifier:(NSString*)uniqueIdentifier
        compositionConfiguration:(NSDictionary*)compositionConfiguration;

//returns a file icon to represent the given PDF data; if not specified (nil), the backcground color will be half-transparent
-(NSImage*) makeIconForData:(NSData*)pdfData backgroundColor:(NSColor*)backgroundColor;

-(NSData*) dataForType:(export_format_t)format pdfData:(NSData*)pdfData
             jpegColor:(NSColor*)color jpegQuality:(CGFloat)quality scaleAsPercent:(CGFloat)scaleAsPercent
             compositionConfiguration:(NSDictionary*)compositionConfiguration;
@end