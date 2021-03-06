//
//  Automator_CreateEquations.m
//  Automator_CreateEquations
//
//  Created by Pierre Chatelier on 24/09/08.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "Automator_CreateEquations.h"

#import "ExportFormatOptionsPanes.h"
#import "IsInTransformer.h"
#import "KeyedUnarchiveFromDataTransformer.h"
#import "LaTeXiTSharedTypes.h"
#import "LaTeXProcessor.h"
#import "NSMutableArrayExtended.h"
#import "NSColorExtended.h"
#import "NSDictionaryCompositionConfiguration.h"
#import "NSFileManagerExtended.h"
#import "NSObjectExtended.h"
#import "NSPopUpButtonExtended.h"
#import "NSStringExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreamblesController.h"
#import "PreferencesController.h"
#import "Utils.h"

#import <OSAKit/OSAKit.h>
#import "RegexKitLite.h"
#import <Automator/AutomatorErrors.h>

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

static NSMutableIndexSet* freeIds = nil;

typedef enum {EQUATION_DESTINATION_ALONGSIDE_INPUT, EQUATION_DESTINATION_TEMPORARY_FOLDER} equationDestination_t;

@interface Automator_CreateEquations () <ExportFormatOptionsDelegate>
-(IBAction) nilAction:(id)sender;
@end

@implementation Automator_CreateEquations

+(void) initialize
{
  if (!freeIds)
  {
    @synchronized(self)
    {
      if (!freeIds)
      {
        NSInteger debugLogLevelShift = 0;
        BOOL shiftIsPressed = ((GetCurrentEventKeyModifiers() & shiftKey) != 0);
        if (shiftIsPressed)
        {
          NSLog(@"Shift key pressed during launch");
          debugLogLevelShift = 1;
        }//end if (shiftIsPressed)
        DebugLogLevel += debugLogLevelShift;
        if (DebugLogLevel >= 1){
          NSLog(@"Launching with DebugLogLevel = %d", DebugLogLevel);
        }

        if (!freeIds)
          freeIds = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(1, NSNotFound-2)];
        [KeyedUnarchiveFromDataTransformer initialize];//seems needed on Tiger
      }//end if (!freeIds)
    }//end @synchronized(self)
  }//end if (!freeIds)
}
//end initialize

+(NSUInteger) getNewIdentifier
{
  NSUInteger result = 0;
  @synchronized(freeIds)
  {
    result = freeIds.firstIndex;
    [freeIds removeIndex:result];
  }//end @synchronized(freeIds)
  return result;
}
//end getNewIdentifier

+(void) releaseIdentifier:(NSUInteger)identifier
{
  @synchronized(freeIds)
  {
    [freeIds addIndex:identifier];
  }//end @synchronized(freeIds)
}
//end getNewIdentifier

-(NSString*) workingDirectory
{
  NSString* temporaryPath =
    [NSTemporaryDirectory() stringByAppendingPathComponent:
      [NSString stringWithFormat:@"latexit-automator-%lu", (unsigned long)self->uniqueId]];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  BOOL exists = [fileManager fileExistsAtPath:temporaryPath isDirectory:&isDirectory];
  if (exists && !isDirectory)
  {
    [fileManager removeItemAtPath:temporaryPath error:0];
    exists = NO;
  }
  if (!exists)
    [fileManager createDirectoryAtPath:temporaryPath withIntermediateDirectories:YES attributes:nil error:0];
  return temporaryPath;
}
//end workingDirectory

-(instancetype) initWithDefinition:(NSDictionary*)dict fromArchive:(BOOL)archived
{
  if ((!(self = [super initWithDefinition:dict fromArchive:archived])))
    return nil;
  self->fromArchive = archived;
  self->uniqueId = [[self class] getNewIdentifier];
  return self;
}
//end initWithDefinition:fromArchive:

-(void) dealloc
{
  [[self class] releaseIdentifier:self->uniqueId];
}
//end dealloc

