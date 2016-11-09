//
//  Automator_CreateEquations.m
//  Automator_CreateEquations
//
//  Created by Pierre Chatelier on 24/09/08.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
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
        int debugLogLevelShift = 0;
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
        
        
        const NSUInteger legacyNSNotFound = 0x7fffffff;
        NSUInteger notFound = isMacOS10_5OrAbove() ? NSNotFound : legacyNSNotFound;
        if (!freeIds)
          freeIds = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(1, notFound-2)];
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
    result = [freeIds firstIndex];
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
    [fileManager bridge_removeItemAtPath:temporaryPath error:0];
    exists = NO;
  }
  if (!exists)
    [fileManager bridge_createDirectoryAtPath:temporaryPath withIntermediateDirectories:YES attributes:nil error:0];
  return temporaryPath;
}
//end workingDirectory

-(id) initWithDefinition:(NSDictionary*)dict fromArchive:(BOOL)archived
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
  #ifdef ARC_ENABLED
  #else
  [super dealloc];
  #endif
}
//end dealloc

-(void) opened
{
  if (!self->fromArchive) //init from latexit preferences
  {
    NSMutableDictionary* dict = [self parameters];
    PreferencesController* preferencesController = [PreferencesController sharedController];
    CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
    NSString* latexitVersion = [preferencesController latexitVersion];
    self->latexitPreferencesAvailable = latexitVersion && ![latexitVersion isEqualToString:@""];
    
    [self->tabView selectTabViewItemWithIdentifier:self->latexitPreferencesAvailable ?
      @"parameters" : @"warning"];
    
    latex_mode_t equationMode = [preferencesController latexisationLaTeXMode];
    if (equationMode == LATEX_MODE_AUTO)
      equationMode = LATEX_MODE_ALIGN;
    [self->exportFormatPopupButton selectItemWithTag:[preferencesController exportFormatPersistent]];
    CGFloat      fontSize       = [preferencesController latexisationFontSize];
    NSData*      fontColorData  = [preferencesController latexisationFontColorData];
    CGFloat exportJpegQualityPercent = [preferencesController exportJpegQualityPercent];
    NSData* exportJpegBackgroundColorAsData = [preferencesController exportJpegBackgroundColorData];
    NSString* exportSvgPdfToSvgPath = [preferencesController exportSvgPdfToSvgPath];
    BOOL exportTextExportPreamble = [preferencesController exportTextExportPreamble];
    BOOL exportTextExportEnvironment = [preferencesController exportTextExportEnvironment];
    BOOL exportTextExportBody = [preferencesController exportTextExportBody];
    [dict setObject:[NSNumber numberWithInt:equationMode] forKey:@"equationMode"];
    [dict setObject:[NSNumber numberWithFloat:fontSize] forKey:@"fontSize"];
    [dict setObject:[NSNumber numberWithInt:equationMode] forKey:@"equationMode"];
    [dict setObject:[NSNumber numberWithFloat:fontSize] forKey:@"fontSize"];
    [dict setObject:[NSNumber numberWithDouble:exportJpegQualityPercent] forKey:@"exportJpegQualityPercent"];
    [dict setObject:exportJpegBackgroundColorAsData forKey:@"exportJpegBackgroundColor"];
    [dict setObject:exportSvgPdfToSvgPath forKey:@"exportSvgPdfToSvgPath"];
    [dict setObject:[NSNumber numberWithBool:exportTextExportPreamble] forKey:@"exportTextExportPreamble"];
    [dict setObject:[NSNumber numberWithBool:exportTextExportEnvironment] forKey:@"exportTextExportEnvironment"];
    [dict setObject:[NSNumber numberWithBool:exportTextExportBody] forKey:@"exportTextExportBody"];
    if (fontColorData)
      [dict setObject:fontColorData forKey:@"fontColorData"];
    [self setParameters:dict];
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
  [self->warningMessage setStringValue:LocalLocalizedString(@"You must run LaTeXiT once, to init the configuration",
                                                            @"You must run LaTeXiT once, to init the configuration")];

  [[self->latexModeSegmentedControl cell] setTag:LATEX_MODE_ALIGN   forSegment:0];
  [[self->latexModeSegmentedControl cell] setTag:LATEX_MODE_DISPLAY forSegment:1];
  [[self->latexModeSegmentedControl cell] setTag:LATEX_MODE_INLINE  forSegment:2];
  [[self->latexModeSegmentedControl cell] setTag:LATEX_MODE_TEXT    forSegment:3];
  [[self->latexModeSegmentedControl cell] setLabel:LocalLocalizedString(@"Align", @"Align") forSegment:0];
  [[self->latexModeSegmentedControl cell] setLabel:LocalLocalizedString(@"Text", @"Text") forSegment:3];

  NSRect rect = NSZeroRect;
  CGFloat x = 0;
  CGFloat width = 0;
  rect = [self->parametersView frame];
  rect.origin.x = 20;
  rect.size.width = [[self->parametersView superview] frame].size.width-2*rect.origin.x;
  [self->parametersView setFrame:rect];
  
  [self->fontSizeLabel  setStringValue:LocalLocalizedString(@"Font size :", @"Font size :")];
  [self->fontSizeLabel sizeToFit];
  [self->fontColorLabel setStringValue:LocalLocalizedString(@"Color :", @"Color :")];
  [self->fontColorLabel sizeToFit];

  [self->exportFormatPopupButton removeAllItems];
/*  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"Default format", @"Default format")
                                              tag:-1];*/
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"PDF vector format", @"PDF vector format")
                                              tag:(int)EXPORT_FORMAT_PDF];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"PDF with outlined fonts", @"PDF with outlined fonts")
                                              tag:(int)EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"EPS vector format", @"EPS vector format")
                                              tag:(int)EXPORT_FORMAT_EPS];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"SVG vector format", @"SVG vector format")
                                              tag:(int)EXPORT_FORMAT_SVG];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"TIFF bitmap format", @"TIFF bitmap format")
                                              tag:(int)EXPORT_FORMAT_PNG];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"PNG bitmap format", @"PNG bitmap format")
                                              tag:(int)EXPORT_FORMAT_TIFF];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"JPEG bitmap format", @"JPEG bitmap format")
                                              tag:(int)EXPORT_FORMAT_JPEG];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"MathML text format", @"MathML text format")
                                              tag:(int)EXPORT_FORMAT_MATHML];
  [self->exportFormatPopupButton addItemWithTitle:LocalLocalizedString(@"Text format", @"Text format")
                                              tag:(int)EXPORT_FORMAT_TEXT];
  [self->exportFormatPopupButton setTarget:self];
  [self->exportFormatPopupButton setAction:@selector(nilAction:)];
  [self->exportFormatPopupButton sizeToFit];

  [self->exportFormatOptionsButton setTitle:[NSString stringWithFormat:@"%@...", LocalLocalizedString(@"Options", @"Options")]];
  [self->exportFormatOptionsButton sizeToFit];
  [self->exportFormatOptionsButton bind:NSEnabledBinding toObject:self withKeyPath:@"parameters.exportFormat" options:
    [NSDictionary dictionaryWithObjectsAndKeys:
      [IsInTransformer transformerWithReferences:
        [NSArray arrayWithObjects:[NSNumber numberWithInt:EXPORT_FORMAT_JPEG], [NSNumber numberWithInt:EXPORT_FORMAT_SVG], nil]],
      NSValueTransformerBindingOption,
      nil]];

  NSRect superFrame = [[self->exportFormatPopupButton superview] frame];
  NSRect frame = NSZeroRect;
  frame = [self->exportFormatOptionsButton frame];
  frame.origin.x = superFrame.size.width-frame.size.width-2;
  [self->exportFormatOptionsButton setFrame:frame];
  frame = [self->exportFormatPopupButton frame];
  frame.origin.x = NSMinX([self->exportFormatOptionsButton frame])-4-frame.size.width;
  [self->exportFormatPopupButton setFrame:frame];
  
  [self->createEquationsOptionsLabel setStringValue:LocalLocalizedString(@"Create equations :", @"Create equations :")];
  [self->createEquationsOptionsLabel sizeToFit];
  [self->createEquationsOptionsPopUpButton removeAllItems];
  [self->createEquationsOptionsPopUpButton addItemWithTitle:LocalLocalizedString(@"alongside input files", @"alongside input files")
                                                        tag:EQUATION_DESTINATION_ALONGSIDE_INPUT];
  [self->createEquationsOptionsPopUpButton addItemWithTitle:LocalLocalizedString(@"in a temporary folder", @"in a temporary folder")
                                                        tag:EQUATION_DESTINATION_TEMPORARY_FOLDER];
  [self->createEquationsOptionsPopUpButton sizeToFit];
  
  width =
    [self->fontSizeLabel frame].size.width+4+[self->fontSizeTextField frame].size.width+4+[self->fontSizeStepper frame].size.width+
    20+
    [self->fontColorLabel frame].size.width+4+[self->fontColorWell frame].size.width;
  x = ([self->parametersView frame].size.width-width)/2;

  rect = [self->fontSizeLabel frame];
  rect.origin.x = x;
  [self->fontSizeLabel setFrame:rect];
  rect = [self->fontSizeTextField frame];
  rect.origin.x = NSMaxX([self->fontSizeLabel frame])+4;
  [self->fontSizeTextField setFrame:rect];
  rect = [self->fontSizeStepper frame];
  rect.origin.x = NSMaxX([self->fontSizeTextField frame])+4;
  [self->fontSizeStepper setFrame:rect];
  rect = [self->fontColorLabel frame];
  rect.origin.x = NSMaxX([self->fontSizeStepper frame])+20;
  [self->fontColorLabel setFrame:rect];
  rect = [self->fontColorWell frame];
  rect.origin.x = NSMaxX([self->fontColorLabel frame])+4;
  [self->fontColorWell setFrame:rect];
  
  width = [self->exportFormatPopupButton frame].size.width;
  x = ([self->parametersView frame].size.width-width)/2;
  rect = [self->exportFormatPopupButton frame];
  rect.origin.x = x;
  [self->exportFormatPopupButton setFrame:rect];
  rect = [self->exportFormatOptionsButton frame];
  rect.origin.x = NSMaxX([self->exportFormatPopupButton frame])+10;
  [self->exportFormatOptionsButton setFrame:rect];

  width = [self->createEquationsOptionsLabel frame].size.width+4+[self->createEquationsOptionsPopUpButton frame].size.width;
  x = ([self->parametersView frame].size.width-width)/2;
  rect = [self->createEquationsOptionsLabel frame];
  rect.origin.x = x;
  [self->createEquationsOptionsLabel setFrame:rect];
  rect = [self->createEquationsOptionsPopUpButton frame];
  rect.origin.x = NSMaxX([self->createEquationsOptionsLabel frame])+4;
  [self->createEquationsOptionsPopUpButton setFrame:rect];
}
//end awakeFromNib

