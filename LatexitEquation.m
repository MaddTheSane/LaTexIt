//
//  LatexitEquation.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/10/08.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "LatexitEquation.h"

#import "CHExportPrefetcher.h"
#import "Compressor.h"
#import "LatexitEquationData.h"
#import "LaTeXProcessor.h"
#import "NSMutableArrayExtended.h"
#import "NSColorExtended.h"
#import "NSDataExtended.h"
#import "NSFontExtended.h"
#import "NSImageExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSObjectExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "RegexKitLite.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>

#import <Quartz/Quartz.h>

static void extractStreamObjectsFunction(const char *key, CGPDFObjectRef object, void* info)
{
  CGPDFDictionaryRef dict = 0;
  CGPDFArrayRef array = 0;
  CGPDFStreamRef stream = 0;
  if (CGPDFObjectGetValue(object, kCGPDFObjectTypeDictionary, &dict))
    CGPDFDictionaryApplyFunction(dict, extractStreamObjectsFunction, info);
  else if (CGPDFObjectGetValue(object, kCGPDFObjectTypeArray, &array))
  {
    size_t count = CGPDFArrayGetCount(array);
    size_t i = 0;
    for(i = 0 ; i<count ; ++i)
    {
      CGPDFStreamRef stream = 0;
      CGPDFArrayRef array2 = 0;
      if (CGPDFArrayGetArray(array, i, &array2))
      {
        CGPDFObjectRef object2 = 0;
        CGPDFArrayGetObject(array, i, &object2);
        extractStreamObjectsFunction(0, object2, info);
      }//end if (CGPDFArrayGetArray(array, i, &array2))
      else if (CGPDFArrayGetStream(array, i, &stream))
      {
        CGPDFDataFormat dataFormat = 0;
        CFDataRef data = CGPDFStreamCopyData(stream, &dataFormat);
        if (data && (dataFormat == CGPDFDataFormatRaw))
          [((NSMutableArray*) info) addObject:[(NSData*)data autorelease]];
        else if (data)
          CFRelease(data);
      }//end if (CGPDFArrayGetStream(array, i, &stream))
    }//end for each object
  }//end if (CGPDFObjectGetValue(object, kCGPDFObjectTypeArray, &array))
  else if (CGPDFObjectGetValue(object, kCGPDFObjectTypeStream, &stream))
  {
    CGPDFDataFormat dataFormat = 0;
    CFDataRef data = CGPDFStreamCopyData(stream, &dataFormat);
    if (data && (dataFormat == CGPDFDataFormatRaw))
      [((NSMutableArray*) info) addObject:[(NSData*)data autorelease]];
    else if (data)
      CFRelease(data);
  }//end if (CGPDFObjectGetValue(object, kCGPDFObjectTypeStream, &stream))
}
//end extractStreamObjectsFunction()

static void CHCGPDFOperatorCallback_Tj(CGPDFScannerRef scanner, void *info);
static void CHCGPDFOperatorCallback_Tj(CGPDFScannerRef scanner, void *info)
{
  CGPDFStringRef pdfString = 0;
  BOOL okString = CGPDFScannerPopString(scanner, &pdfString);
  if (okString)
  {
    CFStringRef cfString = CGPDFStringCopyTextString(pdfString);
    NSString* string = [(NSString*)cfString autorelease];
    NSError* error = nil;
    NSArray* components =
      [string captureComponentsMatchedByRegex:@"^\\<latexit sha1_base64=\"(.*?)\"\\>(.*?)\\</latexit\\>$"
                               options:RKLMultiline|RKLDotAll
                                 range:NSMakeRange(0, [string length]) error:&error];
    if ([components count] == 3)
    {
      NSString* sha1Base64 = [components objectAtIndex:1];
      NSString* dataBase64Encoded = [components objectAtIndex:2];
      NSString* dataBase64EncodedSha1Base64 = [[dataBase64Encoded dataUsingEncoding:NSUTF8StringEncoding] sha1Base64];
      NSData* compressedData = [sha1Base64 isEqualToString:dataBase64EncodedSha1Base64] ?
        [NSData dataWithBase64:dataBase64Encoded encodedWithNewlines:NO] :
        nil;
      NSData* uncompressedData = !compressedData ? nil : [Compressor zipuncompress:compressedData];
      NSPropertyListFormat format = 0;
      id plist = !uncompressedData ? nil :
        isMacOS10_5OrAbove() ?
          [NSPropertyListSerialization propertyListWithData:uncompressedData
            options:NSPropertyListImmutable format:&format error:nil] :
          [NSPropertyListSerialization propertyListFromData:uncompressedData
            mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil];
      NSDictionary* plistAsDictionary = [plist dynamicCastToClass:[NSDictionary class]];
      if (plistAsDictionary)
      {
        NSDictionary** outLatexitMetadata = (NSDictionary**)info;
        if (outLatexitMetadata)
          *outLatexitMetadata = plistAsDictionary;
      }//end if (plistAsDictionary)
    }//end if ([components count] == 3)
  }//end if (okString)
}//end CHCGPDFOperatorCallback_Tj

NSString* LatexitEquationsPboardType = @"LatexitEquationsPboardType";

static NSEntityDescription* cachedEntity = nil;
static NSMutableArray*      managedObjectContextStackInstance = nil;

@interface LatexitEquation (PrivateAPI)
+(NSMutableArray*) managedObjectContextStack;
-(BOOL) isUpdating;
@end

@implementation LatexitEquation

+(NSEntityDescription*) entity
{
  if (!cachedEntity)
  {
    @synchronized(self)
    {
      if (!cachedEntity)
        cachedEntity = [[[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])] retain];
    }//end @synchronized(self)
  }//end if (!cachedEntity)
  return cachedEntity;
}
//end entity

+(NSMutableArray*) managedObjectContextStack
{
  if (!managedObjectContextStackInstance)
  {
    @synchronized(self)
    {
      if (!managedObjectContextStackInstance)
        managedObjectContextStackInstance = [[NSMutableArray alloc] init];
    }
  }
  return managedObjectContextStackInstance;
}
//end managedObjectContextStack

+(void) pushManagedObjectContext:(NSManagedObjectContext*)context
{
  @synchronized([self managedObjectContextStack])
  {
    if (!context)
      [managedObjectContextStackInstance addObject:[NSNull null]];
    else
      [managedObjectContextStackInstance addObject:context];
  }
}
//end pushManagedObjectContext:

+(NSManagedObjectContext*) currentManagedObjectContext
{
  NSManagedObjectContext* result = nil;
  @synchronized([self managedObjectContextStack])
  {
    id context = [managedObjectContextStackInstance lastObject];
    result = (context == [NSNull null]) ? nil : context;
  }
  return result;
}
//end currentManagedObjectContext

+(NSManagedObjectContext*) popManagedObjectContext
{
  NSManagedObjectContext* result = nil;
  @synchronized([self managedObjectContextStack])
  {
    result = [self currentManagedObjectContext];
    [managedObjectContextStackInstance removeLastObject];
  }
  return result;
}
//end popManagedObjectContext