-(void) opened
{
  if (!self->fromArchive) //init from latexit preferences
  {
    NSMutableDictionary* dict = self.parameters;
    PreferencesController* preferencesController = [PreferencesController sharedController];
    CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
    NSString* latexitVersion = preferencesController.latexitVersion;
    self->latexitPreferencesAvailable = latexitVersion && ![latexitVersion isEqualToString:@""];
    
    [self->tabView selectTabViewItemWithIdentifier:self->latexitPreferencesAvailable ?
      @"parameters" : @"warning"];
    
    latex_mode_t equationMode = preferencesController.latexisationLaTeXMode;
    if (equationMode == LATEX_MODE_AUTO)
      equationMode = LATEX_MODE_ALIGN;
    [self->exportFormatPopupButton selectItemWithTag:[preferencesController exportFormatPersistent]];
    CGFloat      fontSize       = [preferencesController latexisationFontSize];
    NSData*      fontColorData  = [preferencesController latexisationFontColorData];
    CGFloat exportJpegQualityPercent = preferencesController.exportJpegQualityPercent;
    NSData* exportJpegBackgroundColorAsData = [preferencesController exportJpegBackgroundColorData];
    NSString* exportSvgPdfToSvgPath = [preferencesController exportSvgPdfToSvgPath];
    BOOL exportTextExportPreamble = [preferencesController exportTextExportPreamble];
    BOOL exportTextExportEnvironment = [preferencesController exportTextExportEnvironment];
    BOOL exportTextExportBody = [preferencesController exportTextExportBody];
    dict[@"equationMode"] = @(equationMode);
    dict[@"fontSize"] = @(fontSize);
    dict[@"exportJpegQualityPercent"] = @(exportJpegQualityPercent);
    dict[@"exportJpegBackgroundColor"] = exportJpegBackgroundColorAsData;
    dict[@"exportSvgPdfToSvgPath"] = exportSvgPdfToSvgPath;
    dict[@"exportTextExportPreamble"] = @(exportTextExportPreamble);
    dict[@"exportTextExportEnvironment"] = @(exportTextExportEnvironment);
    dict[@"exportTextExportBody"] = @(exportTextExportBody);
    if (fontColorData)
      dict[@"fontColorData"] = fontColorData;
    self.parameters = dict;
  }//end if (!self->fromArchive) //init from latexit preferences
  [self parametersUpdated];
  [super opened];
}
//end opened

-(void) awakeFromBundle
{

}
//end awakeFromBundle