-(id) runWithInput:(id)input fromAction:(AMAction*)anAction error:(NSDictionary**)errorInfo
{
  Boolean synchronized = CFPreferencesAppSynchronize((CFStringRef)LaTeXiTAppKey);
  DebugLog(1, @"synchronized = %d", synchronized);
  PreferencesController* preferencesController = [PreferencesController sharedController];

  NSMutableArray* result = [[NSMutableArray alloc] initWithCapacity:[input count]];
  #ifdef ARC_ENABLED
  #else
  [result autorelease];
  #endif

  NSDictionary* parameters = [self parameters];
  latex_mode_t equationMode = (latex_mode_t)[[parameters objectForKey:@"equationMode"] intValue];
  CGFloat      fontSize     = [[parameters objectForKey:@"fontSize"] floatValue];
  NSData*      fontColorData = [parameters objectForKey:@"fontColorData"];
  NSColor*     fontColor      = !fontColorData ? [NSColor blackColor] : [NSColor colorWithData:fontColorData];
  equationDestination_t equationDestination = (equationDestination_t) [[parameters objectForKey:@"equationFilesDestination"] intValue];
  NSString*    workingDirectory = [self workingDirectory];
  NSDictionary* fullEnvironment = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];
  export_format_t exportFormat = (export_format_t)[[parameters objectForKey:@"exportFormat"] intValue];
  if ((int)exportFormat < 0)
    exportFormat = [preferencesController exportFormatPersistent];
  NSNumber* exportJpegQualityPercentAsNumber = [parameters objectForKey:@"exportJpegQualityPercent"];
  double   exportJpegQualityPercent = !exportJpegQualityPercentAsNumber ? 100. : [exportJpegQualityPercentAsNumber doubleValue];
  NSData*  exportJpegBackgroundColorData = [parameters objectForKey:@"exportJpegBackgroundColor"];
  NSColor* exportJpegBackgroundColor = !exportJpegBackgroundColorData ? [NSColor whiteColor] :
                                       [NSColor colorWithData:exportJpegBackgroundColorData];
  //NSColor* exportSvgPdfToSvgPath = [parameters objectForKey:@"exportSvgPdfToSvgPath"];
  BOOL exportTextExportPreamble = [[[parameters objectForKey:@"exportTextExportPreamble"] dynamicCastToClass:[NSNumber class]] boolValue];
  BOOL exportTextExportEnvironment = [[[parameters objectForKey:@"exportTextExportEnvironment"] dynamicCastToClass:[NSNumber class]] boolValue];
  BOOL exportTextExportBody = [[[parameters objectForKey:@"exportTextExportBody"] dynamicCastToClass:[NSNumber class]] boolValue];
  
  DebugLog(1, @"parameters = %@", parameters);
  DebugLog(1, @"equationMode = %d", equationMode);
  DebugLog(1, @"fontSize = %f", fontSize);

  CGFloat leftMargin   = [preferencesController marginsAdditionalLeft];
  CGFloat rightMargin  = [preferencesController marginsAdditionalRight];
  CGFloat bottomMargin = [preferencesController marginsAdditionalBottom];
  CGFloat topMargin    = [preferencesController marginsAdditionalTop];
  
  NSString* defaultPreamble = [[preferencesController preambleDocumentAttributedString] string];
  
	// Add your code here, returning the data to be passed to the next action.
  NSMutableSet* uniqueIdentifiers = [[NSMutableSet alloc] init];
  NSFileManager* fileManager      = [NSFileManager defaultManager];
  NSSet*          inputAsSet      = [NSSet setWithArray:input];
  NSMutableArray* mutableInput    = [NSMutableArray arrayWithArray:input];
  NSMutableArray* filteredInput   = [NSMutableArray arrayWithCapacity:[mutableInput count]];
  unsigned int i = 0;
  for(i = 0 ; defaultPreamble && (i<[mutableInput count]) ; ++i)
  {
    id object = [mutableInput objectAtIndex:i];
    NSURL* url = [object dynamicCastToClass:[NSURL class]];
    NSString* string = [object dynamicCastToClass:[NSString class]];
    if (url && [url isFileURL])
      string = [url path];
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
          #ifdef ARC_ENABLED
          if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, CFSTR("com.apple.flat-rtfd")))
            [filteredInput addObject:object];
          else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, CFSTR("public.rtf")))
            [filteredInput addObject:object];
          else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, CFSTR("public.text")))
            [filteredInput addObject:object];
          #else
          if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("com.apple.flat-rtfd")))
            [filteredInput addObject:object];
          else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.rtf")))
            [filteredInput addObject:object];
          else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.text")))
            [filteredInput addObject:object];
          #endif
        }//end if (!isDirectory)
        else //if (isDirectory)
        {//if this folder was embedded in a previous folder,forget it. otherwise, explore it
          if ([inputAsSet containsObject:object])
          {
            NSError* error = nil;
            NSArray* directoryContent = [fileManager bridge_contentsOfDirectoryAtPath:string error:&error];
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
    #ifdef ARC_ENABLED
    *errorInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
      [NSNumber numberWithInt:errOSAGeneralError], OSAScriptErrorNumber,
      LocalLocalizedString(@"No preamble found", @"No preamble found"), OSAScriptErrorMessage,
      nil];
    #else
    *errorInfo = [[[NSDictionary alloc] initWithObjectsAndKeys:
      [NSNumber numberWithInt:errOSAGeneralError], OSAScriptErrorNumber,
      LocalLocalizedString(@"No preamble found", @"No preamble found"), OSAScriptErrorMessage,
      nil] autorelease];
    #endif
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
    if (!body && errorInfo)
    {
      #ifdef ARC_ENABLED
      *errorInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt:errOSAGeneralError], OSAScriptErrorNumber,
        [error localizedDescription], OSAScriptErrorMessage,
        nil];
      #else
      *errorInfo = [[[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithInt:errOSAGeneralError], OSAScriptErrorNumber,
        [error localizedDescription], OSAScriptErrorMessage,
        nil] autorelease];
      #endif
      didEncounterError = YES;
    }//end if (!body && errorInfo)
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
          leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin
          additionalFilesPaths:[preferencesController additionalFilesPaths]
          workingDirectory:workingDirectory fullEnvironment:fullEnvironment uniqueIdentifier:uniqueIdentifier
          outFullLog:&outFullLog outErrors:&errors outPdfData:&pdfData];
      DebugLog(1, @"1outFilePath = %@", outFilePath);
      DebugLog(1, @"outFullLog = %@", outFullLog);
      DebugLog(1, @"errors = %@", errors);
      DebugLog(1, @"pdfData = %p (%ld)", pdfData, [pdfData length]);
      DebugLog(1, @"exportFormat = %d", exportFormat);
      NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithFloat:exportJpegQualityPercent], @"jpegQuality",
        [NSNumber numberWithFloat:[preferencesController exportScalePercent]], @"scaleAsPercent",
        [NSNumber numberWithBool:exportTextExportPreamble], @"textExportPreamble",
        [NSNumber numberWithBool:exportTextExportEnvironment], @"textExportEnvironment",
        [NSNumber numberWithBool:exportTextExportBody], @"textExportBody",
        exportJpegBackgroundColor, @"jpegColor",//at the end for the case it is null
        nil];
      NSData* convertedData = [[LaTeXProcessor sharedLaTeXProcessor]
        dataForType:exportFormat
            pdfData:pdfData
        exportOptions:exportOptions
         compositionConfiguration:[preferencesController compositionConfigurationDocument]
                 uniqueIdentifier:uniqueIdentifier];
      DebugLog(1, @"convertedData = %p (%ld)", convertedData, [convertedData length]);
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
        NSString* outFilePath2 = [[outFilePath stringByDeletingPathExtension] stringByAppendingPathExtension:extension];
        DebugLog(1, @"outFilePath2 = %@", outFilePath2);
        if (![outFilePath2 isEqualToString:outFilePath])
        {
          if ([convertedData writeToFile:outFilePath2 atomically:YES])
            outFilePath = outFilePath2;
          DebugLog(1, @"+outFilePath = %@", outFilePath);
        }//end if (![outFilePath2 isEqualToString:outFilePath])
      }//end if (convertedData)

      DebugLog(1, @"outFilePath = %@, errors = %@", outFilePath, errors);
      if (outFilePath && ![errors count])
      {
        if (isInputFilePath && (equationDestination == EQUATION_DESTINATION_ALONGSIDE_INPUT))
        {
          NSString* destinationFolder = [object stringByDeletingLastPathComponent];
          NSString* newPath = [destinationFolder stringByAppendingPathComponent:[outFilePath lastPathComponent]];
          NSError* error = nil;
          if (![outFilePath isEqualToString:newPath])
          {
            BOOL moved = [fileManager bridge_moveItemAtPath:outFilePath toPath:newPath error:&error];
            if (moved)
              outFilePath = newPath;
            else//if (!moved)
            {
              BOOL removed = [fileManager bridge_removeItemAtPath:newPath error:&error];
              BOOL moved = [fileManager bridge_moveItemAtPath:outFilePath toPath:newPath error:&error];
              if (removed && moved)
                outFilePath = newPath;
            }//end //if (!moved)
            DebugLog(1, @"moved = %d, outFilePath = %@", moved, outFilePath);
          }//end if (![outFilePath isEqualToString:newPath])
        }
        [fileManager bridge_setAttributes:
          [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt'] forKey:NSFileHFSCreatorCode]
                                ofItemAtPath:outFilePath error:0];
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
          [[LaTeXProcessor sharedLaTeXProcessor] filterLatexErrors:outFullLog shiftLinesBy:[[preamble componentsSeparatedByString:@"\n"] count]+1];
        didEncounterError = YES;
        NSString* errorMessage = [latexErrors count] ? [latexErrors componentsJoinedByString:@"\n"] :
          LocalLocalizedString(@"Unknown error. Please make sure that LaTeXiT has been run once and is fully functional.",
                               @"Unknown error. Please make sure that LaTeXiT has been run once and is fully functional.");
        [errorStrings safeAddObject:errorMessage];
      }
    }//end if (!body)
    //[ap drain];
  }//end or each object
  if (didEncounterError && [errorStrings count] && errorInfo)
  {
    #ifdef ARC_ENABLED
    *errorInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                   [NSNumber numberWithInt:errOSAGeneralError], OSAScriptErrorNumber,
                   [errorStrings componentsJoinedByString:@"\n"], OSAScriptErrorMessage,
                   nil];
    #else
    *errorInfo = [[[NSDictionary alloc] initWithObjectsAndKeys:
                   [NSNumber numberWithInt:errOSAGeneralError], OSAScriptErrorNumber,
                   [errorStrings componentsJoinedByString:@"\n"], OSAScriptErrorMessage,
                   nil] autorelease];
    #endif
    if (*errorInfo)
      DebugLog(0, @"%@", [*errorInfo objectForKey:OSAScriptErrorMessage]);
  }//end if (didEncounterError && [errorStrings count] && errorInfo)
  #ifdef ARC_ENABLED
  #else
  [uniqueIdentifiers release];
  #endif
	return result;
}
//end runWithInput:fromAction:error:

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
      #ifdef ARC_ENABLED
      if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, CFSTR("com.apple.flat-rtfd")))
      #else
      if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("com.apple.flat-rtfd")))
      #endif
      {
        NSAttributedString* attributedString =
          [[NSAttributedString alloc] initWithRTFD:fileData documentAttributes:0];
        fullText = [attributedString string];
        #ifdef ARC_ENABLED
        #else
        [attributedString release];
        #endif
      }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("com.apple.flat-rtfd")))
      #ifdef ARC_ENABLED
      else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, CFSTR("public.rtf")))
      #else
      else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.rtf")))
      #endif
      {
        NSAttributedString* attributedString =
          [[NSAttributedString alloc] initWithRTF:fileData documentAttributes:0];
        fullText = [attributedString string];
        #ifdef ARC_ENABLED
        #else
        [attributedString release];
        #endif
      }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.rtf")))
      #ifdef ARC_ENABLED
      else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, CFSTR("public.text")))
      #else
      else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.text")))
      #endif
        fullText = [NSString stringWithContentsOfFile:object guessEncoding:&encoding error:error];
      result = [NSString stringWithFormat:@"latexit-automator-%lu", (unsigned long)++self->uniqueId];
      #ifdef ARC_ENABLED
      #else
      [fileData release];
      #endif
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
    #ifdef ARC_ENABLED
    if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, CFSTR("com.apple.flat-rtfd")))
    #else
    if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("com.apple.flat-rtfd")))
    #endif
    {
      NSAttributedString* attributedString =
        [[NSAttributedString alloc] initWithRTFD:fileData documentAttributes:0];
      fullText = [attributedString string];
      #ifdef ARC_ENABLED
      #else
      [attributedString release];
      #endif
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("com.apple.flat-rtfd")))
    #ifdef ARC_ENABLED
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, CFSTR("public.rtf")))
    #else
    else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.rtf")))
    #endif
    {
      NSAttributedString* attributedString =
        [[NSAttributedString alloc] initWithRTF:fileData documentAttributes:0];
      fullText = [attributedString string];
      #ifdef ARC_ENABLED
      #else
      [attributedString release];
      #endif
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.rtf")))
    #ifdef ARC_ENABLED
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, CFSTR("public.text")))
    #else
    else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.text")))
    #endif
      fullText = [NSString stringWithContentsOfURL:object guessEncoding:&encoding error:error];
    result = [NSString stringWithFormat:@"latexit-automator-%lu", (unsigned long)++self->uniqueId];
    #ifdef ARC_ENABLED
    #else
    [fileData release];
    #endif
  }//end if ([object isKindOfClass:[NSURL class]])

  //analyze fullText
  if (fullText)
  {
    NSError* error = nil;
    NSString* preamble =
      [fullText stringByMatching:@"(.*)[^%\n]*\\\\begin\\{document\\}(.*)[^%\n]*\\\\end\\{document\\}(.*)" options:RKLMultiline|RKLDotAll
        inRange:NSMakeRange(0, [fullText length]) capture:1 error:&error];
    NSString* body =
      [fullText stringByMatching:@"(.*)[^%\n]*\\\\begin\\{document\\}(.*)[^%\n]*\\\\end\\{document\\}(.*)" options:RKLMultiline|RKLDotAll
        inRange:NSMakeRange(0, [fullText length]) capture:2 error:&error];
    if ((!preamble || ![preamble length]) && (!body || ![body length]))
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
  if ([sender tag] == EXPORT_FORMAT_EPS)
    ok = [[NSFileManager defaultManager] isExecutableFileAtPath:[[preferencesController compositionConfigurationDocument] compositionConfigurationProgramPathGs]];
  else if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [[NSFileManager defaultManager] isExecutableFileAtPath:[[preferencesController compositionConfigurationDocument] compositionConfigurationProgramPathGs]] &&
         [[NSFileManager defaultManager] isExecutableFileAtPath:[[preferencesController compositionConfigurationDocument] compositionConfigurationProgramPathPsToPdf]];
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
    [self->generalExportFormatOptionsPanes setExportFormatOptionsJpegPanelDelegate:self];
    [self->generalExportFormatOptionsPanes setExportFormatOptionsSvgPanelDelegate:self];
    [self->generalExportFormatOptionsPanes setExportFormatOptionsTextPanelDelegate:self];
  }//end if (!self->generalExportFormatOptionsPanes)
  [self->generalExportFormatOptionsPanes setJpegQualityPercent:
    [[[self parameters] objectForKey:@"exportJpegQualityPercent"] doubleValue]];
  [self->generalExportFormatOptionsPanes setJpegBackgroundColor:
    [NSColor colorWithData:[[self parameters] objectForKey:@"exportJpegBackgroundColor"]]];
  [self->generalExportFormatOptionsPanes setSvgPdfToSvgPath:
    [[self parameters] objectForKey:@"exportSvgPdfToSvgPath"]];
  [self->generalExportFormatOptionsPanes setTextExportPreamble:
   [[[[self parameters] objectForKey:@"exportTextExportPreamble"] dynamicCastToClass:[NSNumber class]] boolValue]];
  [self->generalExportFormatOptionsPanes setTextExportEnvironment:
   [[[[self parameters] objectForKey:@"exportTextExportEnvironment"] dynamicCastToClass:[NSNumber class]] boolValue]];
  [self->generalExportFormatOptionsPanes setTextExportBody:
   [[[[self parameters] objectForKey:@"exportTextExportBody"] dynamicCastToClass:[NSNumber class]] boolValue]];
  NSPanel* panelToOpen = nil;
  export_format_t exportFormat = [self->exportFormatPopupButton selectedTag];
  if (exportFormat == EXPORT_FORMAT_JPEG)
    panelToOpen = [self->generalExportFormatOptionsPanes exportFormatOptionsJpegPanel];
  else if (exportFormat == EXPORT_FORMAT_SVG)
    panelToOpen = [self->generalExportFormatOptionsPanes exportFormatOptionsSvgPanel];
  if (panelToOpen)
    [NSApp beginSheet:panelToOpen
       modalForWindow:[self->tabView window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
}
//end generalExportFormatOptionsOpen:

-(void) exportFormatOptionsPanel:(NSPanel*)exportFormatOptionsPanel didCloseWithOK:(BOOL)ok
{
  if (ok)
  {
    if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    {
      [[self parameters] setObject:[NSNumber numberWithDouble:[self->generalExportFormatOptionsPanes jpegQualityPercent]] forKey:@"exportJpegQualityPercent"];
      [[self parameters] setObject:[[self->generalExportFormatOptionsPanes jpegBackgroundColor] colorAsData] forKey:@"exportJpegBackgroundColor"];
    }//end if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsJpegPanel])
    else if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    {
      [[self parameters] setObject:[self->generalExportFormatOptionsPanes svgPdfToSvgPath] forKey:@"exportSvgPdfToSvgPath"];
    }//end if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsSvgPanel])
    else if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsTextPanel])
    {
      [[self parameters] setObject:[NSNumber numberWithBool:[self->generalExportFormatOptionsPanes textExportPreamble]] forKey:@"exportTextExportPreamble"];
      [[self parameters] setObject:[NSNumber numberWithBool:[self->generalExportFormatOptionsPanes textExportEnvironment]] forKey:@"exportTextExportEnvironment"];
      [[self parameters] setObject:[NSNumber numberWithBool:[self->generalExportFormatOptionsPanes textExportBody]] forKey:@"exportTextExportBody"];
    }//end if (exportFormatOptionsPanel == [self->generalExportFormatOptionsPanes exportFormatOptionsSvgPanel])
  }//end if (ok)
  [NSApp endSheet:exportFormatOptionsPanel];
  [exportFormatOptionsPanel orderOut:self];
}
//end exportFormatOptionsPanel:didCloseWithOK:

@end