+(NSDictionary*) metaDataFromPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults outPdfData:(NSData**)outPdfData
{
  NSMutableDictionary* result = [NSMutableDictionary dictionary];
  if (outPdfData)
    *outPdfData = someData;
  
  BOOL isLaTeXiTPDF = NO;
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSFont* defaultFont = [preferencesController editionFont];
  NSDictionary* defaultAttributes = [NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName];
  NSAttributedString* defaultPreambleAttributedString =
    [[PreferencesController sharedController] preambleDocumentAttributedString];

  BOOL decodedFromAnnotation = NO;
  #warning 64bits problem
  BOOL shouldDenyDueTo64Bitsproblem = (sizeof(NSInteger) != 4);
  BOOL shoudDecodeFromAnnotations = !shouldDenyDueTo64Bitsproblem;
  if (shoudDecodeFromAnnotations)
  {
    PDFDocument* pdfDocument = nil;
    NSDictionary* embeddedInfos = nil;
    @try{
      pdfDocument = [[PDFDocument alloc] initWithData:someData];
      PDFPage*     pdfPage     = [pdfDocument pageAtIndex:0];
      NSArray* annotations     = [pdfPage annotations];
      NSUInteger i = 0;
      for(i = 0 ; !embeddedInfos && (i < [annotations count]) ; ++i)
      {
        id annotation = [annotations objectAtIndex:i];
        if ([annotation isKindOfClass:[PDFAnnotationText class]])
        {
          PDFAnnotationText* annotationTextCandidate = (PDFAnnotationText*)annotation;
          if ([[annotationTextCandidate userName] isEqualToString:@"fr.chachatelier.pierre.LaTeXiT"])
          {
            NSString* contents = [annotationTextCandidate contents];
            NSData* data = !contents ? nil : [NSData dataWithBase64:contents];
            @try{
              embeddedInfos = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            }
            @catch(NSException* e){
              DebugLog(0, @"exception : %@", e);
            }
          }//end if ([[annotationTextCandidate userName] isEqualToString:@"fr.chachatelier.pierre.LaTeXiT"])
        }//end if ([annotation isKindOfClass:PDFAnnotationText])
      }//end for each annotation
    }
    @catch(NSException* e) {
      DebugLog(0, @"exception : %@", e);
    }
    @finally{
      [pdfDocument release];
    }
    if (embeddedInfos)
    {
      NSString* preambleAsString = [embeddedInfos objectForKey:@"preamble"];
      NSAttributedString* preamble = !preambleAsString ? nil :
        [[NSAttributedString alloc] initWithString:preambleAsString attributes:defaultAttributes];
      [result setObject:(!preamble ? defaultPreambleAttributedString : preamble) forKey:@"preamble"];
      [preamble release];

      NSNumber* modeAsNumber = [embeddedInfos objectForKey:@"mode"];
      latex_mode_t mode = modeAsNumber ? (latex_mode_t)[modeAsNumber intValue] :
                                         (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : LATEX_MODE_TEXT);
      [result setObject:[NSNumber numberWithInt:((mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode)] forKey:@"mode"];

      NSString* sourceAsString = [embeddedInfos objectForKey:@"source"];
      NSAttributedString* sourceText =
        [[NSAttributedString alloc] initWithString:(!sourceAsString ? @"" : sourceAsString) attributes:defaultAttributes];
      if (mode == LATEX_MODE_EQNARRAY)
      {
        NSMutableAttributedString* sourceText2 = [[NSMutableAttributedString alloc] init];
        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] autorelease]];
        [sourceText2 appendAttributedString:sourceText];
        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] autorelease]];
        [sourceText release];
        sourceText = sourceText2;
      }
      [result setObject:sourceText forKey:@"sourceText"];
      [sourceText release];
      
      NSNumber* pointSizeAsNumber = [embeddedInfos objectForKey:@"magnification"];
      [result setObject:(pointSizeAsNumber ? pointSizeAsNumber :
                         [NSNumber numberWithDouble:(useDefaults ? [preferencesController latexisationFontSize] : 0)])
                 forKey:@"magnification"];

      NSNumber* baselineAsNumber = [embeddedInfos objectForKey:@"baseline"];
      [result setObject:(baselineAsNumber ? baselineAsNumber : [NSNumber numberWithDouble:0.])
                 forKey:@"baseline"];

      NSColor* defaultColor = [preferencesController latexisationFontColor];
      NSColor* color = [NSColor colorWithData:[embeddedInfos objectForKey:@"color"]];
      [result setObject:(color ? color : (useDefaults ? defaultColor : [NSColor blackColor]))
                 forKey:@"color"];

      NSColor* defaultBKColor = [NSColor whiteColor];
      NSColor* backgroundColor = [NSColor colorWithData:[embeddedInfos objectForKey:@"backgroundColor"]];
      [result setObject:(backgroundColor ? backgroundColor : (useDefaults ? defaultBKColor : [NSColor whiteColor]))
                 forKey:@"backgroundColor"];

      NSString* titleAsString = [embeddedInfos objectForKey:@"title"];
      [result setObject:(!titleAsString ? @"" : titleAsString) forKey:@"title"];

      [result setObject:[NSDate date] forKey:@"date"];
      
      decodedFromAnnotation = YES;
    }//end if (embeddedInfos)
  }//end if (shoudDecodeFromAnnotations)
  
  if (decodedFromAnnotation)
    isLaTeXiTPDF = YES;
  else//if (!decodedFromAnnotation)
  {
    NSString* dataAsString = [[[NSString alloc] initWithData:someData encoding:NSMacOSRomanStringEncoding] autorelease];
    NSArray*  testArray    = nil;
    
    NSMutableString* preambleString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Preamble (ESannop"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      preambleString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [preambleString rangeOfString:@"ESannopend"];
      range.length = (range.location != NSNotFound) ? [preambleString length]-range.location : 0;
      [preambleString deleteCharactersInRange:range];
      [preambleString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, [preambleString length])];
      [preambleString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, [preambleString length])];
      [preambleString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, [preambleString length])];
      [preambleString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, [preambleString length])];
    }
    NSAttributedString* preamble =
      preambleString ? [[[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes] autorelease]
                     : (useDefaults ? defaultPreambleAttributedString
                                    : [[[NSAttributedString alloc] initWithString:@"" attributes:defaultAttributes] autorelease]);

    //test escaped preample from version 1.13.0
    testArray = [dataAsString componentsSeparatedByString:@"/EscapedPreamble (ESannoep"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      preambleString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [preambleString rangeOfString:@"ESannoepend"];
      range.length = (range.location != NSNotFound) ? [preambleString length]-range.location : 0;
      [preambleString deleteCharactersInRange:range];
      NSString* unescapedPreamble =
        (NSString*)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                           (CFStringRef)preambleString, CFSTR(""),
                                                                           kCFStringEncodingUTF8);
      preambleString = [NSString stringWithString:(NSString*)unescapedPreamble];
      CFRelease(unescapedPreamble);
    }
    preamble = preambleString ? [[[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes] autorelease]
                              : preamble;
    [result setObject:preamble forKey:@"preamble"];

    NSMutableString* modeAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Type (EEtype"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      modeAsString  = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [modeAsString rangeOfString:@"EEtypeend"];
      range.length = (range.location != NSNotFound) ? [modeAsString length]-range.location : 0;
      [modeAsString deleteCharactersInRange:range];
    }
    latex_mode_t mode = modeAsString ? (latex_mode_t) [modeAsString intValue]
                        : (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : 0);
    mode = (mode == LATEX_MODE_EQNARRAY) ? mode : validateLatexMode(mode); //Added starting from version 1.7.0
    [result setObject:[NSNumber numberWithInt:((mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode)] forKey:@"mode"];

    NSMutableString* sourceString = [NSMutableString string];
    testArray = [dataAsString componentsSeparatedByString:@"/Subject (ESannot"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      [sourceString appendString:[testArray objectAtIndex:1]];
      NSRange range = [sourceString rangeOfString:@"ESannotend"];
      range.length = (range.location != NSNotFound) ? [sourceString length]-range.location : 0;
      [sourceString deleteCharactersInRange:range];
      [sourceString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, [sourceString length])];
      [sourceString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, [sourceString length])];
      [sourceString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, [sourceString length])];
      [sourceString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, [sourceString length])];
    }
    NSAttributedString* sourceText = sourceString ?
      [[[NSAttributedString alloc] initWithString:sourceString attributes:defaultAttributes] autorelease] : @"";

    //test escaped source from version 1.13.0
    testArray = [dataAsString componentsSeparatedByString:@"/EscapedSubject (ESannoes"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      [sourceString setString:@""];
      [sourceString appendString:[testArray objectAtIndex:1]];
      NSRange range = !sourceString ? NSMakeRange(0, 0) : [sourceString rangeOfString:@"ESannoesend"];
      range.length = (range.location != NSNotFound) ? [sourceString length]-range.location : 0;
      [sourceString deleteCharactersInRange:range];
      NSString* unescapedSource =
        (NSString*)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                           (CFStringRef)sourceString, CFSTR(""),
                                                                           kCFStringEncodingUTF8);
      [sourceString setString:unescapedSource];
      CFRelease(unescapedSource);
    }
    sourceText = sourceString ? [[[NSAttributedString alloc] initWithString:sourceString attributes:defaultAttributes] autorelease]
                              : sourceText;
    if (mode == LATEX_MODE_EQNARRAY)
    {
      NSMutableAttributedString* sourceText2 = [[[NSMutableAttributedString alloc] init] autorelease];
      [sourceText2 appendAttributedString:
        [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] autorelease]];
      [sourceText2 appendAttributedString:sourceText];
      [sourceText2 appendAttributedString:
        [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] autorelease]];
      sourceText = sourceText2;
    }
    if (sourceText)
      [result setObject:sourceText forKey:@"sourceText"];

    NSMutableString* pointSizeAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Magnification (EEmag"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      pointSizeAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [pointSizeAsString rangeOfString:@"EEmagend"];
      range.length  = (range.location != NSNotFound) ? [pointSizeAsString length]-range.location : 0;
      [pointSizeAsString deleteCharactersInRange:range];
    }
    [result setObject:[NSNumber numberWithDouble:(pointSizeAsString ? [pointSizeAsString doubleValue] : (useDefaults ? [preferencesController latexisationFontSize] : 0))] forKey:@"magnification"];

    NSColor* defaultColor = [preferencesController latexisationFontColor];
    NSMutableString* colorAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Color (EEcol"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      colorAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [colorAsString rangeOfString:@"EEcolend"];
      range.length = (range.location != NSNotFound) ? [colorAsString length]-range.location : 0;
      [colorAsString deleteCharactersInRange:range];
    }
    NSColor* color = colorAsString ? [NSColor colorWithRgbaString:colorAsString] : nil;
    if (!color)
      color = (useDefaults ? defaultColor : [NSColor blackColor]);
    [result setObject:color forKey:@"color"];

    NSColor* defaultBkColor = [NSColor whiteColor];
    NSMutableString* bkColorAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/BKColor (EEbkc"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      bkColorAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [bkColorAsString rangeOfString:@"EEbkcend"];
      range.length = (range.location != NSNotFound) ? [bkColorAsString length]-range.location : 0;
      [bkColorAsString deleteCharactersInRange:range];
    }
    NSColor* backgroundColor = bkColorAsString ? [NSColor colorWithRgbaString:bkColorAsString] : nil;
    if (!backgroundColor)
      backgroundColor = (useDefaults ? defaultBkColor : [NSColor whiteColor]);
    [result setObject:backgroundColor forKey:@"backgroundColor"];
      
    NSMutableString* baselineAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Baseline (EEbas"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      baselineAsString  = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [baselineAsString rangeOfString:@"EEbasend"];
      range.length = (range.location != NSNotFound) ? [baselineAsString length]-range.location : 0;
      [baselineAsString deleteCharactersInRange:range];
    }
    [result setObject:[NSNumber numberWithDouble:(baselineAsString ? [baselineAsString doubleValue] : 0.)] forKey:@"baseline"];

    NSMutableString* titleAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Title (EEtitle"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      titleAsString  = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [titleAsString rangeOfString:@"EEtitleend"];
      range.length = (range.location != NSNotFound) ? [titleAsString length]-range.location : 0;
      [titleAsString deleteCharactersInRange:range];
    }
    [result setObject:(!titleAsString ? @"" : titleAsString) forKey:@"title"];
    
    [result setObject:[NSDate date] forKey:@"date"];
  }//end if (!decodedFromAnnotation)
  
  if (!isLaTeXiTPDF)
  {
    CGDataProviderRef dataProvider = !someData ? 0 :
      CGDataProviderCreateWithCFData((CFDataRef)someData);
    CGPDFDocumentRef pdfDocument = !dataProvider ? 0 :
      CGPDFDocumentCreateWithProvider(dataProvider);
    CGPDFPageRef page = !pdfDocument || !CGPDFDocumentGetNumberOfPages(pdfDocument) ? 0 :
      CGPDFDocumentGetPage(pdfDocument, 1);
    CGPDFDictionaryRef pageDictionary = !page ? 0 : CGPDFPageGetDictionary(page);
    
    BOOL exploreStreams = NO;
    if (exploreStreams)
    {
      CGPDFDictionaryRef catalog = !pdfDocument ? 0 : CGPDFDocumentGetCatalog(pdfDocument);
      NSMutableArray* streamObjects = [NSMutableArray array];
      if (catalog)
        CGPDFDictionaryApplyFunction(catalog, extractStreamObjectsFunction, streamObjects);
      if (pageDictionary)
        CGPDFDictionaryApplyFunction(pageDictionary, extractStreamObjectsFunction, streamObjects);
      NSEnumerator* enumerator = [streamObjects objectEnumerator];
      id streamData = nil;
      NSData* pdfHeader = [@"%PDF" dataUsingEncoding:NSUTF8StringEncoding];
      while(!isLaTeXiTPDF && ((streamData = [enumerator nextObject])))
      {
        NSData* streamAsData = [streamData dynamicCastToClass:[NSData class]];
        NSData* streamAsPdfData = 
          ([streamAsData bridge_rangeOfData:pdfHeader options:NSDataSearchAnchored range:NSMakeRange(0, [streamAsData length])].location == NSNotFound) ?
          nil : streamAsData;
        NSData* pdfData2 = nil;
        NSDictionary* result2 = !streamAsPdfData ? nil :
          [[[self metaDataFromPDFData:streamAsPdfData useDefaults:NO outPdfData:&pdfData2] mutableCopy] autorelease];
        if (result && outPdfData && pdfData2)
          *outPdfData = pdfData2;
        isLaTeXiTPDF |= (result2 != nil);
      }//end for each stream
    }//end if (exploreStreams)

    NSDictionary* latexitMetadata = nil;
    if (!isLaTeXiTPDF)
    {
      CGPDFContentStreamRef contentStream = !page ? 0 :
        CGPDFContentStreamCreateWithPage(page);
      CGPDFOperatorTableRef operatorTable = CGPDFOperatorTableCreate();
      CGPDFOperatorTableSetCallback(operatorTable, "Tj", &CHCGPDFOperatorCallback_Tj);
      CGPDFScannerRef pdfScanner = !contentStream ? 0 :
        CGPDFScannerCreate(contentStream, operatorTable, &latexitMetadata);
      CGPDFScannerScan(pdfScanner);
      CGPDFScannerRelease(pdfScanner);
      CGPDFOperatorTableRelease(operatorTable);
      CGPDFContentStreamRelease(contentStream);
    }//end if (!isLaTeXiTPDF)
    CGPDFDocumentRelease(pdfDocument);
    CGDataProviderRelease(dataProvider);
    if (latexitMetadata)
    {
      NSString* preambleAsString = [latexitMetadata objectForKey:@"preamble"];
      NSAttributedString* preamble = !preambleAsString ? nil :
        [[NSAttributedString alloc] initWithString:preambleAsString attributes:defaultAttributes];
      [result setObject:(!preamble ? defaultPreambleAttributedString : preamble) forKey:@"preamble"];
      [preamble release];

      NSNumber* modeAsNumber = [latexitMetadata objectForKey:@"mode"];
      latex_mode_t mode = modeAsNumber ? (latex_mode_t)[modeAsNumber intValue] :
                                         (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : LATEX_MODE_TEXT);
      [result setObject:[NSNumber numberWithInt:((mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode)] forKey:@"mode"];

      NSString* sourceAsString = [latexitMetadata objectForKey:@"source"];
      NSAttributedString* sourceText =
        [[NSAttributedString alloc] initWithString:(!sourceAsString ? @"" : sourceAsString) attributes:defaultAttributes];
      if (mode == LATEX_MODE_EQNARRAY)
      {
        NSMutableAttributedString* sourceText2 = [[NSMutableAttributedString alloc] init];
        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] autorelease]];
        [sourceText2 appendAttributedString:sourceText];
        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] autorelease]];
        [sourceText release];
        sourceText = sourceText2;
      }
      [result setObject:sourceText forKey:@"sourceText"];
      [sourceText release];
      
      NSNumber* pointSizeAsNumber = [latexitMetadata objectForKey:@"magnification"];
      [result setObject:(pointSizeAsNumber ? pointSizeAsNumber :
                         [NSNumber numberWithDouble:(useDefaults ? [preferencesController latexisationFontSize] : 0)])
                 forKey:@"magnification"];

      NSNumber* baselineAsNumber = [latexitMetadata objectForKey:@"baseline"];
      [result setObject:(baselineAsNumber ? baselineAsNumber : [NSNumber numberWithDouble:0.])
                 forKey:@"baseline"];

      NSColor* defaultColor = [preferencesController latexisationFontColor];
      NSColor* color = [NSColor colorWithRgbaString:[latexitMetadata objectForKey:@"color"]];
      [result setObject:(color ? color : (useDefaults ? defaultColor : [NSColor blackColor]))
                 forKey:@"color"];

      NSColor* defaultBKColor = [NSColor whiteColor];
      NSColor* backgroundColor = [NSColor colorWithRgbaString:[latexitMetadata objectForKey:@"backgroundColor"]];
      [result setObject:(backgroundColor ? backgroundColor : (useDefaults ? defaultBKColor : [NSColor whiteColor]))
                 forKey:@"backgroundColor"];

      NSString* titleAsString = [latexitMetadata objectForKey:@"title"];
      [result setObject:(!titleAsString ? @"" : titleAsString) forKey:@"title"];

      [result setObject:[NSDate date] forKey:@"date"];
      
      decodedFromAnnotation = YES;
      isLaTeXiTPDF = YES;
    }//end if (latexitMetadata)
  }//end if (!isLaTeXiTPDF)
  
  if (!isLaTeXiTPDF)
    result = nil;
  
  return result;
}
//end metaDataFromPDFData:useDefaults:

+(BOOL) latexitEquationPossibleWithUTI:(NSString*)uti
{
  BOOL result = NO;
  if (UTTypeConformsTo((CFStringRef)uti, CFSTR("com.adobe.pdf")))
    result = YES;
  else if (UTTypeConformsTo((CFStringRef)uti, CFSTR("public.tiff")))
    result = YES;
  else if (UTTypeConformsTo((CFStringRef)uti, CFSTR("public.png")))
    result = YES;
  else if (UTTypeConformsTo((CFStringRef)uti, CFSTR("public.jpeg")))
    result = YES;
  else if (UTTypeConformsTo((CFStringRef)uti, CFSTR("public.svg-image")))
    result = YES;
  else if (UTTypeConformsTo((CFStringRef)uti, CFSTR("public.html")))
    result = YES;
  return result;
}
//end latexitEquationPossibleWithUTI:

+(BOOL) latexitEquationPossibleWithData:(NSData*)data sourceUTI:(NSString*)sourceUTI
{
  BOOL result = NO;
  BOOL utiOk = [self latexitEquationPossibleWithUTI:sourceUTI];
  if (utiOk)
  {
    result = YES;
  }//end if (utiOk)
  return result;
}
//end latexitEquationPossibleWithData:

+(NSArray*) latexitEquationsWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults
{
  NSArray* result = nil;
  NSMutableArray* equations = [NSMutableArray arrayWithCapacity:1];
  if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("com.adobe.pdf")))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.tiff")))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.png")))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.jpeg")))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.svg-image")))
  {
    NSError* error = nil;
    NSString* string = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
    NSArray* descriptions =
      [string componentsMatchedByRegex:@"<svg(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</svg>"
                               options:RKLCaseless|RKLMultiline|RKLDotAll
                                 range:NSMakeRange(0, [string length]) capture:0 error:&error];
    if (error)
      DebugLog(1, @"error : %@", error);
    NSEnumerator* enumerator = [descriptions objectEnumerator];
    NSString* description = nil;
    while((description = [enumerator nextObject]))
    {
      NSData* subData = [description dataUsingEncoding:NSUTF8StringEncoding];
      [equations safeAddObject:[self latexitEquationWithData:subData sourceUTI:sourceUTI useDefaults:useDefaults]];
    }//end for each description
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.svg-image")))
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.html")))
  {
    NSError* error = nil;
    NSString* string = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
    NSArray* descriptions =
      [string componentsMatchedByRegex:@"<blockquote(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</blockquote>"
                               options:RKLCaseless|RKLMultiline|RKLDotAll
                                 range:NSMakeRange(0, [string length]) capture:0 error:&error];
    if (error)
      DebugLog(1, @"error : %@", error);
    NSEnumerator* enumerator = [descriptions objectEnumerator];
    NSString* description = nil;
    while((description = [enumerator nextObject]))
    {
      NSData* subData = [description dataUsingEncoding:NSUTF8StringEncoding];
      [equations safeAddObject:[self latexitEquationWithData:subData sourceUTI:sourceUTI useDefaults:useDefaults]];
    }//end for each description
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.html")))
  result = [NSArray arrayWithArray:equations];
  return result;
}
//end latexitEquationsWithData:sourceUTI:useDefaults

+(id) latexitEquationWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                           color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
                 backgroundColor:(NSColor*)backgroundColor
{
  id instance = [[[self class] alloc] initWithPDFData:someData preamble:aPreamble sourceText:aSourceText
                                              color:aColor pointSize:aPointSize date:aDate mode:aMode
                                              backgroundColor:backgroundColor];
  return [instance autorelease];
}
//end latexitEquationWithPDFData:preamble:sourceText:color:pointSize:date:mode:backgroundColor:

+(id) latexitEquationWithMetaData:(NSDictionary*)metaData useDefaults:(BOOL)useDefaults
{
  return [[[[self class] alloc] initWithMetaData:metaData useDefaults:useDefaults] autorelease];
}
//end latexitEquationWithData:sourceUTI:useDefaults:

+(id) latexitEquationWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults
{
  return [[[[self class] alloc] initWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults] autorelease];
}
//end latexitEquationWithData:sourceUTI:useDefaults:

+(id) latexitEquationWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
{
  return [[[[self class] alloc] initWithPDFData:someData useDefaults:useDefaults] autorelease];
}
//end latexitEquationWithPDFData:useDefaults:

-(id) initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context
{
  if (!((self = [super initWithEntity:entity insertIntoManagedObjectContext:context])))
    return nil;
  self->isModelPrior250 = context &&
    ![[[[context persistentStoreCoordinator] managedObjectModel] entitiesByName]
      objectForKey:NSStringFromClass([LatexitEquationData class])];
  self->exportPrefetcher = [[CHExportPrefetcher alloc] init];
  return self;
}
//end initWithEntity:insertIntoManagedObjectContext:

-(id) initWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
              color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
              backgroundColor:(NSColor*)aBackgroundColor
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
  [self beginUpdate];
  [self setPdfData:someData];
  [self setPreamble:aPreamble];
  [self setSourceText:aSourceText];
  [self setColor:aColor];
  [self setPointSize:aPointSize];
  [self setDate:aDate ? [[aDate copy] autorelease] : [NSDate date]];
  [self setMode:aMode];
  [self setTitle:nil];
    
  if (!aBackgroundColor && [[PreferencesController sharedController] documentUseAutomaticHighContrastedPreviewBackground])
    aBackgroundColor = ([aColor grayLevel] > .5) ? [NSColor blackColor] : nil;
  [self setBackgroundColor:aBackgroundColor];
  [self endUpdate];
  return self;
}
//end initWithPDFData:preamble:sourceText:color:pointSize:date:mode:backgroundColor:

-(id) initWithMetaData:(NSDictionary*)metaData useDefaults:(BOOL)useDefaults
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;

  [self beginUpdate];
  NSAttributedString* preamble = [metaData objectForKey:@"preamble"];
  if (preamble)
    [self setPreamble:preamble];

  NSNumber* mode = [metaData objectForKey:@"mode"];
  if (mode)
    [self setMode:(latex_mode_t)[mode intValue]];

  NSAttributedString* sourceText = [metaData objectForKey:@"sourceText"];
  if (sourceText)
    [self setSourceText:sourceText];

  NSNumber* pointSize = [metaData objectForKey:@"magnification"];
  if (pointSize)
    [self setPointSize:[pointSize doubleValue]];

  NSColor* color = [metaData objectForKey:@"color"];
  if (color)
    [self setColor:color];

  NSColor* backgroundColor = [metaData objectForKey:@"backgroundColor"];
  if (backgroundColor)
    [self setBackgroundColor:backgroundColor];

  NSString* title = [metaData objectForKey:@"title"];
  if (title)
    [self setTitle:title];

  NSNumber* baseline = [metaData objectForKey:@"baseline"];
  [self setBaseline:!baseline ? 0. : [baseline doubleValue]];

  NSDate* date = [metaData objectForKey:@"date"];
  if (date)
    [self setDate:date];
    
  [self endUpdate];
  
  return self;
}
//end initWithMetaData:useDefaults:

-(id) initWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
  [self setPdfData:someData];
  NSDictionary* metaData = [[self class] metaDataFromPDFData:someData useDefaults:useDefaults outPdfData:0];
  BOOL isLaTeXiTPDF = (metaData != nil);

  [self beginUpdate];
  NSAttributedString* preamble = [metaData objectForKey:@"preamble"];
  isLaTeXiTPDF &= (preamble != nil);
  if (preamble)
    [self setPreamble:preamble];

  NSNumber* mode = [metaData objectForKey:@"mode"];
  isLaTeXiTPDF &= (mode != nil);
  if (mode)
    [self setMode:(latex_mode_t)[mode intValue]];

  NSAttributedString* sourceText = [metaData objectForKey:@"sourceText"];
  isLaTeXiTPDF &= (sourceText != nil);
  if (sourceText)
    [self setSourceText:sourceText];

  NSNumber* pointSize = [metaData objectForKey:@"magnification"];
  isLaTeXiTPDF &= (pointSize != nil);
  if (pointSize)
    [self setPointSize:[pointSize doubleValue]];

  NSColor* color = [metaData objectForKey:@"color"];
  isLaTeXiTPDF &= (color != nil);
  if (color)
    [self setColor:color];

  NSColor* backgroundColor = [metaData objectForKey:@"backgroundColor"];
  isLaTeXiTPDF &= (backgroundColor != nil);
  if (backgroundColor)
    [self setBackgroundColor:backgroundColor];

  NSString* title = [metaData objectForKey:@"title"];
  if (title)
    [self setTitle:title];

  NSNumber* baseline = [metaData objectForKey:@"baseline"];
  [self setBaseline:!baseline ? 0. : [baseline doubleValue]];

  NSDate* date = [metaData objectForKey:@"date"];
  if (date)
    [self setDate:date];
    
  [self endUpdate];

  if (!isLaTeXiTPDF)
  {
    [self release];
    self = nil;
  }//end if (!isLaTeXiTPDF)

  /*
  BOOL isLaTeXiTPDF = NO;
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSFont* defaultFont = [preferencesController editionFont];
  NSDictionary* defaultAttributes = [NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName];
  NSAttributedString* defaultPreambleAttributedString = [[PreferencesController sharedController] preambleDocumentAttributedString];

  BOOL decodedFromAnnotation = NO;
  #warning 64bits problem
  BOOL shouldDenyDueTo64Bitsproblem = (sizeof(NSInteger) != 4);
  BOOL shoudDecodeFromAnnotations = !shouldDenyDueTo64Bitsproblem;
  if (shoudDecodeFromAnnotations)
  {
    PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:someData];
    PDFPage*     pdfPage     = [pdfDocument pageAtIndex:0];
    NSArray* annotations     = [pdfPage annotations];
    NSDictionary* embeddedInfos = nil;
    NSUInteger i = 0;
    for(i = 0 ; !embeddedInfos && (i < [annotations count]) ; ++i)
    {
      id annotation = [annotations objectAtIndex:i];
      if ([annotation isKindOfClass:[PDFAnnotationText class]])
      {
        PDFAnnotationText* annotationTextCandidate = (PDFAnnotationText*)annotation;
        if ([[annotationTextCandidate userName] isEqualToString:@"fr.chachatelier.pierre.LaTeXiT"])
        {
          NSString* contents = [annotationTextCandidate contents];
          NSData* data = !contents ? nil : [NSData dataWithBase64:contents];
          @try{
            embeddedInfos = [NSKeyedUnarchiver unarchiveObjectWithData:data];
          }
          @catch(NSException* e){
            DebugLog(0, @"exception : %@", e);
          }
        }//end if ([[annotationTextCandidate userName] isEqualToString:@"fr.chachatelier.pierre.LaTeXiT"])
      }//end if ([annotation isKindOfClass:PDFAnnotationText])
    }//end for each annotation
    if (embeddedInfos)
    {
      NSString* preambleAsString = [embeddedInfos objectForKey:@"preamble"];
      NSAttributedString* preamble = !preambleAsString ? nil :
        [[NSAttributedString alloc] initWithString:preambleAsString attributes:defaultAttributes];
      [self setPreamble:!preamble ? defaultPreambleAttributedString : preamble];
      [preamble release];

      NSNumber* modeAsNumber = [embeddedInfos objectForKey:@"mode"];
      latex_mode_t mode = modeAsNumber ? (latex_mode_t)[modeAsNumber intValue] :
                                         (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : LATEX_MODE_TEXT);
      [self setMode:(mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode];

      NSString* sourceAsString = [embeddedInfos objectForKey:@"source"];
      NSAttributedString* sourceText =
        [[NSAttributedString alloc] initWithString:(!sourceAsString ? @"" : sourceAsString) attributes:defaultAttributes];
      if (mode == LATEX_MODE_EQNARRAY)
      {
        NSMutableAttributedString* sourceText2 = [[NSMutableAttributedString alloc] init];
        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] autorelease]];
        [sourceText2 appendAttributedString:sourceText];
        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] autorelease]];
        [sourceText release];
        sourceText = sourceText2;
      }
      [self setSourceText:sourceText];
      [sourceText release];
      
      NSNumber* pointSizeAsNumber = [embeddedInfos objectForKey:@"magnification"];
      [self setPointSize:pointSizeAsNumber ? [pointSizeAsNumber doubleValue] :
        (useDefaults ? [preferencesController latexisationFontSize] : 0)];

      NSNumber* baselineAsNumber = [embeddedInfos objectForKey:@"baseline"];
      [self setBaseline:[baselineAsNumber doubleValue]];

      NSColor* defaultColor = [preferencesController latexisationFontColor];
      NSColor* color = [NSColor colorWithData:[embeddedInfos objectForKey:@"color"]];
      [self setColor:color ? color : (useDefaults ? defaultColor : [NSColor blackColor])];

      NSColor* defaultBKColor = [NSColor whiteColor];
      NSColor* backgroundColor = [NSColor colorWithData:[embeddedInfos objectForKey:@"backgroundColor"]];
      [self setBackgroundColor:backgroundColor ? backgroundColor : (useDefaults ? defaultBKColor : [NSColor whiteColor])];
 
      NSString* titleAsString = [embeddedInfos objectForKey:@"title"];
      [self setTitle:!titleAsString ? @"" : titleAsString];

      [self setDate:[NSDate date]];
      
      decodedFromAnnotation = YES;
    }//end if (embeddedInfos)
    [pdfDocument release];
  }//end if (shoudDecodeFromAnnotations)
  
  if (decodedFromAnnotation)
    isLaTeXiTPDF = YES;
  else//if (!decodedFromAnnotation)
  {
    NSString* dataAsString = [[[NSString alloc] initWithData:someData encoding:NSMacOSRomanStringEncoding] autorelease];
    NSArray*  testArray    = nil;
    
    NSMutableString* preambleString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Preamble (ESannop"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      preambleString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [preambleString rangeOfString:@"ESannopend"];
      range.length = (range.location != NSNotFound) ? [preambleString length]-range.location : 0;
      [preambleString deleteCharactersInRange:range];
      [preambleString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, [preambleString length])];
      [preambleString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, [preambleString length])];
      [preambleString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, [preambleString length])];
      [preambleString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, [preambleString length])];
    }
    NSAttributedString* preamble =
      preambleString ? [[[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes] autorelease]
                     : (useDefaults ? defaultPreambleAttributedString
                                    : [[[NSAttributedString alloc] initWithString:@"" attributes:defaultAttributes] autorelease]);

    //test escaped preample from version 1.13.0
    testArray = [dataAsString componentsSeparatedByString:@"/EscapedPreamble (ESannoep"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      preambleString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [preambleString rangeOfString:@"ESannoepend"];
      range.length = (range.location != NSNotFound) ? [preambleString length]-range.location : 0;
      [preambleString deleteCharactersInRange:range];
      NSString* unescapedPreamble =
        (NSString*)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                           (CFStringRef)preambleString, CFSTR(""),
                                                                           kCFStringEncodingUTF8);
      preambleString = [NSString stringWithString:(NSString*)unescapedPreamble];
      CFRelease(unescapedPreamble);
    }
    preamble = preambleString ? [[[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes] autorelease]
                              : preamble;
    [self setPreamble:preamble];

    NSMutableString* modeAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Type (EEtype"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      modeAsString  = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [modeAsString rangeOfString:@"EEtypeend"];
      range.length = (range.location != NSNotFound) ? [modeAsString length]-range.location : 0;
      [modeAsString deleteCharactersInRange:range];
    }
    latex_mode_t mode = modeAsString ? (latex_mode_t) [modeAsString intValue]
                        : (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : 0);
    mode = (mode == LATEX_MODE_EQNARRAY) ? mode : validateLatexMode(mode); //Added starting from version 1.7.0
    [self setMode:(mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode];

    NSMutableString* sourceString = [NSMutableString string];
    testArray = [dataAsString componentsSeparatedByString:@"/Subject (ESannot"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      [sourceString appendString:[testArray objectAtIndex:1]];
      NSRange range = [sourceString rangeOfString:@"ESannotend"];
      range.length = (range.location != NSNotFound) ? [sourceString length]-range.location : 0;
      [sourceString deleteCharactersInRange:range];
      [sourceString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, [sourceString length])];
      [sourceString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, [sourceString length])];
      [sourceString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, [sourceString length])];
      [sourceString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, [sourceString length])];
    }
    NSAttributedString* sourceText = sourceString ?
      [[[NSAttributedString alloc] initWithString:sourceString attributes:defaultAttributes] autorelease] : @"";

    //test escaped source from version 1.13.0
    testArray = [dataAsString componentsSeparatedByString:@"/EscapedSubject (ESannoes"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      [sourceString setString:@""];
      [sourceString appendString:[testArray objectAtIndex:1]];
      NSRange range = !sourceString ? NSMakeRange(0, 0) : [sourceString rangeOfString:@"ESannoesend"];
      range.length = (range.location != NSNotFound) ? [sourceString length]-range.location : 0;
      [sourceString deleteCharactersInRange:range];
      NSString* unescapedSource =
        (NSString*)CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                           (CFStringRef)sourceString, CFSTR(""),
                                                                           kCFStringEncodingUTF8);
      [sourceString setString:unescapedSource];
      CFRelease(unescapedSource);
    }
    sourceText = sourceString ? [[[NSAttributedString alloc] initWithString:sourceString attributes:defaultAttributes] autorelease]
                              : sourceText;
    if (mode == LATEX_MODE_EQNARRAY)
    {
      NSMutableAttributedString* sourceText2 = [[[NSMutableAttributedString alloc] init] autorelease];
      [sourceText2 appendAttributedString:
        [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] autorelease]];
      [sourceText2 appendAttributedString:sourceText];
      [sourceText2 appendAttributedString:
        [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] autorelease]];
      sourceText = sourceText2;
    }
    [self setSourceText:sourceText];

    NSMutableString* pointSizeAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Magnification (EEmag"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      pointSizeAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [pointSizeAsString rangeOfString:@"EEmagend"];
      range.length  = (range.location != NSNotFound) ? [pointSizeAsString length]-range.location : 0;
      [pointSizeAsString deleteCharactersInRange:range];
    }
    [self setPointSize:pointSizeAsString ? [pointSizeAsString doubleValue] : (useDefaults ? [preferencesController latexisationFontSize] : 0)];

    NSColor* defaultColor = [preferencesController latexisationFontColor];
    NSMutableString* colorAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Color (EEcol"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      colorAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [colorAsString rangeOfString:@"EEcolend"];
      range.length = (range.location != NSNotFound) ? [colorAsString length]-range.location : 0;
      [colorAsString deleteCharactersInRange:range];
    }
    NSColor* color = colorAsString ? [NSColor colorWithRgbaString:colorAsString] : nil;
    if (!color)
      color = (useDefaults ? defaultColor : [NSColor blackColor]);
    [self setColor:color];

    NSColor* defaultBkColor = [NSColor whiteColor];
    NSMutableString* bkColorAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/BKColor (EEbkc"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      bkColorAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [bkColorAsString rangeOfString:@"EEbkcend"];
      range.length = (range.location != NSNotFound) ? [bkColorAsString length]-range.location : 0;
      [bkColorAsString deleteCharactersInRange:range];
    }
    NSColor* backgroundColor = bkColorAsString ? [NSColor colorWithRgbaString:bkColorAsString] : nil;
    if (!backgroundColor)
      backgroundColor = (useDefaults ? defaultBkColor : [NSColor whiteColor]);
    [self setBackgroundColor:backgroundColor];
      
    NSMutableString* titleAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Title (EEtitle"];
    if (testArray && ([testArray count] >= 2))
    {
      isLaTeXiTPDF |= YES;
      titleAsString  = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [titleAsString rangeOfString:@"EEtitleend"];
      range.length = (range.location != NSNotFound) ? [titleAsString length]-range.location : 0;
      [titleAsString deleteCharactersInRange:range];
    }
    [self setTitle:titleAsString];
    
    [self setDate:[NSDate date]];
  }//end if (!decodedFromAnnotation)
  
  if (!isLaTeXiTPDF)
  {
    [self release];
    self = nil;
  }//end if (!isLaTeXiTPDF)*/
  
  return self;
}
//end initWithPDFData:useDefaults:

-(id) initWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults
{
  id result = nil;
  if (!sourceUTI)
    [self release];
  else//if (sourceUTI)
  {
    if (UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"com.adobe.pdf"))
      result = [self initWithPDFData:someData useDefaults:useDefaults];
    else if (UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"public.tiff")||
             UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"public.png")||
             UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"public.jpeg"))
    {
      CGImageSourceRef imageSource = CGImageSourceCreateWithData((CFDataRef)someData, (CFDictionaryRef)
        [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], (NSString*)kCGImageSourceShouldCache, nil]);
      CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil);
      id infos = [(NSDictionary*)properties objectForKey:(NSString*)kCGImagePropertyExifDictionary];
      id annotationBase64 = ![infos isKindOfClass:[NSDictionary class]] ? nil : [infos objectForKey:(NSString*)kCGImagePropertyExifUserComment];
      NSData* annotationData = ![annotationBase64 isKindOfClass:[NSString class]] ? nil :
        [NSData dataWithBase64:annotationBase64];
      annotationData = [Compressor zipuncompress:annotationData];
      NSDictionary* metaData = !annotationData ? nil :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      result = [self initWithMetaData:metaData useDefaults:useDefaults];
      if (properties) CFRelease(properties);
      if (imageSource) CFRelease(imageSource);
    }//end if (tiff, png, jpeg)
    else if (UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"public.svg-image"))
    {
      NSString* svgString = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
      NSString* annotationBase64 =
        [svgString stringByMatching:@"<!--latexit:(.*?)-->" options:RKLCaseless|RKLDotAll|RKLMultiline
          inRange:NSMakeRange(0, [svgString length]) capture:1 error:0];
      NSData* annotationData = [NSData dataWithBase64:annotationBase64];
      annotationData = [Compressor zipuncompress:annotationData];
      NSDictionary* metaData = !annotationData ? nil :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      result = [self initWithMetaData:metaData useDefaults:useDefaults];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"public.svg-image"))
    else if (UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"public.html"))
    {
      NSString* mathmlString = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
      NSString* annotationBase64 =
        [mathmlString stringByMatching:@"<!--latexit:(.*?)-->" options:RKLCaseless|RKLDotAll|RKLMultiline
          inRange:NSMakeRange(0, [mathmlString length]) capture:1 error:0];
      NSData* annotationData = [NSData dataWithBase64:annotationBase64];
      annotationData = [Compressor zipuncompress:annotationData];
      NSDictionary* metaData = !annotationData ? nil :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      result = [self initWithMetaData:metaData useDefaults:useDefaults];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"public.html"))
    else if (UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"public.text"))
    {
      NSString* string = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
      NSString* annotationBase64 = nil;
      if (!annotationBase64)
        annotationBase64 = [string stringByMatching:@"<!--latexit:(.*?)-->" options:RKLCaseless|RKLDotAll|RKLMultiline
                                            inRange:NSMakeRange(0, [string length]) capture:1 error:0];
      if (!annotationBase64)
        annotationBase64 = [string stringByMatching:@"([A-Za-z0-9\\+\\/\\n])*\\=*" options:RKLCaseless|RKLDotAll|RKLMultiline
                                            inRange:NSMakeRange(0, [string length]) capture:0 error:0];
      NSData* annotationData = !annotationBase64 ? nil : [NSData dataWithBase64:annotationBase64];
      annotationData = !annotationData ? nil : [Compressor zipuncompress:annotationData];
      NSDictionary* metaData = !annotationData ? nil :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      if (!metaData)
        result = nil;
      else
        result = [self initWithMetaData:metaData useDefaults:useDefaults];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, (CFStringRef)@"public.text"))
    else
      [self release];
  }//end if (sourceUTI)
  return result;
}
//end initWithData:useDefaults:

-(id) copyWithZone:(NSZone*)zone
{
  id clone = [[[self class] alloc] initWithPDFData:[self pdfData] preamble:[self preamble] sourceText:[self sourceText]
                                             color:[self color] pointSize:[self pointSize] date:[self date]
                                            mode:[self mode] backgroundColor:[self backgroundColor]];
  [[self managedObjectContext] safeInsertObject:clone];
  return clone;
}
//end copyWithZone:

-(id) initWithCoder:(NSCoder*)coder
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
  [self setPdfData:[coder decodeObjectForKey:@"pdfData"]];
  [self setPreamble:[coder decodeObjectForKey:@"preamble"]];
  [self setSourceText:[coder decodeObjectForKey:@"sourceText"]];
  [self setColor:[coder decodeObjectForKey:@"color"]];
  [self setPointSize:[coder decodeDoubleForKey:@"pointSize"]];
  [self setDate:[coder decodeObjectForKey:@"date"]];
  [self setMode:(latex_mode_t)[coder decodeIntForKey:@"mode"]];
  [self setBaseline:[coder decodeDoubleForKey:@"baseline"]];
  [self setBackgroundColor:[coder decodeObjectForKey:@"backgroundColor"]];
  [self setTitle:[coder decodeObjectForKey:@"title"]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [self dispose];
  [super dealloc];
}
//end dealloc

-(void) dispose
{
  [[self class] cancelPreviousPerformRequestsWithTarget:self];
  [self->exportPrefetcher release];
  self->exportPrefetcher = nil;
}
//end dispose

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:@"2.7.5"               forKey:@"version"];//we encode the current LaTeXiT version number
  [coder encodeObject:[self pdfData]         forKey:@"pdfData"];
  [coder encodeObject:[self preamble]        forKey:@"preamble"];
  [coder encodeObject:[self sourceText]      forKey:@"sourceText"];
  [coder encodeObject:[self color]           forKey:@"color"];
  [coder encodeDouble:[self pointSize]       forKey:@"pointSize"];
  [coder encodeObject:[self date]            forKey:@"date"];
  [coder encodeInt:[self mode]               forKey:@"mode"];
  [coder encodeDouble:[self baseline]        forKey:@"baseline"];
  [coder encodeObject:[self backgroundColor] forKey:@"backgroundColor"];
  [coder encodeObject:[self title]           forKey:@"title"];
}
//end encodeWithCoder:

-(void) awakeFromFetch
{
  [super awakeFromFetch];
  [self performSelector:@selector(awakeFromFetch2:) withObject:nil afterDelay:0.];
}

-(void) awakeFromFetch2:(id)object//delayed to avoid NSManagedObject context being change-disabled
{
  [self checkAndMigrateAlign];
}
//end awakeFromFetch2

-(void) awakeFromInsert
{
  [super awakeFromInsert];
  NSManagedObject* equationData = [self valueForKey:@"equationData"];
  [[self managedObjectContext] safeInsertObject:equationData];
}
//end awakeFromInsert

