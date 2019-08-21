//
//  LaTeXProcessor.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/09/08.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class TeXItemWrapper;

extern NSNotificationName const LatexizationDidEndNotification;

@interface LaTeXProcessor : NSObject {
  NSManagedObjectModel* managedObjectModel;
  NSMutableArray<NSString*>*       unixBins;
  NSMutableString*      globalEnvironmentPath;
  NSMutableDictionary<NSString*,NSString*>*  globalFullEnvironment;
  NSMutableDictionary<NSString*,NSString*>*  globalExtraEnvironment;
  BOOL                  environmentsInitialized;
}

@property (class, readonly, strong) LaTeXProcessor *sharedLaTeXProcessor;

@property (readonly, copy) NSManagedObjectModel *managedObjectModel;
@property (readonly, copy) NSArray<NSString*> *unixBins;
@property (readonly, copy) NSString *environmentPath;
@property (readonly, copy) NSDictionary<NSString*,NSString*> *fullEnvironment;
@property (readonly, copy) NSDictionary<NSString*,NSString*> *extraEnvironment;

-(void) addInEnvironmentPath:(NSString*)path;

-(NSData*) stripPdfData:(NSData*)pdfData;
-(NSData*) annotateData:(NSData*)inputData ofUTI:(NSString*)sourceUTI withData:(NSData*)annotationData;
-(NSData*) annotatePdfDataInLEEFormat:(NSData*)data exportFormat:(export_format_t)exportFormat preamble:(NSString*)preamble source:(NSString*)source color:(NSColor*)color
                                 mode:(mode_t)mode magnification:(double)magnification baseline:(double)baseline
                                 backgroundColor:(NSColor*)backgroundColor title:(NSString*)title
                                 annotateWithTransparentData:(BOOL)annotateWithTransparentData;

-(NSString*) insertColorInPreamble:(NSString*)thePreamble color:(NSColor*)theColor isColorStyAvailable:(BOOL)isColorStyAvailable;

-(void) latexiseTeXItems:(NSArray<TeXItemWrapper*>*)teXItems backgroundly:(BOOL)backgroundly delegate:(id)delegate itemDidEndSelector:(SEL)itemDidEndSelector groupDidEndSelector:(SEL)groupDidEndSelector;
-(void)      latexiseWithConfiguration:(NSMutableDictionary*)configuration;
-(NSString*) latexiseWithPreamble:(NSString*)preamble body:(NSString*)body color:(NSColor*)color mode:(latex_mode_t)latexMode 
                    magnification:(double)magnification compositionConfiguration:(NSDictionary<CompositionConfigurationKey,id>*)compositionConfiguration
                    backgroundColor:(NSColor*)backgroundColor
                              title:(NSString*)title
                    leftMargin:(CGFloat)leftMargin rightMargin:(CGFloat)rightMargin
                    topMargin:(CGFloat)topMargin bottomMargin:(CGFloat)bottomMargin
                    additionalFilesPaths:(NSArray<NSString*>*)additionalFilesPaths
                    workingDirectory:(NSString*)workingDirectory fullEnvironment:(NSDictionary<NSString*,NSString*>*)fullEnvironment
                    uniqueIdentifier:(NSString*)uniqueIdentifier
                    outFullLog:(NSString**)outFullLog outErrors:(NSArray<NSString*>**)outErrors outPdfData:(NSData**)outPdfData;

-(NSRect) computeBoundingBox:(NSString*)filePath workingDirectory:(NSString*)workingDirectory
             fullEnvironment:(NSDictionary<NSString*,NSString*>*)fullEnvironment compositionConfiguration:(NSDictionary<CompositionConfigurationKey,id>*)compositionConfiguration
                  outFullLog:(NSMutableString*)outFullLog;

-(NSData*) composeLaTeX:(NSString*)filePath customLog:(NSString**)customLog
              stdoutLog:(NSString**)stdoutLog stderrLog:(NSString**)stderrLog
              compositionConfiguration:(NSDictionary<CompositionConfigurationKey,id>*)compositionConfiguration
              fullEnvironment:(NSDictionary<NSString*,NSString*>*)fullEnvironment;

-(NSArray<NSString*>*) filterLatexErrors:(NSString*)fullErrorLog shiftLinesBy:(NSInteger)errorLineShift;
-(BOOL) crop:(NSString*)inoutPdfFilePath to:(NSString*)outputPdfFilePath canClip:(BOOL)canClip extraArguments:(NSArray<NSString*>*)extraArguments
        compositionConfiguration:(NSDictionary<CompositionConfigurationKey,id>*)compositionConfiguration
        workingDirectory:(NSString*)workingDirectory
        environment:(NSDictionary<NSString*,NSString*>*)environment
        outFullLog:(NSMutableString*)outFullLog
        outPdfData:(NSData**)outPdfData;

-(NSString*) descriptionForScript:(NSDictionary<CompositionConfigurationKey,id>*)script;

-(void) executeScript:(NSDictionary<CompositionConfigurationKey,id>*)script setEnvironment:(NSDictionary<NSString*,NSString*>*)environment logString:(NSMutableString*)logString
        workingDirectory:(NSString*)workingDirectory uniqueIdentifier:(NSString*)uniqueIdentifier
        compositionConfiguration:(NSDictionary<CompositionConfigurationKey,id>*)compositionConfiguration;

//! returns a file icon to represent the given PDF data; if not specified (nil), the backcground color will be half-transparent
-(NSImage*) makeIconForData:(NSData*)pdfData backgroundColor:(NSColor*)backgroundColor;

-(NSData*) dataForType:(export_format_t)format pdfData:(NSData*)pdfData
             exportOptions:(NSDictionary<NSString*,id>*)exportOptions
             compositionConfiguration:(NSDictionary<CompositionConfigurationKey,id>*)compositionConfiguration
             uniqueIdentifier:(NSString*)uniqueIdentifier;

-(void) displayAlertError:(id)object;
@end
