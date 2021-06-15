//
//  LaTeXiT_XPC_Service.m
//  LaTeXiT XPC Service
//
//  Created by Pierre Chatelier on 02/10/2020.
//

#import "LaTeXiT_XPC_Service.h"

#import "LaTeXProcessor.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSObjectExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#include <unistd.h>

@implementation LaTeXiT_XPC_Service

-(void) processTest:(NSString*)string withReply:(void (^)(NSString* outputString))reply
{
  NSString* upperCaseString = [string uppercaseString];
  reply(upperCaseString);
}

-(void) processLaTeX:(id)inputPlist exportUTI:(NSString*)exportUTI withReply:(void (^)(id plist))reply
{
  id outputPlist = nil;
  NSDictionary* inputPlistAsDict = [inputPlist dynamicCastToClass:[NSDictionary class]];

  NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
  NSError* error = nil;
  if (!inputPlistAsDict)
  {
    NSData* inputPlistAsData = [inputPlist dynamicCastToClass:[NSData class]];
    id decodedPlist = !inputPlistAsData ? nil :
      [NSPropertyListSerialization propertyListWithData:inputPlistAsData options:NSPropertyListImmutable format:&format error:&error];
    inputPlistAsDict = !decodedPlist ? nil : [decodedPlist dynamicCastToClass:[NSDictionary class]];
  }//end if (!inputPlistAsDict)
  if (inputPlistAsDict)
  {
    id preambleObject = [inputPlistAsDict objectForKey:@"preamble"];
    NSString* preambleString = [preambleObject dynamicCastToClass:[NSString class]];
    if (!preambleString)
    {
      NSAttributedString* preambleAttributedString = [preambleObject dynamicCastToClass:[NSAttributedString class]];
      preambleString = preambleAttributedString.string;
    }//end if (!preambleString)
    if (!preambleString)
    {
      NSData* preambleData = [preambleObject dynamicCastToClass:[NSData class]];
      id preamblePlist = !preambleData ? nil : [NSPropertyListSerialization propertyListWithData:preambleData options:NSPropertyListImmutable format:&format error:&error];
      preambleString = [preamblePlist dynamicCastToClass:[NSString class]];
      if (!preambleString)
      {
        NSAttributedString* preambleAttributedString = [preamblePlist dynamicCastToClass:[NSAttributedString class]];
        preambleString = preambleAttributedString.string;
      }//end if (!preambleString)
    }//end if (!preambleString)
    
    id bodyObject = [inputPlistAsDict objectForKey:@"sourceText"];
    NSString* bodyString = [bodyObject dynamicCastToClass:[NSString class]];
    if (!bodyString)
    {
      NSAttributedString* bodyAttributedString = [bodyObject dynamicCastToClass:[NSAttributedString class]];
      bodyString = bodyAttributedString.string;
    }//end if (!bodyString)
    if (!bodyString)
    {
      NSData* bodyData = [bodyObject dynamicCastToClass:[NSData class]];
      id bodyPlist = !bodyData ? nil : [NSPropertyListSerialization propertyListWithData:bodyData options:NSPropertyListImmutable format:&format error:&error];
      bodyString = [bodyPlist dynamicCastToClass:[NSString class]];
      if (!bodyString)
      {
        NSAttributedString* bodyAttributedString = [bodyPlist dynamicCastToClass:[NSAttributedString class]];
        bodyString = bodyAttributedString.string;
      }//end if (!bodyString)
    }//end if (!bodyString)
    
    id colorObject = [inputPlistAsDict objectForKey:@"color"];
    NSColor* color = [colorObject dynamicCastToClass:[NSColor class]];
    if (!color)
    {
      NSData* colorData = [colorObject dynamicCastToClass:[NSData class]];
      color = !colorData ? nil : [NSColor colorWithData:colorData];
    }//end if (!color)

    id latexModeObject = [inputPlistAsDict objectForKey:@"mode"];
    NSNumber* latexModeNumber = [latexModeObject dynamicCastToClass:[NSColor class]];
    if (!latexModeNumber)
    {
      NSData* latexModeData = [latexModeObject dynamicCastToClass:[NSData class]];
      id latexModePlist = !latexModeData ? nil : [NSPropertyListSerialization propertyListWithData:latexModeData options:NSPropertyListImmutable format:&format error:&error];
      latexModeNumber = [latexModePlist dynamicCastToClass:[NSNumber class]];
    }//end if (!latexModeNumber)
    latex_mode_t latexMode = (latex_mode_t)[latexModeNumber intValue];

    id magnificationObject = [inputPlistAsDict objectForKey:@"pointSize"];
    NSNumber* magnificationNumber = [magnificationObject dynamicCastToClass:[NSNumber class]];
    if (!magnificationNumber)
    {
      NSData* magnificationData = [magnificationObject dynamicCastToClass:[NSData class]];
      id magnificationPlist = !magnificationData ? nil : [NSPropertyListSerialization propertyListWithData:magnificationData options:NSPropertyListImmutable format:&format error:&error];
      magnificationNumber = [magnificationPlist dynamicCastToClass:[NSNumber class]];
    }//end if (!magnificationNumber)
    double magnification = [magnificationNumber doubleValue];
    
    id backgroundColorObject = [inputPlistAsDict objectForKey:@"backgroundColor"];
    NSColor* backgroundColor = [backgroundColorObject dynamicCastToClass:[NSColor class]];
    if (!backgroundColor)
    {
      NSData* backgroundColorData = [backgroundColorObject dynamicCastToClass:[NSData class]];
      backgroundColor = !backgroundColorData ? nil : [NSColor colorWithData:backgroundColorData];
    }//end if (!backgroundColor)
    
    id titleObject = [inputPlistAsDict objectForKey:@"title"];
    NSString* titleString = [titleObject dynamicCastToClass:[NSString class]];
    if (!titleString)
    {
      NSData* titleData = [titleObject dynamicCastToClass:[NSData class]];
      id titlePlist = !titleData ? nil : [NSPropertyListSerialization propertyListWithData:titleData options:NSPropertyListImmutable format:&format error:&error];
      titleString = [titlePlist dynamicCastToClass:[NSString class]];
    }//end if (!titleString)

    LaTeXProcessor* latexProcessor = [LaTeXProcessor sharedLaTeXProcessor];
    PreferencesController* preferencesController = [PreferencesController sharedController];
    NSDictionary* compositionConfiguration = [preferencesController compositionConfigurationDocument];
    CGFloat topMargin = [preferencesController marginsAdditionalTop];
    CGFloat leftMargin = [preferencesController marginsAdditionalLeft];
    CGFloat bottomMargin = [preferencesController marginsAdditionalBottom];
    CGFloat rightMargin = [preferencesController marginsAdditionalRight];
    NSArray* additionalFilesPaths = [preferencesController additionalFilesPaths];
    NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
    NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-appex-xpc-service-%@-%p", @(getpid()), inputPlistAsDict];
    NSDictionary* fullEnvironment  = [latexProcessor fullEnvironment];
    NSString* outFullLog = nil;
    NSArray* outErrors = nil;
    NSData* outPdfData = nil;
    [latexProcessor latexiseWithPreamble:preambleString body:bodyString color:color mode:latexMode magnification:magnification compositionConfiguration:compositionConfiguration backgroundColor:backgroundColor title:titleString leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin additionalFilesPaths:additionalFilesPaths workingDirectory:workingDirectory fullEnvironment:fullEnvironment uniqueIdentifier:uniqueIdentifier outFullLog:&outFullLog outErrors:&outErrors outPdfData:&outPdfData];
    NSData* exportedData = nil;
    if (outPdfData && exportUTI)
    {
      NSDictionary* exportOptions =
        [NSDictionary dictionaryWithObjectsAndKeys:
           @([preferencesController exportJpegQualityPercent]), @"jpegQuality",
           @([preferencesController exportScalePercent]), @"scaleAsPercent",
           @([preferencesController exportIncludeBackgroundColor]), @"exportIncludeBackgroundColor",
           @([preferencesController exportTextExportPreamble]), @"textExportPreamble",
           @([preferencesController exportTextExportEnvironment]), @"textExportEnvironment",
           @([preferencesController exportTextExportBody]), @"textExportBody",
           [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
           nil];
      export_format_t exportFormat =
        UTTypeConformsTo((CFStringRef)exportUTI, kUTTypePDF) ? EXPORT_FORMAT_PDF :
        UTTypeConformsTo((CFStringRef)exportUTI, kUTTypePNG) ? EXPORT_FORMAT_PNG :
        UTTypeConformsTo((CFStringRef)exportUTI, kUTTypeTIFF) ? EXPORT_FORMAT_TIFF :
        UTTypeConformsTo((CFStringRef)exportUTI, kUTTypeJPEG) ? EXPORT_FORMAT_JPEG :
        UTTypeConformsTo((CFStringRef)exportUTI, (CFStringRef)GetMySVGPboardType()) ? EXPORT_FORMAT_SVG :
        EXPORT_FORMAT_PDF;
      exportedData = [latexProcessor dataForType:exportFormat pdfData:outPdfData exportOptions:exportOptions compositionConfiguration:compositionConfiguration uniqueIdentifier:uniqueIdentifier];
    }//end if (outPdfData && exportUTI)
    if (outPdfData)
      outputPlist = [NSDictionary dictionaryWithObjectsAndKeys:outPdfData, @"pdfData", exportedData, @"exportedData", nil];
  }//end if (inputPlistAsDict)
  reply(outputPlist);
}
//end process:withReply:

-(void) openWithLaTeXiT:(NSData*)data uti:(NSString*)uti
{
  if (data && uti)
  {
    NSString* folder = NSTemporaryDirectory();
    NSString* filename = [NSString stringWithFormat:@"latexit-service-file-%p.%@", data,
      UTTypeConformsTo((CFStringRef)uti, kUTTypePDF) ? @"pdf" :
      UTTypeConformsTo((CFStringRef)uti, kUTTypePNG) ? @"png" :
      UTTypeConformsTo((CFStringRef)uti, kUTTypeTIFF) ? @"tiff" :
      UTTypeConformsTo((CFStringRef)uti, kUTTypeJPEG) ? @"jpeg" :
      UTTypeConformsTo((CFStringRef)uti, CFSTR("public.svg-image")) ? @"svg" :
      @""];
    NSString* filepath = [folder stringByAppendingPathComponent:filename];
    __block NSURL* fileURL = !filepath ? nil : [NSURL fileURLWithPath:filepath];
    [data writeToURL:fileURL atomically:YES];
    __block NSURL* applicationURL = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"fr.chachatelier.pierre.LaTeXiT"];
    if (isMacOS10_15OrAbove())
    {
      NSWorkspaceOpenConfiguration* configuration = [NSWorkspaceOpenConfiguration configuration];
      [[NSWorkspace sharedWorkspace] openURLs:@[fileURL] withApplicationAtURL:applicationURL configuration:configuration completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
            if (error != nil)
              NSLog(@"could not open <%@> with <%@>: %@", fileURL, applicationURL, error);
            error = nil;
        }];
    }//end if (isMacOS10_15OrAbove())
    else//if (!isMacOS10_15OrAbove())
    {
      bool opened = [[NSWorkspace sharedWorkspace] openFile:filepath withApplication:@"LaTeXiT"];
      if (!opened)
        NSLog(@"could not open <%@> with <%@>", fileURL, applicationURL);
    }//end if (!isMacOS10_15OrAbove())
  }//end if (data && uti)
}
//end openWithLaTeXiT:uti:

@end