-(void) awakeFromNib
{
  [self->warningMessage setStringValue:LocalLocalizedString(@"You must run LaTeXiT once, to init the configuration", @"")];

  [[self->latexModeSegmentedControl cell] setTag:LATEX_MODE_ALIGN   forSegment:0];
  [[self->latexModeSegmentedControl cell] setTag:LATEX_MODE_DISPLAY forSegment:1];
  [[self->latexModeSegmentedControl cell] setTag:LATEX_MODE_INLINE  forSegment:2];
  [[self->latexModeSegmentedControl cell] setTag:LATEX_MODE_TEXT    forSegment:3];
  [[self->latexModeSegmentedControl cell] setLabel:LocalLocalizedString(@"Align", @"") forSegment:0];
  [[self->latexModeSegmentedControl cell] setLabel:LocalLocalizedString(@"Text", @"") forSegment:3];

  NSRect rect = NSZeroRect;
  CGFloat x = 0;
  CGFloat width = 0;
  rect = self->parametersView.frame;
  rect.origin.x = 20;
  rect.size.width = self->parametersView.superview.frame.size.width-2*rect.origin.x;
  self->parametersView.frame = rect;
  
  [self->fontSizeLabel  setStringValue:LocalLocalizedString(@"Font size :", @"")];
  [self->fontSizeLabel sizeToFit];
  [self->fontColorLabel setStringValue:LocalLocalizedString(@"Color :", @"")];
  [self->fontColorLabel sizeToFit];

  [self->exportFormatPopupButton removeAllItems];
/*  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"Default format", @"")
                                              tag:-1];*/
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"PDF vector format", @"")
                                              tag:(NSInteger)EXPORT_FORMAT_PDF];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"PDF with outlined fonts", @"")
                                              tag:(NSInteger)EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"EPS vector format", @"")
                                              tag:(NSInteger)EXPORT_FORMAT_EPS];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"SVG vector format", @"")
                                              tag:(NSInteger)EXPORT_FORMAT_SVG];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"TIFF bitmap format", @"")
                                              tag:(NSInteger)EXPORT_FORMAT_PNG];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"PNG bitmap format", @"")
                                              tag:(NSInteger)EXPORT_FORMAT_TIFF];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"JPEG bitmap format", @"")
                                              tag:(NSInteger)EXPORT_FORMAT_JPEG];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"MathML text format", @"")
                                              tag:(NSInteger)EXPORT_FORMAT_MATHML];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"Text format", @"")
                                              tag:(NSInteger)EXPORT_FORMAT_TEXT];
  self->exportFormatPopupButton.target = self;
  self->exportFormatPopupButton.action = @selector(nilAction:);
  [self->exportFormatPopupButton sizeToFit];

  [self->exportFormatOptionsButton setTitle:[NSString stringWithFormat:@"%@...", LocalLocalizedString(@"Options", @"")]];
  [self->exportFormatOptionsButton sizeToFit];
  [self->exportFormatOptionsButton bind:NSEnabledBinding toObject:self withKeyPath:@"parameters.exportFormat" options:
    @{NSValueTransformerBindingOption:[IsInTransformer transformerWithReferences:@[@(EXPORT_FORMAT_JPEG), @(EXPORT_FORMAT_SVG)]]}];

  [self->createEquationsOptionsLabel setStringValue:LocalLocalizedString(@"Create equations :", @"")];
  [self->createEquationsOptionsLabel sizeToFit];
  [self->createEquationsOptionsPopUpButton removeAllItems];
  [self->createEquationsOptionsPopUpButton addItemWithTitle:LocalLocalizedString(@"alongside input files", @"")
                                                        tag:EQUATION_DESTINATION_ALONGSIDE_INPUT];
  [self->createEquationsOptionsPopUpButton addItemWithTitle:LocalLocalizedString(@"in a temporary folder", @"")
                                                        tag:EQUATION_DESTINATION_TEMPORARY_FOLDER];
  [self->createEquationsOptionsPopUpButton sizeToFit];
  
  width =
    self->fontSizeLabel.frame.size.width+4+self->fontSizeTextField.frame.size.width+4+self->fontSizeStepper.frame.size.width+
    20+
    self->fontColorLabel.frame.size.width+4+self->fontColorWell.frame.size.width;
  x = (self->parametersView.frame.size.width-width)/2;

  rect = self->fontSizeLabel.frame;
  rect.origin.x = x;
  self->fontSizeLabel.frame = rect;
  rect = self->fontSizeTextField.frame;
  rect.origin.x = NSMaxX(self->fontSizeLabel.frame)+4;
  self->fontSizeTextField.frame = rect;
  rect = self->fontSizeStepper.frame;
  rect.origin.x = NSMaxX(self->fontSizeTextField.frame)+4;
  self->fontSizeStepper.frame = rect;
  rect = self->fontColorLabel.frame;
  rect.origin.x = NSMaxX(self->fontSizeStepper.frame)+20;
  self->fontColorLabel.frame = rect;
  rect = self->fontColorWell.frame;
  rect.origin.x = NSMaxX(self->fontColorLabel.frame)+4;
  self->fontColorWell.frame = rect;
  
  width = [self->exportFormatPopupButton frame].size.width+4+[self->exportFormatOptionsButton frame].size.width;
  x = ([self->parametersView frame].size.width-width)/2;
  rect = [self->exportFormatPopupButton frame];
  rect.origin.x = x;
  [self->exportFormatPopupButton setFrame:rect];
  rect = [self->exportFormatOptionsButton frame];
  rect.origin.x = NSMaxX([self->exportFormatPopupButton frame])+4;
  [self->exportFormatOptionsButton setFrame:rect];

  width = [self->createEquationsOptionsLabel frame].size.width+4+[self->createEquationsOptionsPopUpButton frame].size.width;
  x = ([self->parametersView frame].size.width-width)/2;
  rect = [self->createEquationsOptionsLabel frame];
  rect.origin.x = x;
  self->createEquationsOptionsLabel.frame = rect;
  rect = self->createEquationsOptionsPopUpButton.frame;
  rect.origin.x = NSMaxX(self->createEquationsOptionsLabel.frame)+4;
  self->createEquationsOptionsPopUpButton.frame = rect;
}
//end awakeFromNib