-(void) checkAndMigrateAlign
{
  if ([self mode] == LATEX_MODE_EQNARRAY)
  {
    [[self managedObjectContext] disableUndoRegistration];
    [self setMode:LATEX_MODE_TEXT];
    NSAttributedString* oldSourceText = [self sourceText];
    NSDictionary* attributes = [oldSourceText attributesAtIndex:0 effectiveRange:0];
    NSMutableAttributedString* newSourceText = [[NSMutableAttributedString alloc] init];
    [newSourceText appendAttributedString:
       [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:attributes] autorelease]];
    [newSourceText appendAttributedString:oldSourceText];
    [newSourceText appendAttributedString:
       [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:attributes] autorelease]];
    [self setSourceText:newSourceText];
    [newSourceText release];
    [[self managedObjectContext] enableUndoRegistration];
  }//end if ([self mode] == LATEX_MODE_EQNARRAY)
}
//end checkAndMigrateAlign

-(void) didTurnIntoFault
{
  [self resetPdfCachedImage];
  [super didTurnIntoFault];
}
//end didTurnIntoFault

-(void) resetPdfCachedImage
{
  @synchronized(self)
  {
    [self->pdfCachedImage release];
    self->pdfCachedImage = nil;
  }//@synchronized(self)
}
//end resetPdfCachedImage

-(void) beginUpdate
{
  ++self->updateLevel;
}
//end beginUpdate

-(void) endUpdate
{
  --self->updateLevel;
  if (![self isUpdating] && self->annotateDataDirtyState)
    [self reannotatePDFDataUsingPDFKeywords:YES];
}
//end endUpdate

-(BOOL) isUpdating
{
  return (self->updateLevel > 0);
}
//end isUpdating

-(NSData*) pdfData
{
  NSData* result = nil;
  if (!self->isModelPrior250)
  {
    [self willAccessValueForKey:@"equationData"];
    LatexitEquationData* equationData = [self primitiveValueForKey:@"equationData"];
    result = [equationData pdfData];
    [self didAccessValueForKey:@"equationData"];
  }//end if (!self->isModelPrior250)
  else//if (self->isModelPrior250)
  {
    [self willAccessValueForKey:@"pdfData"];
    result = [self primitiveValueForKey:@"pdfData"];
    [self didAccessValueForKey:@"pdfData"];
  }//end if (self->isModelPrior250)
  return result;
} 
//end pdfData

-(void) setPdfData:(NSData*)value
{
  [self willChangeValueForKey:@"pdfCachedImage"];
  @synchronized(self)
  {
    [self->pdfCachedImage release];
    self->pdfCachedImage = nil;
  }//end @synchronized(self)
  if (value != [self pdfData])
  {
    if (self->isModelPrior250)
    {
      [self willChangeValueForKey:@"pdfData"];
      [self setPrimitiveValue:value forKey:@"pdfData"];
      [self didChangeValueForKey:@"pdfData"];
    }//end if (self->isModelPrior250)
    else//if (!self->isModelPrior250)
    {
      [self willAccessValueForKey:@"equationData"];
      LatexitEquationData* equationData = [self primitiveValueForKey:@"equationData"];
      [self didAccessValueForKey:@"equationData"];
      if (!equationData)
      {
        equationData = [[LatexitEquationData alloc]
          initWithEntity:[LatexitEquationData entity] insertIntoManagedObjectContext:[self managedObjectContext]];
        if (equationData)
        {
          [self willChangeValueForKey:@"equationData"];
          [self setPrimitiveValue:equationData forKey:@"equationData"];
          [self didChangeValueForKey:@"equationData"];
          [equationData willChangeValueForKey:@"equation"];
          [equationData setPrimitiveValue:self forKey:@"equation"];//if managedObjectContext is nil, this is necessary
          [equationData didChangeValueForKey:@"equation"];
        }//end if (equationData)
        [equationData release];
      }//end if (!equationData)
      [equationData setPdfData:value];
    }//end //if (!self->isModelPrior250)
  }//end if (value != [self pdfData])
  [self didChangeValueForKey:@"pdfCachedImage"];
}
//end setPdfData:

-(NSAttributedString*) preamble
{
  NSAttributedString* result = nil;
  [self willAccessValueForKey:@"preamble"];
  result = [self primitiveValueForKey:@"preamble"];
  [self didAccessValueForKey:@"preamble"];
  if (!result)
  {
    [self willAccessValueForKey:@"preambleAsData"];
    NSData* archivedData = [self primitiveValueForKey:@"preambleAsData"];
    [self didAccessValueForKey:@"preambleAsData"];
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self setPrimitiveValue:result forKey:@"preamble"];
  }
  return result;
} 
//end preamble

-(void) setPreamble:(NSAttributedString*)value
{
  [self willChangeValueForKey:@"preamble"];
  [self setPrimitiveValue:value forKey:@"preamble"];
  [self didChangeValueForKey:@"preamble"];
  NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"preambleAsData"];
  [self setPrimitiveValue:archivedData forKey:@"preambleAsData"];
  [self didChangeValueForKey:@"preambleAsData"];
  [self reannotatePDFDataUsingPDFKeywords:YES];
}
//end setPreamble:

-(NSAttributedString*) sourceText
{
  NSAttributedString* result = nil;
  [self willAccessValueForKey:@"sourceText"];
  result = [self primitiveValueForKey:@"sourceText"];
  [self didAccessValueForKey:@"sourceText"];
  if (!result)
  {
    [self willAccessValueForKey:@"sourceTextAsData"];
    NSData* archivedData = [self primitiveValueForKey:@"sourceTextAsData"];
    [self didAccessValueForKey:@"sourceTextAsData"];
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self setPrimitiveValue:result forKey:@"sourceText"];
  }
  return result;
} 
//end sourceText

-(void) setSourceText:(NSAttributedString*)value
{
  [self willChangeValueForKey:@"sourceText"];
  [self setPrimitiveValue:value forKey:@"sourceText"];
  [self didChangeValueForKey:@"sourceText"];
  NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"sourceTextAsData"];
  [self setPrimitiveValue:archivedData forKey:@"sourceTextAsData"];
  [self didChangeValueForKey:@"sourceTextAsData"];
  [self reannotatePDFDataUsingPDFKeywords:YES];
}
//end setSourceText:

-(NSColor*) color
{
  NSColor* result = nil;
  [self willAccessValueForKey:@"color"];
  result = [self primitiveValueForKey:@"color"];
  [self didAccessValueForKey:@"color"];
  if (!result)
  {
    [self willAccessValueForKey:@"colorAsData"];
    NSData* archivedData = [self primitiveValueForKey:@"colorAsData"];
    [self didAccessValueForKey:@"colorAsData"];
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self setPrimitiveValue:result forKey:@"color"];
  }//end if (!result)
  return result;
}
//end color

-(void) setColor:(NSColor*)value
{
  [self willChangeValueForKey:@"color"];
  [self setPrimitiveValue:value forKey:@"color"];
  [self didChangeValueForKey:@"color"];
  NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"colorAsData"];
  [self setPrimitiveValue:archivedData forKey:@"colorAsData"];
  [self didChangeValueForKey:@"colorAsData"];
  [self reannotatePDFDataUsingPDFKeywords:YES];
}
//end setColor:

-(double) baseline
{
  double result = 0;
  [self willAccessValueForKey:@"baseline"];
  result = [[self primitiveValueForKey:@"baseline"] doubleValue];
  [self didAccessValueForKey:@"baseline"];
  return result;
}
//end baseline

-(void) setBaseline:(double)value
{
  [self willChangeValueForKey:@"baseline"];
  [self setPrimitiveValue:[NSNumber numberWithDouble:value] forKey:@"baseline"];
  [self didChangeValueForKey:@"baseline"];
  [self reannotatePDFDataUsingPDFKeywords:YES];
}
//end setBaseline:

-(double) pointSize
{
  double result = 0;
  [self willAccessValueForKey:@"pointSize"];
  result = [[self primitiveValueForKey:@"pointSize"] doubleValue];
  [self didAccessValueForKey:@"pointSize"];
  return result;
}
//end pointSize

-(void) setPointSize:(double)value
{
  [self willChangeValueForKey:@"pointSize"];
  [self setPrimitiveValue:[NSNumber numberWithDouble:value] forKey:@"pointSize"];
  [self didChangeValueForKey:@"pointSize"];
  [self reannotatePDFDataUsingPDFKeywords:YES];
}
//end setPointSize:

-(NSDate*) date
{
  NSDate* result = nil;
  [self willAccessValueForKey:@"date"];
  result = [self primitiveValueForKey:@"date"];
  [self didAccessValueForKey:@"date"];
  return result;
} 
//end date

-(void) setDate:(NSDate*)value
{
  [self willChangeValueForKey:@"date"];
  [self setPrimitiveValue:value forKey:@"date"];
  [self didChangeValueForKey:@"date"];
}
//end setDate:

-(latex_mode_t)mode
{
  latex_mode_t result = 0;
  [self willAccessValueForKey:@"modeAsInteger"];
  result = (latex_mode_t)[[self primitiveValueForKey:@"modeAsInteger"] intValue];
  [self didAccessValueForKey:@"modeAsInteger"];
  return result;
}
//end mode

-(void) setMode:(latex_mode_t)value
{
  [self willChangeValueForKey:@"modeAsInteger"];
  [self setPrimitiveValue:[NSNumber numberWithInt:(int)value] forKey:@"modeAsInteger"];
  [self didChangeValueForKey:@"modeAsInteger"];
  [self reannotatePDFDataUsingPDFKeywords:YES];
}
//end setMode:

-(NSColor*) backgroundColor
{
  NSColor* result = nil;
  [self willAccessValueForKey:@"backgroundColor"];
  result = [self primitiveValueForKey:@"backgroundColor"];
  [self didAccessValueForKey:@"backgroundColor"];
  if (!result)
  {
    [self willAccessValueForKey:@"backgroundColorAsData"];
    NSData* archivedData = [self primitiveValueForKey:@"backgroundColorAsData"];
    [self didAccessValueForKey:@"backgroundColorAsData"];
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self setPrimitiveValue:result forKey:@"backgroundColor"];
  }//end if (!result)
  return result;
}
//end backgroundColor

