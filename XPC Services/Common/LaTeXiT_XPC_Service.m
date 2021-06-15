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

#include <unistd.h>

@implementation LaTeXiT_XPC_Service

-(void) processTest:(NSString*)string withReply:(void (^)(NSString* outputString))reply
{
  NSString* upperCaseString = [string uppercaseString];
  reply(upperCaseString);
}

-(void) processLaTeX:(id)inputPlist withReply:(void (^)(id plist))reply
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

    id latexModeObject = [inputPlistAsDict objectForKey:@"latexMode"];
    NSNumber* latexModeNumber = [latexModeObject dynamicCastToClass:[NSColor class]];
    if (!latexModeNumber)
    {
      NSData* latexModeData = [latexModeObject dynamicCastToClass:[NSData class]];
      id latexModePlist = !latexModeData ? nil : [NSPropertyListSerialization propertyListWithData:latexModeData options:NSPropertyListImmutable format:&format error:&error];
      latexModeNumber = [latexModePlist dynamicCastToClass:[NSNumber class]];
    }//end if (!latexModeNumber)
    latex_mode_t latexMode = (latex_mode_t)[latexModeNumber intValue];

    id magnificationObject = [inputPlistAsDict objectForKey:@"magnification"];
    NSNumber* magnificationNumber = [magnificationObject dynamicCastToClass:[NSColor class]];
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
    NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-xpc-service-%@-%p", @(getpid()), inputPlistAsDict];
    NSDictionary* fullEnvironment  = [latexProcessor fullEnvironment];
    NSString* outFullLog = nil;
    NSArray* outErrors = nil;
    NSData* outPdfData = nil;
    [latexProcessor latexiseWithPreamble:preambleString body:bodyString color:color mode:latexMode magnification:magnification compositionConfiguration:compositionConfiguration backgroundColor:backgroundColor title:titleString leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin additionalFilesPaths:additionalFilesPaths workingDirectory:workingDirectory fullEnvironment:fullEnvironment uniqueIdentifier:uniqueIdentifier outFullLog:&outFullLog outErrors:&outErrors outPdfData:&outPdfData];
    if (outPdfData)
      outputPlist = @{@"pdfData":outPdfData};
  }//end if (inputPlistAsDict)
  reply(outputPlist);
}
//end process:withReply:

@end