-(id)runWithInput:(id)input error:(NSError * _Nullable __autoreleasing *)errorInfo
{
  Boolean synchronized = CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
  DebugLog(1, @"synchronized = %d", synchronized);
  PreferencesController* preferencesController = [PreferencesController sharedController];

  NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:[input count]];

  NSDictionary* parameters = self.parameters;
  latex_mode_t equationMode = (latex_mode_t)[[parameters objectForKey:@"equationMode"] integerValue];
  CGFloat      fontSize     = [[parameters objectForKey:@"fontSize"] floatValue];
  NSData*      fontColorData = [parameters objectForKey:@"fontColorData"];
  NSColor*     fontColor      = !fontColorData ? [NSColor blackColor] : [NSColor colorWithData:fontColorData];
  equationDestination_t equationDestination = (equationDestination_t) [[parameters objectForKey:@"equationFilesDestination"] integerValue];
  NSString*    workingDirectory = [self workingDirectory];
  NSDictionary* fullEnvironment = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];
  export_format_t exportFormat = (export_format_t)[[parameters objectForKey:@"exportFormat"] integerValue];
  if ((NSInteger)exportFormat < 0)
    exportFormat = [preferencesController exportFormatPersistent];
  NSNumber* exportJpegQualityPercentAsNumber = [parameters objectForKey:@"exportJpegQualityPercent"];
  double   exportJpegQualityPercent = !exportJpegQualityPercentAsNumber ? 100. : [exportJpegQualityPercentAsNumber doubleValue];
  NSData*  exportJpegBackgroundColorData = [parameters objectForKey:@"exportJpegBackgroundColor"];
  NSColor* exportJpegBackgroundColor = !exportJpegBackgroundColorData ? [NSColor whiteColor] :
                                       [NSColor colorWithData:exportJpegBackgroundColorData];
  //NSColor* exportSvgPdfToSvgPath = [parameters objectForKey:@"exportSvgPdfToSvgPath"];
  BOOL exportTextExportPreamble = [[parameters[@"exportTextExportPreamble"] dynamicCastToClass:[NSNumber class]] boolValue];
  BOOL exportTextExportEnvironment = [[parameters[@"exportTextExportEnvironment"] dynamicCastToClass:[NSNumber class]] boolValue];
  BOOL exportTextExportBody = [[parameters[@"exportTextExportBody"] dynamicCastToClass:[NSNumber class]] boolValue];
  
  DebugLog(1, @"parameters = %@", parameters);
  DebugLog(1, @"equationMode = %d", equationMode);
  DebugLog(1, @"fontSize = %f", fontSize);

  CGFloat leftMargin   = preferencesController.marginsAdditionalLeft;
  CGFloat rightMargin  = preferencesController.marginsAdditionalRight;
  CGFloat bottomMargin = preferencesController.marginsAdditionalBottom;
  CGFloat topMargin    = preferencesController.marginsAdditionalTop;
  
  NSString* defaultPreamble = [preferencesController preambleDocumentAttributedString].string;
  
  // Add your code here, returning the data to be passed to the next action.
  NSMutableSet* uniqueIdentifiers = [[NSMutableSet alloc] init];
  NSFileManager* fileManager      = [NSFileManager defaultManager];
  NSSet*          inputAsSet      = [NSSet setWithArray:input];
  NSMutableArray* mutableInput    = [NSMutableArray arrayWithArray:input];
  NSMutableArray* filteredInput   = [NSMutableArray arrayWithCapacity:mutableInput.count];
  NSUInteger i = 0;
  for(i = 0 ; defaultPreamble && (i<mutableInput.count) ; ++i)
  {
    id object = mutableInput[i];
    NSURL* url = [object dynamicCastToClass:[NSURL class]];
    NSString* string = [object dynamicCastToClass:[NSString class]];
    if (url && url.fileURL)
      string = url.path;
    if (!string)
      [filteredInput addObject:object];
    else//if (string)
    {
      BOOL isDirectory = NO;
      if (![fileManager fileExistsAtPath:string isDirectory:&isDirectory])
        [filteredInput addObject:object];
      else//if path
      {
        if (!isDirectory)
        {//keep it if it is a file text
          NSString* sourceUTI = [[NSFileManager defaultManager] UTIFromPath:string];
          if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeFlatRTFD))
            [filteredInput addObject:object];
          else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeRTF))
            [filteredInput addObject:object];
          else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeText))
            [filteredInput addObject:object];
        }//end if (!isDirectory)
        else //if (isDirectory)
        {//if this folder was embedded in a previous folder,forget it. otherwise, explore it
          if ([inputAsSet containsObject:object])
          {
            NSError* error = nil;
            NSArray* directoryContent = [fileManager contentsOfDirectoryAtPath:string error:&error];
            NSEnumerator* fileEnumerator = [directoryContent objectEnumerator];
            NSString* filename = nil;
            while((filename = [fileEnumerator nextObject]))
              [mutableInput addObject:[string stringByAppendingPathComponent:filename]];
          }//end if root-level folder
        }//end if folder
      }//end if path
    }//end if string
  }//end for each input
  
  BOOL didEncounterError = NO;
  if (errorInfo && !defaultPreamble)
  {
    *errorInfo = [NSError errorWithDomain:AMAutomatorErrorDomain
                                     code:AMWorkflowPropertyListInvalidError
                                 userInfo:@{OSAScriptErrorNumber: @(errOSAGeneralError),
                                            OSAScriptErrorMessage: LocalLocalizedString(@"No preamble found", @"No preamble found"),
                                            AMActionErrorKey: self}];
  }//end if (errorInfo && !defaultPreamble)

  NSMutableArray* errorStrings = [NSMutableArray array];
  NSEnumerator* enumerator = [filteredInput objectEnumerator];
  id object = nil;
  while(defaultPreamble && (object = [enumerator nextObject]))
  {
    //NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
    NSString* preamble = nil;
    NSString* body     = nil;
    NSError*  error    = nil;
    BOOL      isInputFilePath = NO;
    NSString* uniqueIdentifierPrefix = [self extractFromObject:object preamble:&preamble body:&body isFilePath:&isInputFilePath error:&error];
    NSString* uniqueIdentifier = [uniqueIdentifierPrefix stringByReplacingOccurrencesOfRegex:@"\\s" withString:@"-"];
    unsigned long index = 1;
    while ([uniqueIdentifiers containsObject:uniqueIdentifier])
      uniqueIdentifier = [NSString stringWithFormat:@"%@-%lu", uniqueIdentifierPrefix, (unsigned long)++index];
    [uniqueIdentifiers addObject:uniqueIdentifier];
    if (!body && errorInfo && error)
    {
      *errorInfo = error;
      didEncounterError = YES;
    }//end if (!body && errorInfo && error)
    else if (body)
    {
      latex_mode_t latexMode = preamble ? LATEX_MODE_TEXT : equationMode;
      if (!preamble)
        preamble = defaultPreamble;
      NSString* outFullLog = nil;
      NSArray*  errors = nil;
      NSData*   pdfData = nil;
      DebugLog(1, @"compositionConfiguration = %@", [preferencesController compositionConfigurationDocument]);
      DebugLog(1, @"body = %@", body);
      DebugLog(1, @"fontColor = %@", fontColor);
      DebugLog(1, @"latexMode = %d", latexMode);
      DebugLog(1, @"fontSize = %f", fontSize);
      DebugLog(1, @"workingDirectory = %@", workingDirectory);
      DebugLog(1, @"fullEnvironment = %@", fullEnvironment);
      DebugLog(1, @"uniqueIdentifier = %ld", (unsigned long)uniqueIdentifier);
      NSString* outFilePath =
        [[LaTeXProcessor sharedLaTeXProcessor] latexiseWithPreamble:preamble body:body color:fontColor mode:latexMode magnification:fontSize
          compositionConfiguration:[preferencesController compositionConfigurationDocument] backgroundColor:nil
          title:nil
          leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin
          additionalFilesPaths:preferencesController.additionalFilesPaths
          workingDirectory:workingDirectory fullEnvironment:fullEnvironment uniqueIdentifier:uniqueIdentifier
          outFullLog:&outFullLog outErrors:&errors outPdfData:&pdfData];
      DebugLog(1, @"1outFilePath = %@", outFilePath);
      DebugLog(1, @"outFullLog = %@", outFullLog);
      DebugLog(1, @"errors = %@", errors);
      DebugLog(1, @"pdfData = %p (%lu)", pdfData, (unsigned long)[pdfData length]);
      DebugLog(1, @"exportFormat = %d", exportFormat);
      NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
        @(exportJpegQualityPercent), @"jpegQuality",
        @([preferencesController exportScalePercent]), @"scaleAsPercent",
        @([preferencesController exportIncludeBackgroundColor]), @"exportIncludeBackgroundColor",
        @(exportTextExportPreamble), @"textExportPreamble",
        @(exportTextExportEnvironment), @"textExportEnvironment",
        @(exportTextExportBody), @"textExportBody",
        exportJpegBackgroundColor, @"jpegColor",//at the end for the case it is null
        nil];
      NSData* convertedData = [[LaTeXProcessor sharedLaTeXProcessor]
        dataForType:exportFormat
            pdfData:pdfData
        exportOptions:exportOptions
         compositionConfiguration:preferencesController.compositionConfigurationDocument
                 uniqueIdentifier:uniqueIdentifier];
      DebugLog(1, @"convertedData = %p (%lu)", convertedData, (unsigned long)[convertedData length]);
      if (convertedData)
      {
        NSString* extension = nil;
        switch(exportFormat)
        {
          case EXPORT_FORMAT_PDF:
          case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
            extension = @"pdf";
            break;
          case EXPORT_FORMAT_EPS:
            extension = @"eps";
            break;
          case EXPORT_FORMAT_TIFF:
            extension = @"tiff";
            break;
          case EXPORT_FORMAT_PNG:
            extension = @"png";
            break;
          case EXPORT_FORMAT_JPEG:
            extension = @"jpeg";
            break;
          case EXPORT_FORMAT_MATHML:
            extension = @"html";
            break;
          case EXPORT_FORMAT_SVG:
            extension = @"svg";
            break;
          case EXPORT_FORMAT_TEXT:
            extension = @"tex";
            break;
        }
        NSString* outFilePath2 = [outFilePath.stringByDeletingPathExtension stringByAppendingPathExtension:extension];
        DebugLog(1, @"outFilePath2 = %@", outFilePath2);
        if (![outFilePath2 isEqualToString:outFilePath])
        {
          if ([convertedData writeToFile:outFilePath2 atomically:YES])
            outFilePath = outFilePath2;
          DebugLog(1, @"+outFilePath = %@", outFilePath);
        }//end if (![outFilePath2 isEqualToString:outFilePath])
      }//end if (convertedData)

      DebugLog(1, @"outFilePath = %@, errors = %@", outFilePath, errors);
      if (outFilePath && !errors.count)
      {
        if (isInputFilePath && (equationDestination == EQUATION_DESTINATION_ALONGSIDE_INPUT))
        {
          NSString* destinationFolder = [object stringByDeletingLastPathComponent];
          NSString* newPath = [destinationFolder stringByAppendingPathComponent:outFilePath.lastPathComponent];
          NSError* error = nil;
          if (![outFilePath isEqualToString:newPath])
          {
            BOOL moved = [fileManager moveItemAtPath:outFilePath toPath:newPath error:&error];
            if (moved)
              outFilePath = newPath;
            else//if (!moved)
            {
              BOOL removed = [fileManager removeItemAtPath:newPath error:&error];
              BOOL moved = [fileManager moveItemAtPath:outFilePath toPath:newPath error:&error];
              if (removed && moved)
                outFilePath = newPath;
            }//end //if (!moved)
            DebugLog(1, @"moved = %d, outFilePath = %@", moved, outFilePath);
          }//end if (![outFilePath isEqualToString:newPath])
        }
        [fileManager setAttributes:@{NSFileHFSCreatorCode:@((OSType)'LTXt')} ofItemAtPath:outFilePath error:0];
        if ((exportFormat != EXPORT_FORMAT_PNG) &&
            (exportFormat != EXPORT_FORMAT_TIFF) &&
            (exportFormat != EXPORT_FORMAT_JPEG))
          [[NSWorkspace sharedWorkspace] setIcon:[[LaTeXProcessor sharedLaTeXProcessor] makeIconForData:pdfData backgroundColor:nil]
                                         forFile:outFilePath options:NSExclude10_4ElementsIconCreationOption];
        [result addObject:outFilePath];
      }
      else
      {
        NSArray* latexErrors = 
          [[LaTeXProcessor sharedLaTeXProcessor] filterLatexErrors:outFullLog shiftLinesBy:[preamble componentsSeparatedByString:@"\n"].count+1];
        didEncounterError = YES;
        NSString* errorMessage = [latexErrors count] ? [latexErrors componentsJoinedByString:@"\n"] :
          LocalLocalizedString(@"Unknown error. Please make sure that LaTeXiT has been run once and is fully functional.", @"");
        [errorStrings safeAddObject:errorMessage];
      }
    }//end if (!body)
    //[ap drain];
  }//end or each object
  if (didEncounterError && errorStrings.count && errorInfo)
  {
    *errorInfo = [NSError errorWithDomain:AMAutomatorErrorDomain
                                     code:AMConversionFailedError
                                 userInfo:@{OSAScriptErrorNumber: @(errOSAGeneralError),
                                            OSAScriptErrorMessage: [errorStrings componentsJoinedByString:@"\n"],
                                            AMActionErrorKey: self}];
    if (*errorInfo)
      DebugLog(0, @"%@", (*errorInfo).userInfo[OSAScriptErrorMessage]);
  }//end if (didEncounterError && [errorStrings count] && errorInfo)
  return result;
}
//end runWithInput:error:

-(NSString*) extractFromObject:(id)object preamble:(NSString**)outPeamble body:(NSString**)outBody isFilePath:(BOOL*)isFilePath
                         error:(NSError**)error
{
  NSString* result = nil;
  NSString* fullText = nil;
  
  //extract fullText
  if ([object isKindOfClass:[NSAttributedString class]])
  {
    fullText = [object string];
    result = [NSString stringWithFormat:@"latexit-automator-%lu", (unsigned long)++self->uniqueId];
  }//end if ([object isKindOfClass:[NSString class]])
  else if ([object isKindOfClass:[NSString class]])
  {
    BOOL isDirectory = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:object isDirectory:&isDirectory])
    {//path
      if (isFilePath)
        *isFilePath = !isDirectory;
      NSString* sourceUTI = [[NSFileManager defaultManager] UTIFromPath:object];
      NSData* fileData = [[NSData alloc] initWithContentsOfFile:object options:NSUncachedRead error:error];
      if (error && *error)
        {DebugLog(0, @"error: %@", *error);}
      NSStringEncoding encoding = NSUTF8StringEncoding;
      if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeFlatRTFD))
      {
        NSAttributedString* attributedString =
          [[NSAttributedString alloc] initWithRTFD:fileData documentAttributes:0];
        fullText = attributedString.string;
      }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeFlatRTFD))
      else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeRTF))
      {
        NSAttributedString* attributedString =
          [[NSAttributedString alloc] initWithRTF:fileData documentAttributes:0];
        fullText = attributedString.string;
      }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeRTF))
      else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeText))
        fullText = [NSString stringWithContentsOfFile:object guessEncoding:&encoding error:error];
      result = [NSString stringWithFormat:@"latexit-automator-%lu", (unsigned long)++self->uniqueId];
    }//end if ([[NSFileManager defaultManager] fileExistsAtPath:object isDirectory:&isDirectory])
    else //(if !path)
    {
      fullText = object;
      result = [NSString stringWithFormat:@"latexit-automator-%lu", (unsigned long)++self->uniqueId];
    }
  }//end if ([object isKindOfClass:[NSString class]])
  else if ([object isKindOfClass:[NSURL class]])
  {
    NSString* sourceUTI = [[NSFileManager defaultManager] UTIFromPath:object];
    NSData* fileData = [[NSData alloc] initWithContentsOfURL:object options:NSUncachedRead error:error];
    if (error && *error)
      {DebugLog(0, @"error: %@", *error);}
    NSStringEncoding encoding = NSUTF8StringEncoding;
    if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeFlatRTFD))
    {
      NSAttributedString* attributedString =
        [[NSAttributedString alloc] initWithRTFD:fileData documentAttributes:0];
      fullText = attributedString.string;
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeFlatRTFD))
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeRTF))
    {
      NSAttributedString* attributedString =
        [[NSAttributedString alloc] initWithRTF:fileData documentAttributes:0];
      fullText = attributedString.string;
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeRTF))
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeText))
      fullText = [NSString stringWithContentsOfURL:object guessEncoding:&encoding error:error];
    result = [NSString stringWithFormat:@"latexit-automator-%lu", (unsigned long)++self->uniqueId];
  }//end if ([object isKindOfClass:[NSURL class]])

  //analyze fullText
  if (fullText)
  {
    NSError* error = nil;
    NSString* preamble =
      [fullText stringByMatching:@"(.*)[^%\n]*\\\\begin\\{document\\}(.*)[^%\n]*\\\\end\\{document\\}(.*)" options:RKLMultiline|RKLDotAll
        inRange:NSMakeRange(0, fullText.length) capture:1 error:&error];
    NSString* body =
      [fullText stringByMatching:@"(.*)[^%\n]*\\\\begin\\{document\\}(.*)[^%\n]*\\\\end\\{document\\}(.*)" options:RKLMultiline|RKLDotAll
        inRange:NSMakeRange(0, fullText.length) capture:2 error:&error];
    if ((!preamble || !preamble.length) && (!body || !body.length))
      body = fullText;
    if (!body)     body     = @"";
    if (outPeamble) *outPeamble = preamble;
    if (outBody)    *outBody = body;
  }//end if (fullText)
  return result;
}
//end extractFromObject:preamble:body:

-(IBAction) nilAction:(id)sender
{
  //useful for validateMenuItem:
}
//end nilAction:

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok  = YES;
  PreferencesController* preferencesController = [PreferencesController sharedController];
  CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
  if (sender.tag == EXPORT_FORMAT_EPS)
    ok = [[NSFileManager defaultManager] isExecutableFileAtPath:[preferencesController.compositionConfigurationDocument compositionConfigurationProgramPathGs]];
  else if (sender.tag == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [[NSFileManager defaultManager] isExecutableFileAtPath:[preferencesController.compositionConfigurationDocument compositionConfigurationProgramPathGs]] &&
         [[NSFileManager defaultManager] isExecutableFileAtPath:[preferencesController.compositionConfigurationDocument compositionConfigurationProgramPathPsToPdf]];
  /*else if ([sender tag] == EXPORT_FORMAT_SVG)
    ok = [[NSFileManager defaultManager] isExecutableFileAtPath:[preferencesController exportSvgPdfToSvgPath]];*/
  return ok;
}
//end validateMenuItem:

-(IBAction) generalExportFormatOptionsOpen:(id)sender
{
  if (!self->generalExportFormatOptionsPanes)
  {
    self->generalExportFormatOptionsPanes = [[ExportFormatOptionsPanes alloc] initWithLoadingFromNib];
    self->generalExportFormatOptionsPanes.exportFormatOptionsJpegPanelDelegate = self;
    self->generalExportFormatOptionsPanes.exportFormatOptionsSvgPanelDelegate = self;
    self->generalExportFormatOptionsPanes.exportFormatOptionsTextPanelDelegate = self;
  }//end if (!self->generalExportFormatOptionsPanes)
  self->generalExportFormatOptionsPanes.jpegQualityPercent = [self.parameters[@"exportJpegQualityPercent"] doubleValue];
  self->generalExportFormatOptionsPanes.jpegBackgroundColor = [NSColor colorWithData:self.parameters[@"exportJpegBackgroundColor"]];
  self->generalExportFormatOptionsPanes.svgPdfToSvgPath = self.parameters[@"exportSvgPdfToSvgPath"];
  self->generalExportFormatOptionsPanes.textExportPreamble = [[self.parameters[@"exportTextExportPreamble"] dynamicCastToClass:[NSNumber class]] boolValue];
  self->generalExportFormatOptionsPanes.textExportEnvironment = [[self.parameters[@"exportTextExportEnvironment"] dynamicCastToClass:[NSNumber class]] boolValue];
  self->generalExportFormatOptionsPanes.textExportBody = [[self.parameters[@"exportTextExportBody"] dynamicCastToClass:[NSNumber class]] boolValue];
  self->generalExportFormatOptionsPanes.pdfWofGSWriteEngine = [self.parameters[@"pdfWofGSWriteEngine"] dynamicCastToClass:[NSString class]];
  self->generalExportFormatOptionsPanes.pdfWofGSPDFCompatibilityLevel = [self.parameters[@"pdfWofGSPDFCompatibilityLevel"] dynamicCastToClass:[NSString class]];
  self->generalExportFormatOptionsPanes.pdfWofMetaDataInvisibleGraphicsEnabled = [[self.parameters[@"pdfWofMetaDataInvisibleGraphicsEnabled"] dynamicCastToClass:[NSNumber class]] boolValue];
  NSPanel* panelToOpen = nil;
  export_format_t exportFormat = (export_format_t)[self->exportFormatPopupButton selectedTag];
  if (exportFormat == EXPORT_FORMAT_JPEG)
    panelToOpen = self->generalExportFormatOptionsPanes.exportFormatOptionsJpegPanel;
  else if (exportFormat == EXPORT_FORMAT_SVG)
    panelToOpen = self->generalExportFormatOptionsPanes.exportFormatOptionsSvgPanel;
  if (panelToOpen) {
    [tabView.window beginSheet:panelToOpen completionHandler:^(NSModalResponse returnCode) {
      
    }];
  }
}
//end generalExportFormatOptionsOpen:

-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok
{
  if (ok)
  {
    if (exportFormatOptionsPanel == self->generalExportFormatOptionsPanes.exportFormatOptionsJpegPanel)
    {
      self.parameters[@"exportJpegQualityPercent"] = @([self->generalExportFormatOptionsPanes jpegQualityPercent]);
      self.parameters[@"exportJpegBackgroundColor"] = [self->generalExportFormatOptionsPanes.jpegBackgroundColor colorAsData];
    }//end if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    else if (exportFormatOptionsPanel == self->generalExportFormatOptionsPanes.exportFormatOptionsSvgPanel)
    {
      self.parameters[@"exportSvgPdfToSvgPath"] = self->generalExportFormatOptionsPanes.svgPdfToSvgPath;
    }//end if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    else if (exportFormatOptionsPanel == self->generalExportFormatOptionsPanes.exportFormatOptionsTextPanel)
    {
      self.parameters[@"exportTextExportPreamble"] = @(self->generalExportFormatOptionsPanes.textExportPreamble);
      self.parameters[@"exportTextExportEnvironment"] = @(self->generalExportFormatOptionsPanes.textExportEnvironment);
      self.parameters[@"exportTextExportBody"] = @(self->generalExportFormatOptionsPanes.textExportBody);
    }//end if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsSvgPanel])
  }//end if (ok)
  [tabView.window endSheet:exportFormatOptionsPanel];
  [exportFormatOptionsPanel orderOut:self];
}
//end exportFormatOptionsPanel:didCloseWithOK:

@end