-(void) setBackgroundColor:(NSColor*)value
{
  NSColor* grayLevelColor = [value colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
  value = ([grayLevelColor whiteComponent] == 1.0f) ? nil : value;
  [self willChangeValueForKey:@"backgroundColor"];
  [self setPrimitiveValue:value forKey:@"backgroundColor"];
  [self didChangeValueForKey:@"backgroundColor"];
  NSData* archivedData = !value ? nil : [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"backgroundColorAsData"];
  [self setPrimitiveValue:archivedData forKey:@"backgroundColorAsData"];
  [self didChangeValueForKey:@"backgroundColorAsData"];
  [self reannotatePDFDataUsingPDFKeywords:YES];
}
//end setBackgroundColor:

-(NSString*) title
{
  NSString* result = nil;
  [self willAccessValueForKey:@"title"];
  result = [self primitiveValueForKey:@"title"];
  [self didAccessValueForKey:@"title"];
  return result;
}
//end title

-(void) setTitle:(NSString*)value
{
  NSString* oldTitle = [self title];
  if ((value != oldTitle) && ![value isEqualToString:oldTitle])
  {
    [self willChangeValueForKey:@"title"];
    [self setPrimitiveValue:value forKey:@"title"];
    [self didChangeValueForKey:@"title"];
    [self reannotatePDFDataUsingPDFKeywords:YES];
  }//end if ((value != oldTitle) && ![value isEqualToString:oldTitle])
}
//end setTitle:

-(NSImage*) pdfCachedImage
{
  NSImage* result = nil;
  [self willAccessValueForKey:@"pdfCachedImage"];
  @synchronized(self)
  {
    result = self->pdfCachedImage;
    if (result)
    {
      BOOL hasPdfOrBitmapImageRep = NO;
      NSArray* representations = [result representations];
      int i = 0;
      int count = [representations count];
      for(i = 0 ; !hasPdfOrBitmapImageRep && (i<count) ; ++i)
      {
        id representation = [representations objectAtIndex:i];
        hasPdfOrBitmapImageRep |=
          [representation isKindOfClass:[NSPDFImageRep class]] |
          [representation isKindOfClass:[NSBitmapImageRep class]];
      }//end for each representation
      if (!hasPdfOrBitmapImageRep)
      {
        [self->pdfCachedImage release];
        result = nil;
      }//end if (!hasPdfOrBitmapImageRep)
    }//end if (result)
    
    if (!result)
    {
      NSData* pdfData = [self pdfData];
      NSPDFImageRep* pdfImageRep = !pdfData ? nil : [[NSPDFImageRep alloc] initWithData:pdfData];
      if (pdfImageRep)
      {
        self->pdfCachedImage = [[NSImage alloc] initWithSize:[pdfImageRep size]];
        [self->pdfCachedImage setCacheMode:NSImageCacheNever];
        [self->pdfCachedImage setDataRetained:YES];
        [self->pdfCachedImage setScalesWhenResized:YES];
        [self->pdfCachedImage addRepresentation:pdfImageRep];
        if (![self->pdfCachedImage bitmapImageRepresentationWithMaxSize:NSMakeSize(0, 128)])//to help drawing in library
          [self->pdfCachedImage bitmapImageRepresentation];
        [pdfImageRep release];
        result = self->pdfCachedImage;
      }//end if (pdfImageRep)
    }//end if (!result)
  }//end @synchronized(self)
  [self didAccessValueForKey:@"pdfCachedImage"];
  return result;
} 
//end pdfCachedImage

-(NSString*) modeAsString
{
  NSString* result = [[self class] latexModeToString:[self mode]];
  return result;
}
//end modeAsString

-(CHExportPrefetcher*) exportPrefetcher
{
  return self->exportPrefetcher;
}
//end exportPrefetcher

+(NSString*) latexModeToString:(latex_mode_t)mode
{
  NSString* result = nil;
  switch(mode)
  {
    case LATEX_MODE_ALIGN:
      result = @"align";
      break;
    case LATEX_MODE_EQNARRAY:
      result = @"eqnarray";
      break;
    case LATEX_MODE_DISPLAY:
      result = @"display";
      break;
    case LATEX_MODE_INLINE:
      result = @"inline";
      break;
    case LATEX_MODE_TEXT:
      result = @"text";
      break;
    case LATEX_MODE_AUTO:
      result = @"auto";
      break;
  }
  return result;
}
//end latexModeToString:

+(latex_mode_t) latexModeFromString:(NSString*)modeAsString
{
  latex_mode_t result = LATEX_MODE_DISPLAY;
  if ([modeAsString isEqualToString:@"align"])
    result = LATEX_MODE_ALIGN;
  else if ([modeAsString isEqualToString:@"eqnarray"])
    result = LATEX_MODE_EQNARRAY;
  else if ([modeAsString isEqualToString:@"display"])
    result = LATEX_MODE_DISPLAY;
  else if ([modeAsString isEqualToString:@"inline"])
    result = LATEX_MODE_INLINE;
  else if ([modeAsString isEqualToString:@"text"])
    result = LATEX_MODE_TEXT;
  return result;
}
//end latexModeFromString:

//latex source code (preamble+body) typed by the user. This WON'T add magnification, auto-bounding, coloring.
//It is a summary of what the user did effectively type. We just add \begin{document} and \end{document}
-(NSString*) string
{
  return [NSString stringWithFormat:@"%@\n\\begin{document}\n%@\n\\end{document}", [[self preamble] string], [[self sourceText] string]];
}
//end string

-(NSAttributedString*) encapsulatedSource//the body, with \[...\], $...$ or nothing according to the mode
{
  NSMutableAttributedString* result = [[[NSMutableAttributedString alloc] initWithAttributedString:[self sourceText]] autorelease];
  switch([self mode])
  {
    case LATEX_MODE_DISPLAY:
      [result insertAttributedString:[[[NSAttributedString alloc] initWithString:@"\\["] autorelease] atIndex:0];
      [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\\]"] autorelease]];
      break;
    case LATEX_MODE_INLINE:
      [result insertAttributedString:[[[NSAttributedString alloc] initWithString:@"$"] autorelease] atIndex:0];
      [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"$"] autorelease]];
      break;
    case LATEX_MODE_EQNARRAY:
      [result insertAttributedString:[[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}"] autorelease] atIndex:0];
      [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\\end{eqnarray*}"] autorelease]];
      break;
    case LATEX_MODE_ALIGN:
      [result insertAttributedString:[[[NSAttributedString alloc] initWithString:@"\\begin{align*}"] autorelease] atIndex:0];
      [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\\end{align*}"] autorelease]];
      break;
    case LATEX_MODE_TEXT:
      break;
    case LATEX_MODE_AUTO:
      break;
  }
  return result;
}
//end encapsulatedSource

/*
+(double) baselineFromData:(NSData*)someData
{
  double result = 0;

  BOOL decodedFromAnnotation = NO;
  BOOL shoudDecodeFromAnnotations = YES;
  if (shoudDecodeFromAnnotations)
  {
    PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:someData];
    PDFPage*     pdfPage     = [pdfDocument pageAtIndex:0];
    NSArray* annotations     = [pdfPage annotations];
    NSDictionary* embeddedInfos = nil;
    NSUInteger i = 0;
    for(i = 0 ; !embeddedInfos && (i < [annotations count]) ; ++i)
    {
      id annotation = [annotations objectAtIndex:i];
      if ([annotation isKindOfClass:[PDFAnnotationText class]])
      {
        PDFAnnotationText* annotationTextCandidate = (PDFAnnotationText*)annotation;
        if ([[annotationTextCandidate userName] isEqualToString:@"fr.chachatelier.pierre.LaTeXiT"])
        {
          NSString* contents = [annotationTextCandidate contents];
          NSData* data = !contents ? nil : [NSData dataWithBase64:contents];
          @try{
            embeddedInfos = [NSKeyedUnarchiver unarchiveObjectWithData:data];
          }
          @catch(NSException* e){
            DebugLog(0, @"exception : %@", e);
          }
        }//end if ([[annotationTextCandidate userName] isEqualToString:@"fr.chachatelier.pierre.LaTeXiT"])
      }//end if ([annotation isKindOfClass:PDFAnnotationText])
    }//end for each annotation
    if (embeddedInfos)
    {
      NSNumber* baselineAsNumber = [embeddedInfos objectForKey:@"baseline"];
      result = [baselineAsNumber doubleValue];
      decodedFromAnnotation = YES;
    }//end if (embeddedInfos)
    [pdfDocument release];
  }//end if (shoudDecodeFromAnnotations)
  
  if (!decodedFromAnnotation)
  {
    NSMutableString* equationBaselineAsString = [NSMutableString stringWithString:@"0"];
    NSString* dataAsString = [[[NSString alloc] initWithData:someData encoding:NSASCIIStringEncoding] autorelease];
    NSArray*  testArray    = [dataAsString componentsSeparatedByString:@"/Baseline (EEbas"];
    if (testArray && ([testArray count] >= 2))
    {
      [equationBaselineAsString setString:[testArray objectAtIndex:1]];
      NSRange range = [equationBaselineAsString rangeOfString:@"EEbasend"];
      range.length  = (range.location != NSNotFound) ? [equationBaselineAsString length]-range.location : 0;
      [equationBaselineAsString deleteCharactersInRange:range];
      result = [equationBaselineAsString doubleValue];
    }
  }//end if (!decodedFromAnnotation)
  
  return result;
}
//end baselineFromData
*/

-(NSString*) titleAuto
{
  NSString* result = [[[self sourceText] string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  unsigned int endIndex = MIN(17U, [result length]);
  result = [result substringToIndex:endIndex];
  return result;
}
//end titleAuto

//useful to resynchronize the pdfData with the actual parameters (background color...)
//its use if VERY rare, so that it is not automatic for the sake of efficiency
-(void) reannotatePDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords
{
  self->annotateDataDirtyState |= YES;
  if (![self isUpdating])
  {
    NSData* newData = [self annotatedPDFDataUsingPDFKeywords:usingPDFKeywords];
    [self setPdfData:newData];
  }//end if (![self isUpdating])
}
//end reannotatePDFDataUsingPDFKeywords:

-(NSData*) annotatedPDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords
{
  NSData* result = [self pdfData];

   /*
  //first, we retreive the baseline if possible
  double baseline = 0;

  NSData* pdfData = result;
  NSString* dataAsString = [[[NSString alloc] initWithData:pdfData encoding:NSASCIIStringEncoding] autorelease];
  NSArray* testArray = nil;
  NSMutableString* baselineAsString = @"0";
  testArray = [dataAsString componentsSeparatedByString:@"/Baseline (EEbas"];
  if (testArray && ([testArray count] >= 2))
  {
    [baselineAsString setString:[testArray objectAtIndex:1]];
    NSRange range = [baselineAsString rangeOfString:@"EEbasend"];
    range.length = (range.location != NSNotFound) ? [baselineAsString length]-range.location : 0;
    [baselineAsString deleteCharactersInRange:range];
  }
  baseline = [baselineAsString doubleValue];
  
  [self setBaseline:baseline];

  //then, we rewrite the pdfData
  #warning 64bits problem
  BOOL shouldDenyDueTo64Bitsproblem = (sizeof(NSInteger) != 4);
  if (usingPDFKeywords && !shouldDenyDueTo64Bitsproblem);
  {
    PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
    NSDictionary* attributes =
      [NSDictionary dictionaryWithObjectsAndKeys:
          [[NSWorkspace sharedWorkspace] applicationName], PDFDocumentCreatorAttribute,
         nil];
    [pdfDocument setDocumentAttributes:attributes];
    result = [pdfDocument dataRepresentation];
    [pdfDocument release];
  }
  */

  //annotate in LEE format
  result = [[LaTeXProcessor sharedLaTeXProcessor] annotatePdfDataInLEEFormat:result
              preamble:[[self preamble] string] source:[[self sourceText] string]
                 color:[self color] mode:[self mode] magnification:[self pointSize] baseline:[self baseline]
       backgroundColor:[self backgroundColor] title:[self title]];
  return result;
}
//end annotatedPDFDataUsingPDFKeywords:usingPDFKeywords

//to feed a pasteboard. It needs a document, because there may be some temporary files needed for certain kind of data
//the lazyDataProvider, if not nil, is the one who will call [pasteboard:provideDataForType] *as needed* (to save time)
-(void) writeToPasteboard:(NSPasteboard *)pboard exportFormat:(export_format_t)exportFormat isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider
{
  //LinkBack pasteboard
  NSArray* latexitEquationArray = [NSArray arrayWithObject:self];
  NSData*  latexitEquationData  = [NSKeyedArchiver archivedDataWithRootObject:latexitEquationArray];
  NSDictionary* linkBackPlist =
    isLinkBackRefresh ? [NSDictionary linkBackDataWithServerName:[[NSWorkspace sharedWorkspace] applicationName] appData:latexitEquationData
                                      actionName:LinkBackRefreshActionName suggestedRefreshRate:0]
                      : [NSDictionary linkBackDataWithServerName:[[NSWorkspace sharedWorkspace] applicationName] appData:latexitEquationData]; 
  
  if (isLinkBackRefresh)
    [pboard declareTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:self];
  else
    [pboard addTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:self];
  [pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];

  NSData* pdfData = [self pdfData];
  //[pboard addTypes:[NSArray arrayWithObject:NSFileContentsPboardType] owner:self];
  //[pboard setData:pdfData forType:NSFileContentsPboardType];

  //no NSStringPboardType because of stupid Pages
  //[pboard addTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
  //[pboard setString:[[self sourceText] string] forType:NSStringPboardType];
  
  PreferencesController* preferencesController = [PreferencesController sharedController];

  //Stores the data in the pasteboard corresponding to what the user asked for (pdf, jpeg, tiff...)
  [self->exportPrefetcher invalidateAllData];
  if (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    [self->exportPrefetcher prefetchForFormat:exportFormat pdfData:pdfData];
  NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithFloat:[preferencesController exportJpegQualityPercent]], @"jpegQuality",
                                 [NSNumber numberWithFloat:[preferencesController exportScalePercent]], @"scaleAsPercent",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportPreamble]], @"textExportPreamble",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportEnvironment]], @"textExportEnvironment",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportBody]], @"textExportBody",
                                 [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                 nil];
  NSData* data = lazyDataProvider ? nil :
    (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) ?
  [self->exportPrefetcher fetchDataForFormat:exportFormat wait:YES] : 
      nil;
  if (!data && !lazyDataProvider)
    data = 
      [[LaTeXProcessor sharedLaTeXProcessor]
        dataForType:exportFormat pdfData:pdfData
        exportOptions:exportOptions
        compositionConfiguration:[preferencesController compositionConfigurationDocument]
        uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  //feeds the right pasteboard according to the type (pdf, eps, tiff, jpeg, png...)
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
      [pboard addTypes:[NSArray arrayWithObjects:NSPDFPboardType, @"com.adobe.pdf", nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSPDFPboardType];
      if (!lazyDataProvider) [pboard setData:data forType:@"com.adobe.pdf"];
      break;
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
      [pboard addTypes:[NSArray arrayWithObjects:NSPDFPboardType, @"com.adobe.pdf", nil]
                 owner:lazyDataProvider ? lazyDataProvider : self];
      if (data && (!lazyDataProvider || (lazyDataProvider != self))) [pboard setData:data forType:NSPDFPboardType];
      if (data && (!lazyDataProvider || (lazyDataProvider != self))) [pboard setData:data forType:@"com.adobe.pdf"];
      break;
    case EXPORT_FORMAT_EPS:
      [pboard addTypes:[NSArray arrayWithObjects:NSPostScriptPboardType, @"com.adobe.encapsulated-postscript", nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSPostScriptPboardType];
      if (!lazyDataProvider) [pboard setData:data forType:@"com.adobe.encapsulated-postscript"];
      break;
    case EXPORT_FORMAT_PNG:
      /*[pboard addTypes:[NSArray arrayWithObjects:NSTIFFPboardType, nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSTIFFPboardType];*/
      [pboard addTypes:[NSArray arrayWithObjects:GetMyPNGPboardType(), nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:GetMyPNGPboardType()];
      break;
    case EXPORT_FORMAT_JPEG:
      /*[pboard addTypes:[NSArray arrayWithObjects:NSTIFFPboardType, nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSTIFFPboardType];*/
      [pboard addTypes:[NSArray arrayWithObjects:GetMyJPEGPboardType(), nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:GetMyJPEGPboardType()];
      break;
    case EXPORT_FORMAT_TIFF:
      [pboard addTypes:[NSArray arrayWithObjects:NSTIFFPboardType, @"public.tiff", nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSTIFFPboardType];
      if (!lazyDataProvider) [pboard setData:data forType:@"public.tiff"];
      break;
    case EXPORT_FORMAT_MATHML:
      [pboard addTypes:[NSArray arrayWithObjects:NSHTMLPboardType, @"public.html", nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSHTMLPboardType];
      if (!lazyDataProvider) [pboard setData:data forType:@"public.html"];
      {
        NSString* documentString = !data ? nil : [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        NSString* blockQuote = [documentString stringByMatching:@"<blockquote(.*?)>.*</blockquote>" options:RKLDotAll inRange:NSMakeRange(0, [documentString length]) capture:0 error:0];
        [pboard addTypes:[NSArray arrayWithObjects:NSStringPboardType, @"public.text", nil] owner:lazyDataProvider];
        if (blockQuote)
        {
          if (!lazyDataProvider) [pboard setString:blockQuote forType:NSStringPboardType];
          if (!lazyDataProvider) [pboard setString:blockQuote forType:@"public.text"];
        }//end if (blockQuote)
      }
      break;
    case EXPORT_FORMAT_SVG:
      [pboard addTypes:[NSArray arrayWithObjects:GetMySVGPboardType(), @"public.svg-image", nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:GetMySVGPboardType()];
      if (!lazyDataProvider) [pboard setData:data forType:@"public.svg-image"];
      break;
    case EXPORT_FORMAT_TEXT:
      [pboard addTypes:[NSArray arrayWithObjects:NSStringPboardType, @"public.text", nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSStringPboardType];
      if (!lazyDataProvider) [pboard setData:data forType:@"public.text"];
      break;
  }//end switch
}
//end writeToPasteboard:isLinkBackRefresh:lazyDataProvider:

//provides lazy data to a pasteboard
-(void) pasteboard:(NSPasteboard *)pasteboard provideDataForType:(NSString*)type
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithFloat:[preferencesController exportJpegQualityPercent]], @"jpegQuality",
                                 [NSNumber numberWithFloat:[preferencesController exportScalePercent]], @"scaleAsPercent",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportPreamble]], @"textExportPreamble",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportEnvironment]], @"textExportEnvironment",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportBody]], @"textExportBody",
                                 [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                 nil];
  export_format_t exportFormat = [preferencesController exportFormatCurrentSession];
  NSData* data = (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) ?
    [self->exportPrefetcher fetchDataForFormat:exportFormat wait:YES] :
    nil;
  if (!data)
    data = [[LaTeXProcessor sharedLaTeXProcessor]
            dataForType:exportFormat
                pdfData:[self pdfData]
              exportOptions:exportOptions
            compositionConfiguration:[preferencesController compositionConfigurationDocument]
            uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  if (exportFormat == EXPORT_FORMAT_MATHML)
  {
    NSString* documentString = !data ? nil : [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    NSString* blockQuote = [documentString stringByMatching:@"<blockquote(.*?)>.*</blockquote>" options:RKLDotAll inRange:NSMakeRange(0, [documentString length]) capture:0 error:0];
    if (blockQuote)
      [pasteboard setString:blockQuote forType:type];
  }//end if (exportFormat == EXPORT_FORMAT_MATHML)
  else
    [pasteboard setData:data forType:type];
}
//end pasteboard:provideDataForType:
-(id) plistDescription
{
  NSMutableDictionary* plist = 
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
       @"2.7.5", @"version",
       [self pdfData], @"pdfData",
       [[self preamble] string], @"preamble",
       [[self sourceText] string], @"sourceText",
       [[self color] rgbaString], @"color",
       [NSNumber numberWithDouble:[self pointSize]], @"pointSize",
       [self modeAsString], @"mode",
       [self date], @"date",
       nil];
  if ([self backgroundColor])
    [plist setObject:[[self backgroundColor] rgbaString] forKey:@"backgroundColor"];
  if ([self title])
    [plist setObject:[self title] forKey:@"title"];
  return plist;
}
//end plistDescription

-(id) initWithDescription:(id)description
{
  NSManagedObjectContext* managedObjectContext = [LatexitEquation currentManagedObjectContext];
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  [self beginUpdate];
  [self setPdfData:[description objectForKey:@"pdfData"]];
  NSString* string = [description objectForKey:@"preamble"];
  [self setPreamble:(!string ? nil : [[[NSAttributedString alloc] initWithString:string] autorelease])];
  string = [description objectForKey:@"sourceText"];
  [self setSourceText:(!string ? nil : [[[NSAttributedString alloc] initWithString:string] autorelease])];
  [self setColor:[NSColor colorWithRgbaString:[description objectForKey:@"color"]]];
  [self setPointSize:[[description objectForKey:@"pointSize"] doubleValue]];
  [self setMode:[[self class] latexModeFromString:[description objectForKey:@"mode"]]];
  [self setDate:[description objectForKey:@"date"]];
  [self setBackgroundColor:[NSColor colorWithRgbaString:[description objectForKey:@"backgroundColor"]]];
  [self setTitle:[description objectForKey:@"title"]];
  [self endUpdate];
  return self;
}
//end initWithDescription:

@end
