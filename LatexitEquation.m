//
//  LatexitEquation.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/10/08.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "LatexitEquation.h"

#import "CHExportPrefetcher.h"
#import "Compressor.h"
#import "FileManagerHelper.h"
#import "LatexitEquationData.h"
#import "LaTeXProcessor.h"
#import "NSMutableArrayExtended.h"
#import "NSColorExtended.h"
#import "NSDataExtended.h"
#import "NSFileManagerExtended.h"
#import "NSFontExtended.h"
#import "NSImageExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSObjectExtended.h"
#import "NSStringExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "RegexKitLite.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>

#import <Quartz/Quartz.h>

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#else
#define ARC_ENABLED
//#define CHBRIDGE CHBRIDGE
#endif

@interface LaTeXiTMetaDataParsingContext : NSObject
{
  BOOL latexitMetadataStarted;
  NSMutableString* latexitMetadataString;
  id latexitMetadata;
  CGPoint* curvePoints;
  size_t curvePointsCapacity;
  size_t curvePointsSize;
}

@property BOOL latexitMetadataStarted;
-(NSMutableString*) latexitMetadataString;
@property (strong) id latexitMetadata;
-(void) resetCurvePoints;
-(void) appendCurvePoint:(CGPoint)point;
-(void) checkMetadataFromCurvePointBytes;
-(void) checkMetadataFromString:(NSString*)string;

@end //LaTeXiTMetaDataParsingContext

@implementation LaTeXiTMetaDataParsingContext

-(id) init
{
  if (!((self = [super init])))
    return nil;
  self->latexitMetadataStarted = NO;
  self->latexitMetadataString = [[NSMutableString alloc] init];
  self->latexitMetadata = nil;
  self->curvePoints = 0;
  self->curvePointsCapacity = 0;
  self->curvePointsSize = 0;
  return self;
}
//end init

@synthesize latexitMetadataStarted;

-(NSMutableString*) latexitMetadataString
{
  return self->latexitMetadataString;
}
//end latexitMetadataString

@synthesize latexitMetadata;

-(void) resetCurvePoints
{
  self->curvePointsSize = 0;
}
//end resetCurvePoints:

-(void) appendCurvePoint:(CGPoint)point
{
  DebugLog(1, @"(%.20f,%.20f)", point.x, point.y);
  if (self->curvePointsSize+1 > self->curvePointsCapacity)
  {
    size_t newCapacity = MAX(64U, 2*self->curvePointsCapacity);
    self->curvePoints = (CGPoint*)reallocf(self->curvePoints, newCapacity*sizeof(CGPoint));
    self->curvePointsCapacity = !self->curvePoints ? 0 : newCapacity;
    self->curvePointsSize = MIN(self->curvePointsSize, self->curvePointsCapacity);
  }//end if (self->curvePointsSize+1 > self->curvePointsCapacity)
  if (self->curvePointsSize+1 <= self->curvePointsCapacity)
    self->curvePoints[self->curvePointsSize++] = point;
}
//end appendCurvePoint:

-(void) checkMetadataFromCurvePointBytes
{
  NSMutableString* candidateString = nil;
  const CGPoint* src = self->curvePoints;
  const CGPoint* srcEnd = self->curvePoints+self->curvePointsSize;
  double epsilon = 1e-6;
  for( ; src != srcEnd ; ++src)
  {
    BOOL isIntegerX = (ABS(src->x-floor(src->x)) <= epsilon);
    BOOL isValidIntegerX = isIntegerX && (src->x >= 0) && (src->x <= 255);
    BOOL isIntegerY = (ABS(src->y-floor(src->y)) <= epsilon);
    BOOL isValidIntegerY = isIntegerY && (src->y >= 0) && (src->y <= 255);
    if (isValidIntegerX && isValidIntegerY)
    {
      candidateString = !candidateString ? [[NSMutableString alloc] init] : candidateString;
      [candidateString appendFormat:@"%c%c", (char)(unsigned char)src->x, (char)(unsigned char)src->y];
    }//end if (isValidIntegerX && isValidIntegerY)
  }//end for each point
  [self checkMetadataFromString:candidateString];
}
//end checkMetadataFromCurvePointBytes

-(void) checkMetadataFromString:(NSString*)string
{
  NSError* error = nil;
  NSArray* components =
    [string captureComponentsMatchedByRegex:@"^\\<latexit sha1_base64=\"(.*?)\"\\>(.*?)\\</latexit\\>\\x00*$"
                                    options:RKLMultiline|RKLDotAll
                                      range:NSMakeRange(0, [string length]) error:&error];
  if ([components count] == 3)
  {
    DebugLogStatic(1, @"this is metadata : %@", string);
    NSString* sha1Base64 = [components objectAtIndex:1];
    NSString* dataBase64Encoded = [components objectAtIndex:2];
    NSString* dataBase64EncodedSha1Base64 = [[dataBase64Encoded dataUsingEncoding:NSUTF8StringEncoding] sha1Base64];
    NSData* compressedData = [sha1Base64 isEqualToString:dataBase64EncodedSha1Base64] ?
      [NSData dataWithBase64:dataBase64Encoded encodedWithNewlines:NO] :
      nil;
    NSData* uncompressedData = !compressedData ? nil : [Compressor zipuncompress:compressedData];
    NSPropertyListFormat format = 0;
    id plist = !uncompressedData ? nil :
      [NSPropertyListSerialization propertyListWithData:uncompressedData
        options:NSPropertyListImmutable format:&format error:nil];
    NSDictionary* plistAsDictionary = [plist dynamicCastToClass:[NSDictionary class]];
    if (plistAsDictionary)
      [self setLatexitMetadata:plistAsDictionary];
  }//end if ([components count] == 3)
}
//end checkMetadataFromString:

@end //LaTeXiTMetaDataParsingContext

static BOOL objectDiffers(id o1, id o2)
{
  BOOL result = (o1 && !o2) || (!o1 && o2) || ((o1 != o2) && ![o1 isEqualTo:o2]);
  return result;
}
//end objectDiffers()

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
        NSData *data = CFBridgingRelease(CGPDFStreamCopyData(stream, &dataFormat));
        if (data && (dataFormat == CGPDFDataFormatRaw))
          [((__bridge NSMutableArray*) info) addObject:data];
      }//end if (CGPDFArrayGetStream(array, i, &stream))
    }//end for each object
  }//end if (CGPDFObjectGetValue(object, kCGPDFObjectTypeArray, &array))
  else if (CGPDFObjectGetValue(object, kCGPDFObjectTypeStream, &stream))
  {
    CGPDFDataFormat dataFormat = 0;
    NSData *data = CFBridgingRelease(CGPDFStreamCopyData(stream, &dataFormat));
    if (data && (dataFormat == CGPDFDataFormatRaw))
      [((__bridge NSMutableArray*) info) addObject:data];
  }//end if (CGPDFObjectGetValue(object, kCGPDFObjectTypeStream, &stream))
}
//end extractStreamObjectsFunction()

static void CHCGPDFOperatorCallback_b(CGPDFScannerRef scanner, void *info)
{
  //closepath,fill,stroke
  DebugLogStatic(1, @"<b (closepath,fill,stroke)>");
}
//end CHCGPDFOperatorCallback_b()

static void CHCGPDFOperatorCallback_bstar(CGPDFScannerRef scanner, void *info)
{
  //closepath, fill, stroke (EO)
  DebugLogStatic(1, @"<b* (closepath, fill, stroke) (EO)>");
}
//end CHCGPDFOperatorCallback_bstar()

static void CHCGPDFOperatorCallback_B(CGPDFScannerRef scanner, void *info)
{
  //fill, stroke
  DebugLogStatic(1, @"<B (fill,stroke)>");
}
//end CHCGPDFOperatorCallback_B()

static void CHCGPDFOperatorCallback_Bstar(CGPDFScannerRef scanner, void *info)
{
  //fill, stroke (EO)
  DebugLogStatic(1, @"<B* (closepath, fill, stroke) (EO)>");
}
//end CHCGPDFOperatorCallback_Bstar()

static void CHCGPDFOperatorCallback_c(CGPDFScannerRef scanner, void *info)
{
  //curveto (3 points)
  DebugLogStatic(1, @"<c (curveto)>");
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(__bridge id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
  CGPDFReal valueNumber1 = 0;
  CGPDFReal valueNumber2 = 0;
  CGPDFReal valueNumber3 = 0;
  CGPDFReal valueNumber4 = 0;
  CGPDFReal valueNumber5 = 0;
  CGPDFReal valueNumber6 = 0;
  BOOL ok = YES;
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber6);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber5);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber4);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber3);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber2);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber1);
  [pdfScanningContext appendCurvePoint:CGPointMake(valueNumber1, valueNumber2)];
  [pdfScanningContext appendCurvePoint:CGPointMake(valueNumber3, valueNumber4)];
  [pdfScanningContext appendCurvePoint:CGPointMake(valueNumber5, valueNumber6)];
}
//end CHCGPDFOperatorCallback_c()

static void CHCGPDFOperatorCallback_cs(CGPDFScannerRef scanner, void *info)
{
  //set color space (for non stroking)
  DebugLogStatic(1, @"<cs (set color space (for non stroking)>,");
}
//end CHCGPDFOperatorCallback_cs()

static void CHCGPDFOperatorCallback_h(CGPDFScannerRef scanner, void *info)
{
  //close subpath
  DebugLogStatic(1, @"<h (close subpath)>");
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(__bridge id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
  [pdfScanningContext checkMetadataFromCurvePointBytes];
  [pdfScanningContext resetCurvePoints];
}
//end CHCGPDFOperatorCallback_h()

static void CHCGPDFOperatorCallback_l(CGPDFScannerRef scanner, void *info)
{
  //lineto (1 point)
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(__bridge id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
  DebugLogStatic(1, @"<l (lineto)>");
  CGPDFReal valueNumber1 = 0;
  CGPDFReal valueNumber2 = 0;
  BOOL ok = YES;
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber2);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber1);
  [pdfScanningContext appendCurvePoint:CGPointMake(valueNumber1, valueNumber2)];
}
//end CHCGPDFOperatorCallback_l()

static void CHCGPDFOperatorCallback_m(CGPDFScannerRef scanner, void *info)
{
  //moveto (new subpath)
  DebugLogStatic(1, @"<m (moveto) (new subpath)>");
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(__bridge id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
  [pdfScanningContext resetCurvePoints];
}
//end CHCGPDFOperatorCallback_m()

static void CHCGPDFOperatorCallback_n(CGPDFScannerRef scanner, void *info)
{
  //end path (no fill, no stroke)
  DebugLogStatic(1, @"<n end path (no fill, no stroke)>");
}
//end CHCGPDFOperatorCallback_n()

static void CHCGPDFOperatorCallback_Tj(CGPDFScannerRef scanner, void *info)
{
  CGPDFStringRef pdfString = 0;
  BOOL okString = CGPDFScannerPopString(scanner, &pdfString);
  if (okString)
  {
    CFStringRef cfString = CGPDFStringCopyTextString(pdfString);
    #ifdef ARC_ENABLED
    NSString* string = (CHBRIDGE NSString*)cfString;
    #else
    NSString* string = [(NSString*)cfString autorelease];
    #endif
    DebugLogStatic(1, @"PDF scanning found <%@>", string);
    
    LaTeXiTMetaDataParsingContext* pdfScanningContext = [(__bridge id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];

    BOOL isStartingLatexitMetadata = [string isMatchedByRegex:@"^\\<latexit sha1_base64=\""];
    if (isStartingLatexitMetadata)
    {
      [pdfScanningContext setLatexitMetadataStarted:YES];
      [[pdfScanningContext latexitMetadataString] setString:@""];
    }//end if (isStartingLatexitMetadata)

    BOOL isLatexitMetadataStarted = [pdfScanningContext latexitMetadataStarted];
    NSMutableString* latexitMedatataString = [pdfScanningContext latexitMetadataString];

    if (isLatexitMetadataStarted)
      [latexitMedatataString appendString:string];
    
    BOOL isStoppingLatexitMetadata = isLatexitMetadataStarted && [string isMatchedByRegex:@"\\</latexit\\>$"];
    if (isStoppingLatexitMetadata)
      [pdfScanningContext setLatexitMetadataStarted:NO];

    NSString* stringToMatch = latexitMedatataString;
    [pdfScanningContext checkMetadataFromString:stringToMatch];
  }//end if (okString)
}//end CHCGPDFOperatorCallback_Tj

static void CHCGPDFOperatorCallback_v(CGPDFScannerRef scanner, void *info)
{
  //curve
  DebugLogStatic(1, @"<v (curve)>");
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(__bridge id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
  CGPDFReal valueNumber1 = 0;
  CGPDFReal valueNumber2 = 0;
  CGPDFReal valueNumber3 = 0;
  CGPDFReal valueNumber4 = 0;    
  BOOL ok = YES;
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber4);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber3);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber2);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber1);
  [pdfScanningContext appendCurvePoint:CGPointMake(valueNumber1, valueNumber2)];
  [pdfScanningContext appendCurvePoint:CGPointMake(valueNumber3, valueNumber4)];
}
//end CHCGPDFOperatorCallback_v()

static void CHCGPDFOperatorCallback_y(CGPDFScannerRef scanner, void *info)
{
  //curveto
  DebugLogStatic(1, @"<y (curveto)>");
  CGPDFReal valueNumber1 = 0;
  CGPDFReal valueNumber2 = 0;
  CGPDFReal valueNumber3 = 0;
  CGPDFReal valueNumber4 = 0;
  BOOL ok = YES;
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber4);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber3);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber2);
  ok = ok && CGPDFScannerPopNumber(scanner, &valueNumber1);
}
//end CHCGPDFOperatorCallback_y()

NSString*const LatexitEquationsPboardType = @"LatexitEquationsPboardType";

static NSEntityDescription* cachedEntity = nil;
static NSMutableArray*      managedObjectContextStackInstance = nil;

@interface LatexitEquation ()
+(NSMutableArray*) managedObjectContextStack;
@property (getter=isUpdating, readonly) BOOL updating;
@end

@implementation LatexitEquation

+(NSEntityDescription*) entity
{
  if (!cachedEntity)
  {
    @synchronized(self)
    {
      if (!cachedEntity)
        cachedEntity = [[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel].entitiesByName[NSStringFromClass([self class])];
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
    id context = managedObjectContextStackInstance.lastObject;
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
  NSFont* defaultFont = preferencesController.editionFont;
  NSDictionary* defaultAttributes = @{NSFontAttributeName: defaultFont};
  NSAttributedString* defaultPreambleAttributedString =
    [[PreferencesController sharedController] preambleDocumentAttributedString];

  BOOL decodedFromAnnotation = NO;
  BOOL shoudDecodeFromAnnotations = YES;
  DebugLog(1, @"shoudDecodeFromAnnotations = %d", shoudDecodeFromAnnotations);
  if (shoudDecodeFromAnnotations)
  {
    PDFDocument* pdfDocument = nil;
    NSDictionary* embeddedInfos = nil;
    @try{
      pdfDocument = [[PDFDocument alloc] initWithData:someData];
      PDFPage*     pdfPage     = [pdfDocument pageAtIndex:0];
      NSArray* annotations     = pdfPage.annotations;
      NSUInteger i = 0;
      DebugLog(1, @"annotations = %@", annotations);
      for(i = 0 ; !embeddedInfos && (i < annotations.count) ; ++i)
      {
        id annotation = annotations[i];
        if ([annotation isKindOfClass:[PDFAnnotationText class]])
        {
          PDFAnnotationText* annotationTextCandidate = (PDFAnnotationText*)annotation;
          DebugLog(1, @"annotationTextCandidate = %@", annotationTextCandidate);
          if ([annotationTextCandidate.userName isEqualToString:@"fr.chachatelier.pierre.LaTeXiT"])
          {
            NSString* contents = annotationTextCandidate.contents;
            NSData* data = !contents ? nil : [NSData dataWithBase64:contents];
            @try{
              embeddedInfos = [NSKeyedUnarchiver unarchiveObjectWithData:data];
              DebugLog(1, @"embeddedInfos = %@", embeddedInfos);
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
      pdfDocument = nil;
    }
    if (embeddedInfos)
    {
      DebugLog(1, @"embeddedInfos found = %@", embeddedInfos);
      NSString* preambleAsString = embeddedInfos[@"preamble"];
      NSAttributedString* preamble = !preambleAsString ? nil :
        [[NSAttributedString alloc] initWithString:preambleAsString attributes:defaultAttributes];
      result[@"preamble"] = (!preamble ? defaultPreambleAttributedString : preamble);
      preamble = nil;

      NSNumber* modeAsNumber = [embeddedInfos objectForKey:@"mode"];
      latex_mode_t mode = modeAsNumber ? (latex_mode_t)[modeAsNumber integerValue] :
                                         (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : LATEX_MODE_TEXT);
      [result setObject:@((mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode) forKey:@"mode"];

      NSString* sourceAsString = embeddedInfos[@"source"];
      NSAttributedString* sourceText =
        [[NSAttributedString alloc] initWithString:(!sourceAsString ? @"" : sourceAsString) attributes:defaultAttributes];
      if (mode == LATEX_MODE_EQNARRAY)
      {
        NSMutableAttributedString* sourceText2 = [[NSMutableAttributedString alloc] init];
        [sourceText2 appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] ];
        [sourceText2 appendAttributedString:sourceText];
        [sourceText2 appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] ];

        sourceText = sourceText2;
      }
      result[@"sourceText"] = sourceText;
      sourceText = nil;
      
      NSNumber* pointSizeAsNumber = [embeddedInfos objectForKey:@"magnification"];
      [result setObject:(pointSizeAsNumber ? pointSizeAsNumber :
                         @(useDefaults ? preferencesController.latexisationFontSize : 0))
                 forKey:@"magnification"];

      NSNumber* baselineAsNumber = [embeddedInfos objectForKey:@"baseline"];
      [result setObject:(baselineAsNumber ? baselineAsNumber : @(0.))
                 forKey:@"baseline"];

      NSColor* defaultColor = preferencesController.latexisationFontColor;
      NSColor* color = [NSColor colorWithData:embeddedInfos[@"color"]];
      result[@"color"] = (color ? color : (useDefaults ? defaultColor : [NSColor blackColor]));

      NSColor* defaultBKColor = [NSColor whiteColor];
      NSColor* backgroundColor = [NSColor colorWithData:embeddedInfos[@"backgroundColor"]];
      result[@"backgroundColor"] = (backgroundColor ? backgroundColor : (useDefaults ? defaultBKColor : [NSColor whiteColor]));

      NSString* titleAsString = embeddedInfos[@"title"];
      result[@"title"] = (!titleAsString ? @"" : titleAsString);

      result[@"date"] = [NSDate date];
      
      decodedFromAnnotation = YES;
      isLaTeXiTPDF = YES;
      DebugLog(1, @"decodedFromAnnotation = %d", decodedFromAnnotation);
    }//end if (embeddedInfos)
  }//end if (shoudDecodeFromAnnotations)
  
  BOOL shouldDecodeLEE = !isLaTeXiTPDF;
  DebugLog(1, @"shouldDecodeLEE = %d", shouldDecodeLEE);
  if (!isLaTeXiTPDF && shouldDecodeLEE)
  {
    NSString* dataAsString = [[NSString alloc] initWithData:someData encoding:NSMacOSRomanStringEncoding];
    NSArray*  testArray    = nil;
    
    NSMutableString* preambleString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Preamble (ESannop"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      preambleString = [NSMutableString stringWithString:testArray[1]];
      NSRange range = [preambleString rangeOfString:@"ESannopend"];
      range.length = (range.location != NSNotFound) ? preambleString.length-range.location : 0;
      [preambleString deleteCharactersInRange:range];
      [preambleString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, preambleString.length)];
      [preambleString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, preambleString.length)];
      [preambleString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, preambleString.length)];
      [preambleString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, preambleString.length)];
    }
    NSAttributedString* preamble =
      preambleString ? [[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes]
                     : (useDefaults ? defaultPreambleAttributedString
                                    : [[NSAttributedString alloc] initWithString:@"" attributes:defaultAttributes]);

    //test escaped preample from version 1.13.0
    testArray = [dataAsString componentsSeparatedByString:@"/EscapedPreamble (ESannoep"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      preambleString = [NSMutableString stringWithString:testArray[1]];
      NSRange range = [preambleString rangeOfString:@"ESannoepend"];
      range.length = (range.location != NSNotFound) ? preambleString.length-range.location : 0;
      [preambleString deleteCharactersInRange:range];
      NSString* unescapedPreamble =
    (NSString*)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault,
                                               (__bridge CFStringRef)preambleString, CFSTR("")));
      preambleString = [NSMutableString stringWithString:unescapedPreamble];
    }
    preamble = preambleString ? [[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes]
                              : preamble;
    result[@"preamble"] = preamble;

    NSMutableString* modeAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Type (EEtype"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      modeAsString  = [NSMutableString stringWithString:testArray[1]];
      NSRange range = [modeAsString rangeOfString:@"EEtypeend"];
      range.length = (range.location != NSNotFound) ? modeAsString.length-range.location : 0;
      [modeAsString deleteCharactersInRange:range];
    }
    latex_mode_t mode = modeAsString ? (latex_mode_t) [modeAsString integerValue]
                        : (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : 0);
    mode = (mode == LATEX_MODE_EQNARRAY) ? mode : validateLatexMode(mode); //Added starting from version 1.7.0
    [result setObject:@((mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode) forKey:@"mode"];

    NSMutableString* sourceString = [NSMutableString string];
    testArray = [dataAsString componentsSeparatedByString:@"/Subject (ESannot"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      [sourceString appendString:testArray[1]];
      NSRange range = [sourceString rangeOfString:@"ESannotend"];
      range.length = (range.location != NSNotFound) ? sourceString.length-range.location : 0;
      [sourceString deleteCharactersInRange:range];
      [sourceString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, sourceString.length)];
      [sourceString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, sourceString.length)];
      [sourceString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, sourceString.length)];
      [sourceString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, sourceString.length)];
    }
    NSAttributedString* sourceText =
      [[NSAttributedString alloc] initWithString:(!sourceString ? @"" : sourceString) attributes:defaultAttributes] ;

    //test escaped source from version 1.13.0
    testArray = [dataAsString componentsSeparatedByString:@"/EscapedSubject (ESannoes"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      [sourceString setString:@""];
      [sourceString appendString:testArray[1]];
      NSRange range = !sourceString ? NSMakeRange(0, 0) : [sourceString rangeOfString:@"ESannoesend"];
      range.length = (range.location != NSNotFound) ? sourceString.length-range.location : 0;
      [sourceString deleteCharactersInRange:range];
      NSString* unescapedSource =
    (NSString*)CFBridgingRelease(CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault,
                                               (__bridge CFStringRef)sourceString, CFSTR("")));
      [sourceString setString:unescapedSource];
    }
    sourceText = sourceString ? [[NSAttributedString alloc] initWithString:sourceString attributes:defaultAttributes]
                              : sourceText;

    if (mode == LATEX_MODE_EQNARRAY)
    {
      NSMutableAttributedString* sourceText2 = [[NSMutableAttributedString alloc] init];
      [sourceText2 appendAttributedString:
        [[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] ];
      [sourceText2 appendAttributedString:sourceText];
      [sourceText2 appendAttributedString:
        [[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes]];
      sourceText = sourceText2;
    }
    if (sourceText)
      result[@"sourceText"] = sourceText;

    NSMutableString* pointSizeAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Magnification (EEmag"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      pointSizeAsString = [NSMutableString stringWithString:testArray[1]];
      NSRange range = [pointSizeAsString rangeOfString:@"EEmagend"];
      range.length  = (range.location != NSNotFound) ? pointSizeAsString.length-range.location : 0;
      [pointSizeAsString deleteCharactersInRange:range];
    }
    result[@"magnification"] = @(pointSizeAsString ? pointSizeAsString.doubleValue : (useDefaults ? preferencesController.latexisationFontSize : 0));

    NSColor* defaultColor = preferencesController.latexisationFontColor;
    NSMutableString* colorAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Color (EEcol"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      colorAsString = [NSMutableString stringWithString:testArray[1]];
      NSRange range = [colorAsString rangeOfString:@"EEcolend"];
      range.length = (range.location != NSNotFound) ? colorAsString.length-range.location : 0;
      [colorAsString deleteCharactersInRange:range];
    }
    NSColor* color = colorAsString ? [NSColor colorWithRgbaString:colorAsString] : nil;
    if (!color)
      color = (useDefaults ? defaultColor : [NSColor blackColor]);
    result[@"color"] = color;

    NSColor* defaultBkColor = [NSColor whiteColor];
    NSMutableString* bkColorAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/BKColor (EEbkc"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      bkColorAsString = [NSMutableString stringWithString:testArray[1]];
      NSRange range = [bkColorAsString rangeOfString:@"EEbkcend"];
      range.length = (range.location != NSNotFound) ? bkColorAsString.length-range.location : 0;
      [bkColorAsString deleteCharactersInRange:range];
    }
    NSColor* backgroundColor = bkColorAsString ? [NSColor colorWithRgbaString:bkColorAsString] : nil;
    if (!backgroundColor)
      backgroundColor = (useDefaults ? defaultBkColor : [NSColor whiteColor]);
    result[@"backgroundColor"] = backgroundColor;
      
    NSMutableString* baselineAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Baseline (EEbas"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      baselineAsString  = [NSMutableString stringWithString:testArray[1]];
      NSRange range = [baselineAsString rangeOfString:@"EEbasend"];
      range.length = (range.location != NSNotFound) ? baselineAsString.length-range.location : 0;
      [baselineAsString deleteCharactersInRange:range];
    }
    result[@"baseline"] = @(baselineAsString ? baselineAsString.doubleValue : 0.);

    NSMutableString* titleAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Title (EEtitle"];
    if (testArray && (testArray.count >= 2))
    {
      DebugLog(1, @"[testArray objectAtIndex:1] = %@", testArray[1]);
      isLaTeXiTPDF |= YES;
      titleAsString  = [NSMutableString stringWithString:testArray[1]];
      NSRange range = [titleAsString rangeOfString:@"EEtitleend"];
      range.length = (range.location != NSNotFound) ? titleAsString.length-range.location : 0;
      [titleAsString deleteCharactersInRange:range];
    }
    result[@"title"] = (!titleAsString ? @"" : titleAsString);
    
    result[@"date"] = [NSDate date];
  }//end if (shouldDecodeLEE)
  
  DebugLog(1, @"isLaTeXiTPDF = %d", isLaTeXiTPDF);
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
    DebugLog(1, @"exploreStreams = %d", exploreStreams);
    if (exploreStreams)
    {
      CGPDFDictionaryRef catalog = !pdfDocument ? 0 : CGPDFDocumentGetCatalog(pdfDocument);
      NSMutableArray* streamObjects = [NSMutableArray array];
      if (catalog)
        CGPDFDictionaryApplyFunction(catalog, extractStreamObjectsFunction, (__bridge void*)streamObjects);
      if (pageDictionary)
        CGPDFDictionaryApplyFunction(pageDictionary, extractStreamObjectsFunction, (__bridge void*)streamObjects);
      NSEnumerator* enumerator = [streamObjects objectEnumerator];
      id streamData = nil;
      NSData* pdfHeader = [@"%PDF" dataUsingEncoding:NSUTF8StringEncoding];
      while(!isLaTeXiTPDF && ((streamData = [enumerator nextObject])))
      {
        NSData* streamAsData = [streamData dynamicCastToClass:[NSData class]];
        NSData* streamAsPdfData = 
          ([streamAsData rangeOfData:pdfHeader options:NSDataSearchAnchored range:NSMakeRange(0, streamAsData.length)].location == NSNotFound) ?
          nil : streamAsData;
        NSData* pdfData2 = nil;
        NSDictionary* result2 = !streamAsPdfData ? nil :
          [[self metaDataFromPDFData:streamAsPdfData useDefaults:NO outPdfData:&pdfData2] mutableCopy];
        if (result && outPdfData && pdfData2)
          *outPdfData = pdfData2;
        isLaTeXiTPDF |= (result2 != nil);
      }//end for each stream
    }//end if (exploreStreams)

    NSDictionary* latexitMetadata = nil;
    if (!isLaTeXiTPDF)
    {
      DebugLog(1, @">PDF scanning");
      CGPDFContentStreamRef contentStream = !page ? 0 :
        CGPDFContentStreamCreateWithPage(page);
      CGPDFOperatorTableRef operatorTable = CGPDFOperatorTableCreate();
      CGPDFOperatorTableSetCallback(operatorTable, "b", &CHCGPDFOperatorCallback_b);
      CGPDFOperatorTableSetCallback(operatorTable, "b*", &CHCGPDFOperatorCallback_bstar);
      CGPDFOperatorTableSetCallback(operatorTable, "B", &CHCGPDFOperatorCallback_B);
      CGPDFOperatorTableSetCallback(operatorTable, "B*", &CHCGPDFOperatorCallback_Bstar);
      CGPDFOperatorTableSetCallback(operatorTable, "c", &CHCGPDFOperatorCallback_c);
      CGPDFOperatorTableSetCallback(operatorTable, "cs", &CHCGPDFOperatorCallback_cs);
      CGPDFOperatorTableSetCallback(operatorTable, "h", &CHCGPDFOperatorCallback_h);
      CGPDFOperatorTableSetCallback(operatorTable, "l", &CHCGPDFOperatorCallback_l);
      CGPDFOperatorTableSetCallback(operatorTable, "m", &CHCGPDFOperatorCallback_m);
      CGPDFOperatorTableSetCallback(operatorTable, "n", &CHCGPDFOperatorCallback_n);
      CGPDFOperatorTableSetCallback(operatorTable, "Tj", &CHCGPDFOperatorCallback_Tj);
      CGPDFOperatorTableSetCallback(operatorTable, "v", &CHCGPDFOperatorCallback_v);
      CGPDFOperatorTableSetCallback(operatorTable, "y", &CHCGPDFOperatorCallback_y);
      LaTeXiTMetaDataParsingContext* pdfScanningContext = [[LaTeXiTMetaDataParsingContext alloc] init];
      CGPDFScannerRef pdfScanner = !contentStream ? 0 :
      CGPDFScannerCreate(contentStream, operatorTable, (__bridge void * _Nullable)(pdfScanningContext));
      CGPDFScannerScan(pdfScanner);
      CGPDFScannerRelease(pdfScanner);
      CGPDFOperatorTableRelease(operatorTable);
      CGPDFContentStreamRelease(contentStream);
      latexitMetadata = [[pdfScanningContext latexitMetadata] dynamicCastToClass:[NSDictionary class]];
      latexitMetadata = [latexitMetadata copy];
      #ifdef ARC_ENABLED
      #else
      [latexitMetadata autorelease];
      [pdfScanningContext release];
      #endif
      DebugLog(1, @"<PDF scanning");
    }//end if (!isLaTeXiTPDF)
    CGPDFDocumentRelease(pdfDocument);
    CGDataProviderRelease(dataProvider);
    DebugLog(1, @"latexitMetadata = %@", latexitMetadata);
    if (latexitMetadata)
    {
      NSString* preambleAsString = latexitMetadata[@"preamble"];
      NSAttributedString* preamble = !preambleAsString ? nil :
        [[NSAttributedString alloc] initWithString:preambleAsString attributes:defaultAttributes];
      result[@"preamble"] = (!preamble ? defaultPreambleAttributedString : preamble);

      NSNumber* modeAsNumber = nil;
      if (!modeAsNumber)
        modeAsNumber = [latexitMetadata objectForKey:@"type"];
      if (!modeAsNumber)
        modeAsNumber = [latexitMetadata objectForKey:@"mode"];
      latex_mode_t mode = modeAsNumber ? (latex_mode_t)[modeAsNumber integerValue] :
                                         (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : LATEX_MODE_TEXT);
      [result setObject:@((mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode) forKey:@"mode"];

      NSString* sourceAsString = latexitMetadata[@"source"];
      NSAttributedString* sourceText =
        [[NSAttributedString alloc] initWithString:(!sourceAsString ? @"" : sourceAsString) attributes:defaultAttributes];
      if (mode == LATEX_MODE_EQNARRAY)
      {
        NSMutableAttributedString* sourceText2 = [[NSMutableAttributedString alloc] init];
        [sourceText2 appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] ];
        [sourceText2 appendAttributedString:sourceText];
        [sourceText2 appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] ];
        sourceText = sourceText2;
      }
      result[@"sourceText"] = sourceText;
      
      NSNumber* pointSizeAsNumber = [latexitMetadata objectForKey:@"magnification"];
      [result setObject:(pointSizeAsNumber ? pointSizeAsNumber :
                         @(useDefaults ? [preferencesController latexisationFontSize] : 0))
                 forKey:@"magnification"];

      NSNumber* baselineAsNumber = [latexitMetadata objectForKey:@"baseline"];
      [result setObject:(baselineAsNumber ? baselineAsNumber : @0.)
                 forKey:@"baseline"];

      NSColor* defaultColor = preferencesController.latexisationFontColor;
      NSColor* color = [NSColor colorWithRgbaString:latexitMetadata[@"color"]];
      result[@"color"] = (color ? color : (useDefaults ? defaultColor : [NSColor blackColor]));

      NSColor* defaultBKColor = [NSColor whiteColor];
      NSColor* backgroundColor = [NSColor colorWithRgbaString:latexitMetadata[@"backgroundColor"]];
      result[@"backgroundColor"] = (backgroundColor ? backgroundColor : (useDefaults ? defaultBKColor : [NSColor whiteColor]));

      NSString* titleAsString = latexitMetadata[@"title"];
      result[@"title"] = (!titleAsString ? @"" : titleAsString);

      result[@"date"] = [NSDate date];
      isLaTeXiTPDF = YES;
    }//end if (latexitMetadata)
  }//end if (!isLaTeXiTPDF)
  
  if (!isLaTeXiTPDF)
    result = nil;
  
  return result;
}
//end metaDataFromPDFData:useDefaults:

+(BOOL) hasInvisibleGraphicCommandsInPDFData:(NSData*)someData
{
  BOOL result = NO;
  CGDataProviderRef dataProvider = !someData ? 0 :
    CGDataProviderCreateWithCFData((CFDataRef)someData);
  CGPDFDocumentRef pdfDocument = !dataProvider ? 0 :
    CGPDFDocumentCreateWithProvider(dataProvider);
  CGPDFPageRef page = !pdfDocument || !CGPDFDocumentGetNumberOfPages(pdfDocument) ? 0 :
    CGPDFDocumentGetPage(pdfDocument, 1);
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [[LaTeXiTMetaDataParsingContext alloc] init];
    CGPDFContentStreamRef contentStream = !page ? 0 :
      CGPDFContentStreamCreateWithPage(page);
    CGPDFOperatorTableRef operatorTable = CGPDFOperatorTableCreate();
    CGPDFOperatorTableSetCallback(operatorTable, "b", &CHCGPDFOperatorCallback_b);
    CGPDFOperatorTableSetCallback(operatorTable, "b*", &CHCGPDFOperatorCallback_bstar);
    CGPDFOperatorTableSetCallback(operatorTable, "B", &CHCGPDFOperatorCallback_B);
    CGPDFOperatorTableSetCallback(operatorTable, "B*", &CHCGPDFOperatorCallback_Bstar);
    CGPDFOperatorTableSetCallback(operatorTable, "c", &CHCGPDFOperatorCallback_c);
    CGPDFOperatorTableSetCallback(operatorTable, "cs", &CHCGPDFOperatorCallback_cs);
    CGPDFOperatorTableSetCallback(operatorTable, "h", &CHCGPDFOperatorCallback_h);
    CGPDFOperatorTableSetCallback(operatorTable, "l", &CHCGPDFOperatorCallback_l);
    CGPDFOperatorTableSetCallback(operatorTable, "m", &CHCGPDFOperatorCallback_m);
    CGPDFOperatorTableSetCallback(operatorTable, "n", &CHCGPDFOperatorCallback_n);
    CGPDFOperatorTableSetCallback(operatorTable, "Tj", &CHCGPDFOperatorCallback_Tj);
    CGPDFOperatorTableSetCallback(operatorTable, "v", &CHCGPDFOperatorCallback_v);
    CGPDFOperatorTableSetCallback(operatorTable, "y", &CHCGPDFOperatorCallback_y);
    CGPDFScannerRef pdfScanner = !contentStream ? 0 :
    CGPDFScannerCreate(contentStream, operatorTable, (__bridge void * _Nullable)(pdfScanningContext));
    CGPDFScannerScan(pdfScanner);
    CGPDFScannerRelease(pdfScanner);
    CGPDFOperatorTableRelease(operatorTable);
    CGPDFContentStreamRelease(contentStream);
  CGPDFDocumentRelease(pdfDocument);
  CGDataProviderRelease(dataProvider);
  NSDictionary* latexitMetadata = [[pdfScanningContext latexitMetadata] dynamicCastToClass:[NSDictionary class]];
  result = ([latexitMetadata count] > 0);
  #ifdef ARC_ENABLED
  #else
  [pdfScanningContext release];
  #endif
  return result;
}
//end hasInvisibleGraphicCommandsInPDFData:

+(BOOL) latexitEquationPossibleWithUTI:(NSString*)uti
{
  BOOL result = NO;
  if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypePDF))
    result = YES;
  else if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeTIFF))
    result = YES;
  else if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypePNG))
    result = YES;
  else if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeJPEG))
    result = YES;
  else if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeScalableVectorGraphics))
    result = YES;
  else if (UTTypeConformsTo((__bridge CFStringRef)uti, kUTTypeHTML))
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
  if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypePDF))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeTIFF))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypePNG))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeJPEG))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeScalableVectorGraphics))
  {
    NSError* error = nil;
    NSString* string = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
    NSArray* descriptions =
      [string componentsMatchedByRegex:@"<svg(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</svg>"
                               options:RKLCaseless|RKLMultiline|RKLDotAll
                                 range:NSMakeRange(0, string.length) capture:0 error:&error];
    if (error)
      DebugLog(1, @"error : %@", error);
    NSEnumerator* enumerator = [descriptions objectEnumerator];
    NSString* description = nil;
    while((description = [enumerator nextObject]))
    {
      NSData* subData = [description dataUsingEncoding:NSUTF8StringEncoding];
      [equations safeAddObject:[self latexitEquationWithData:subData sourceUTI:sourceUTI useDefaults:useDefaults]];
    }//end for each description
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeScalableVectorGraphics))
  else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeHTML))
  {
    NSError* error = nil;
    NSString* string = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
    NSArray* descriptions_legacy =
      [string componentsMatchedByRegex:@"<blockquote(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</blockquote>"
                               options:RKLCaseless|RKLMultiline|RKLDotAll
                                 range:NSMakeRange(0, string.length) capture:0 error:&error];
    if (error)
      DebugLog(1, @"error : %@", error);
    NSArray* descriptions =
    [string componentsMatchedByRegex:@"<math(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</math>"
                             options:RKLCaseless|RKLMultiline|RKLDotAll
                               range:NSMakeRange(0, string.length) capture:0 error:&error];
    if (error)
      DebugLog(1, @"error : %@", error);
    NSEnumerator* enumerator = nil;
    NSString* description = nil;
    enumerator = [descriptions_legacy objectEnumerator];
    while((description = [enumerator nextObject]))
    {
      NSData* subData = [description dataUsingEncoding:NSUTF8StringEncoding];
      [equations safeAddObject:[self latexitEquationWithData:subData sourceUTI:sourceUTI useDefaults:useDefaults]];
    }//end for each description
    enumerator = [descriptions objectEnumerator];
    while((description = [enumerator nextObject]))
    {
      NSData* subData = [description dataUsingEncoding:NSUTF8StringEncoding];
      [equations safeAddObject:[self latexitEquationWithData:subData sourceUTI:sourceUTI useDefaults:useDefaults]];
    }//end for each description
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeHTML))
  result = [NSArray arrayWithArray:equations];
  return result;
}
//end latexitEquationsWithData:sourceUTI:useDefaults

+(instancetype) latexitEquationWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                           color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
                 backgroundColor:(NSColor*)backgroundColor
                           title:(NSString*)aTitle
{
  id instance = [[[self class] alloc] initWithPDFData:someData preamble:aPreamble sourceText:aSourceText
                                              color:aColor pointSize:aPointSize date:aDate mode:aMode
                                              backgroundColor:backgroundColor title:aTitle];
  #ifdef ARC_ENABLED
  #else
  [instance autorelease];
  #endif
  return instance;
}
//end latexitEquationWithPDFData:preamble:sourceText:color:pointSize:date:mode:backgroundColor:

+(instancetype) latexitEquationWithMetaData:(NSDictionary*)metaData useDefaults:(BOOL)useDefaults
{
  return [[[self class] alloc] initWithMetaData:metaData useDefaults:useDefaults];
}
//end latexitEquationWithData:sourceUTI:useDefaults:

+(instancetype) latexitEquationWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults
{
  return [[[self class] alloc] initWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults];
}
//end latexitEquationWithData:sourceUTI:useDefaults:

+(instancetype) latexitEquationWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
{
  return [[[self class] alloc] initWithPDFData:someData useDefaults:useDefaults];
}
//end latexitEquationWithPDFData:useDefaults:

-(instancetype) initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context
{
  if (!((self = [super initWithEntity:entity insertIntoManagedObjectContext:context])))
    return nil;
  self->isModelPrior250 = context &&
    !context.persistentStoreCoordinator.managedObjectModel.entitiesByName[NSStringFromClass([LatexitEquationData class])];
  self->exportPrefetcher = [[CHExportPrefetcher alloc] init];
  return self;
}
//end initWithEntity:insertIntoManagedObjectContext:

-(instancetype) initWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
              color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
              backgroundColor:(NSColor*)aBackgroundColor title:(NSString*)aTitle
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
  [self beginUpdate];
  self.pdfData = someData;
  self.preamble = aPreamble;
  self.sourceText = aSourceText;
  self.color = aColor;
  self.pointSize = aPointSize;
  self.date = aDate ? [aDate copy] : [NSDate date];
  self.mode = aMode;
  [self setTitle:aTitle];
  
  if (!aBackgroundColor && [PreferencesController sharedController].documentUseAutomaticHighContrastedPreviewBackground)
    aBackgroundColor = ([aColor grayLevel] > .5) ? [NSColor blackColor] : nil;
  self.backgroundColor = aBackgroundColor;
  self->annotateDataDirtyState = NO;
  [self endUpdate];
  return self;
}
//end initWithPDFData:preamble:sourceText:color:pointSize:date:mode:backgroundColor:

-(instancetype) initWithMetaData:(NSDictionary*)metaData useDefaults:(BOOL)useDefaults
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;

  [self beginUpdate];
  NSAttributedString* preamble = metaData[@"preamble"];
  if (preamble)
    self.preamble = preamble;

  NSNumber* mode = metaData[@"mode"];
  if (mode)
    [self setMode:(latex_mode_t)[mode integerValue]];

  NSAttributedString* sourceText = metaData[@"sourceText"];
  if (sourceText)
    self.sourceText = sourceText;

  NSNumber* pointSize = metaData[@"magnification"];
  if (pointSize)
    self.pointSize = pointSize.doubleValue;

  NSColor* color = metaData[@"color"];
  if (color)
    self.color = color;

  NSColor* backgroundColor = metaData[@"backgroundColor"];
  if (backgroundColor)
    self.backgroundColor = backgroundColor;

  NSString* title = metaData[@"title"];
  if (title)
    self.title = title;

  NSNumber* baseline = metaData[@"baseline"];
  self.baseline = !baseline ? 0. : baseline.doubleValue;

  NSDate* date = metaData[@"date"];
  if (date)
    self.date = date;
    
  [self endUpdate];
  
  return self;
}
//end initWithMetaData:useDefaults:

-(instancetype) initWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
  self.pdfData = someData;
  NSDictionary* metaData = [[self class] metaDataFromPDFData:someData useDefaults:useDefaults outPdfData:0];
  BOOL isLaTeXiTPDF = (metaData != nil);

  [self beginUpdate];
  NSAttributedString* preamble = metaData[@"preamble"];
  isLaTeXiTPDF &= (preamble != nil);
  if (preamble)
    self.preamble = preamble;

  NSNumber* mode = metaData[@"mode"];
  isLaTeXiTPDF &= (mode != nil);
  if (mode)
    [self setMode:(latex_mode_t)[mode integerValue]];

  NSAttributedString* sourceText = metaData[@"sourceText"];
  isLaTeXiTPDF &= (sourceText != nil);
  if (sourceText)
    self.sourceText = sourceText;

  NSNumber* pointSize = metaData[@"magnification"];
  isLaTeXiTPDF &= (pointSize != nil);
  if (pointSize)
    self.pointSize = pointSize.doubleValue;

  NSColor* color = metaData[@"color"];
  isLaTeXiTPDF &= (color != nil);
  if (color)
    self.color = color;

  NSColor* backgroundColor = metaData[@"backgroundColor"];
  isLaTeXiTPDF &= (backgroundColor != nil);
  if (backgroundColor)
    self.backgroundColor = backgroundColor;

  NSString* title = metaData[@"title"];
  if (title)
    self.title = title;

  NSNumber* baseline = metaData[@"baseline"];
  self.baseline = !baseline ? 0. : baseline.doubleValue;

  NSDate* date = metaData[@"date"];
  if (date)
    self.date = date;
    
  
  self->annotateDataDirtyState = NO;
  [self endUpdate];

  if (!isLaTeXiTPDF)
  {
    self = nil;
    return nil;
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
      latex_mode_t mode = modeAsNumber ? (latex_mode_t)[modeAsNumber integerValue] :
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
    latex_mode_t mode = modeAsString ? (latex_mode_t) [modeAsString integerValue]
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

-(instancetype) initWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults
{
  id result = nil;
  if (!sourceUTI)
  {
    
  }//end if (!sourceUTI)
  else//if (sourceUTI)
  {
    if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypePDF))
      result = [self initWithPDFData:someData useDefaults:useDefaults];
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeTIFF)||
             UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypePNG)||
             UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeJPEG))
    {
      CGImageSourceRef imageSource = CGImageSourceCreateWithData((CHBRIDGE CFDataRef)someData,
        (CHBRIDGE CFDictionaryRef)@{(NSString*)kCGImageSourceShouldCache: @NO});
      NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil));
      DebugLog(1, @"properties = %@", properties);
      id infos = properties[(NSString*)kCGImagePropertyExifDictionary];
      id annotationBase64 = ![infos isKindOfClass:[NSDictionary class]] ? nil : infos[(NSString*)kCGImagePropertyExifUserComment];
      NSData* annotationData = ![annotationBase64 isKindOfClass:[NSString class]] ? nil :
        [NSData dataWithBase64:annotationBase64];
      DebugLog(1, @"annotationData(64) = %@", annotationData);
      annotationData = [Compressor zipuncompress:annotationData];
      DebugLog(1, @"annotationData(z) = %@", annotationData);
      NSDictionary* metaData = !annotationData ? nil :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      DebugLog(1, @"metaData = %@", metaData);
      result = [self initWithMetaData:metaData useDefaults:useDefaults];
      if (imageSource)
        CFRelease(imageSource);
    }//end if (tiff, png, jpeg)
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeScalableVectorGraphics))
    {
      NSString* svgString = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
      NSString* annotationBase64 =
        [svgString stringByMatching:@"<!--latexit:(.*?)-->" options:RKLCaseless|RKLDotAll|RKLMultiline
          inRange:NSMakeRange(0, svgString.length) capture:1 error:0];
      NSData* annotationData = [NSData dataWithBase64:annotationBase64];
      annotationData = [Compressor zipuncompress:annotationData];
      NSDictionary* metaData = !annotationData ? nil :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      result = [self initWithMetaData:metaData useDefaults:useDefaults];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeScalableVectorGraphics))
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeHTML))
    {
      NSString* mathmlString = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
      NSString* annotationBase64 =
        [mathmlString stringByMatching:@"<!--latexit:(.*?)-->" options:RKLCaseless|RKLDotAll|RKLMultiline
          inRange:NSMakeRange(0, mathmlString.length) capture:1 error:0];
      NSData* annotationData = [NSData dataWithBase64:annotationBase64];
      annotationData = [Compressor zipuncompress:annotationData];
      NSDictionary* metaData = !annotationData ? nil :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      result = [self initWithMetaData:metaData useDefaults:useDefaults];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeHTML))
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeText))
    {
      NSString* string = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
      NSString* annotationBase64 = nil;
      if (!annotationBase64)
        annotationBase64 = [string stringByMatching:@"<!--latexit:(.*?)-->" options:RKLCaseless|RKLDotAll|RKLMultiline
                                            inRange:NSMakeRange(0, string.length) capture:1 error:0];
      if (!annotationBase64)
        annotationBase64 = [string stringByMatching:@"([A-Za-z0-9\\+\\/\\n])*\\=*" options:RKLCaseless|RKLDotAll|RKLMultiline
                                            inRange:NSMakeRange(0, string.length) capture:0 error:0];
      NSData* annotationData = !annotationBase64 ? nil : [NSData dataWithBase64:annotationBase64];
      annotationData = !annotationData ? nil : [Compressor zipuncompress:annotationData];
      NSDictionary* metaData = !annotationData ? nil :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      if (!metaData)
        result = nil;
      else
        result = [self initWithMetaData:metaData useDefaults:useDefaults];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeText))
    else
    {
    }
  }//end if (sourceUTI)
  return result;
}
//end initWithData:useDefaults:

-(id) copyWithZone:(NSZone*)zone
{
  id clone = [[[self class] alloc] initWithPDFData:[self pdfData] preamble:[self preamble] sourceText:[self sourceText]
                                             color:[self color] pointSize:[self pointSize] date:[self date]
                                            mode:[self mode] backgroundColor:[self backgroundColor]
                                            title:[self title]];
  [self.managedObjectContext safeInsertObject:clone];
  return clone;
}
//end copyWithZone:

-(instancetype) initWithCoder:(NSCoder*)coder
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
  [self beginUpdate];
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
  self->annotateDataDirtyState = NO;
  [self endUpdate];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [self dispose];
}
//end dealloc

-(void) dispose
{
  [[self class] cancelPreviousPerformRequestsWithTarget:self];
  self->exportPrefetcher = nil;
}
//end dispose

-(void) encodeWithCoder:(NSCoder*)coder
{
  NSString* applicationVersion = [[NSWorkspace sharedWorkspace] applicationVersion];
  [coder encodeObject:applicationVersion forKey:@"version"];//we encode the current LaTeXiT version number
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
  [self.managedObjectContext safeInsertObject:equationData];
}
//end awakeFromInsert

-(void) checkAndMigrateAlign
{
  if (self.mode == LATEX_MODE_EQNARRAY)
  {
    [self.managedObjectContext disableUndoRegistration];
    self.mode = LATEX_MODE_TEXT;
    NSAttributedString* oldSourceText = self.sourceText;
    NSDictionary* attributes = [oldSourceText attributesAtIndex:0 effectiveRange:0];
    NSMutableAttributedString* newSourceText = [[NSMutableAttributedString alloc] init];
    [newSourceText appendAttributedString:
       [[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:attributes]];
    [newSourceText appendAttributedString:oldSourceText];
    [newSourceText appendAttributedString:
       [[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:attributes]];
    self.sourceText = newSourceText;
    [self.managedObjectContext enableUndoRegistration];
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
    result = equationData.pdfData;
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
    self->pdfCachedImage = nil;
  }//end @synchronized(self)
  if (value != self.pdfData)
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
          initWithEntity:[LatexitEquationData entity] insertIntoManagedObjectContext:self.managedObjectContext];
        if (equationData)
        {
          [self willChangeValueForKey:@"equationData"];
          [self setPrimitiveValue:equationData forKey:@"equationData"];
          [self didChangeValueForKey:@"equationData"];
          [equationData willChangeValueForKey:@"equation"];
          [equationData setPrimitiveValue:self forKey:@"equation"];//if managedObjectContext is nil, this is necessary
          [equationData didChangeValueForKey:@"equation"];
        }//end if (equationData)
      }//end if (!equationData)
      equationData.pdfData = value;
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
  }//end if (!result)
  return result;
} 
//end preamble

-(void) setPreamble:(NSAttributedString*)value
{
  [self beginUpdate];
  self->annotateDataDirtyState |= objectDiffers(value, [self preamble]);
  [self willChangeValueForKey:@"preamble"];
  [self setPrimitiveValue:value forKey:@"preamble"];
  [self didChangeValueForKey:@"preamble"];
  NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"preambleAsData"];
  [self setPrimitiveValue:archivedData forKey:@"preambleAsData"];
  [self didChangeValueForKey:@"preambleAsData"];
  [self endUpdate];
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
  [self beginUpdate];
  self->annotateDataDirtyState |= objectDiffers(value, [self sourceText]);
  [self willChangeValueForKey:@"sourceText"];
  [self setPrimitiveValue:value forKey:@"sourceText"];
  [self didChangeValueForKey:@"sourceText"];
  NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"sourceTextAsData"];
  [self setPrimitiveValue:archivedData forKey:@"sourceTextAsData"];
  [self didChangeValueForKey:@"sourceTextAsData"];
  [self endUpdate];
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
  [self beginUpdate];
  self->annotateDataDirtyState |= objectDiffers(value, [self color]);
  [self willChangeValueForKey:@"color"];
  [self setPrimitiveValue:value forKey:@"color"];
  [self didChangeValueForKey:@"color"];
  NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"colorAsData"];
  [self setPrimitiveValue:archivedData forKey:@"colorAsData"];
  [self didChangeValueForKey:@"colorAsData"];
  [self endUpdate];
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
  [self beginUpdate];
  self->annotateDataDirtyState |= (value != [self baseline]);
  [self willChangeValueForKey:@"baseline"];
  [self setPrimitiveValue:@(value) forKey:@"baseline"];
  [self didChangeValueForKey:@"baseline"];
  [self endUpdate];
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
  [self beginUpdate];
  self->annotateDataDirtyState |= (value != [self pointSize]);
  [self willChangeValueForKey:@"pointSize"];
  [self setPrimitiveValue:@(value) forKey:@"pointSize"];
  [self didChangeValueForKey:@"pointSize"];
  [self endUpdate];
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
  [self beginUpdate];
  [self willChangeValueForKey:@"date"];
  [self setPrimitiveValue:value forKey:@"date"];
  [self didChangeValueForKey:@"date"];
  [self endUpdate];
}
//end setDate:

-(latex_mode_t)mode
{
  latex_mode_t result = 0;
  [self willAccessValueForKey:@"modeAsInteger"];
  result = (latex_mode_t)[[self primitiveValueForKey:@"modeAsInteger"] integerValue];
  [self didAccessValueForKey:@"modeAsInteger"];
  return result;
}
//end mode

-(void) setMode:(latex_mode_t)value
{
  [self beginUpdate];
  self->annotateDataDirtyState |= (value != [self mode]);
  [self willChangeValueForKey:@"modeAsInteger"];
  [self setPrimitiveValue:@(value) forKey:@"modeAsInteger"];
  [self didChangeValueForKey:@"modeAsInteger"];
  [self endUpdate];
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
  NSColor* grayLevelColor = [value colorUsingColorSpace:[NSColorSpace deviceGrayColorSpace]];
  value = ([grayLevelColor whiteComponent] == 1.0f) ? nil : value;
  [self beginUpdate];
  self->annotateDataDirtyState |= objectDiffers(value, [self backgroundColor]);
  [self willChangeValueForKey:@"backgroundColor"];
  [self setPrimitiveValue:value forKey:@"backgroundColor"];
  [self didChangeValueForKey:@"backgroundColor"];
  NSData* archivedData = !value ? nil : [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"backgroundColorAsData"];
  [self setPrimitiveValue:archivedData forKey:@"backgroundColorAsData"];
  [self didChangeValueForKey:@"backgroundColorAsData"];
  [self endUpdate];
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
  NSString* oldTitle = self.title;
  BOOL bothEmpty = ![oldTitle length] && ![value length];
  BOOL isDifferent = !bothEmpty && objectDiffers(value, [self title]);
  [self beginUpdate];
  self->annotateDataDirtyState |= isDifferent;
  if (isDifferent)
  {
    [self willChangeValueForKey:@"title"];
    [self setPrimitiveValue:value forKey:@"title"];
    [self didChangeValueForKey:@"title"];
  }//end if (isDifferent)
  [self endUpdate];
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
      NSArray* representations = result.representations;
      NSUInteger i = 0;
      NSUInteger count = representations.count;
      for(i = 0 ; !hasPdfOrBitmapImageRep && (i<count) ; ++i)
      {
        id representation = representations[i];
        hasPdfOrBitmapImageRep |=
          [representation isKindOfClass:[NSPDFImageRep class]] |
          [representation isKindOfClass:[NSBitmapImageRep class]];
      }//end for each representation
      if (!hasPdfOrBitmapImageRep)
      {
        result = nil;
      }//end if (!hasPdfOrBitmapImageRep)
    }//end if (result)
    
    if (!result)
    {
      NSData* pdfData = self.pdfData;
      NSPDFImageRep* pdfImageRep = !pdfData ? nil : [[NSPDFImageRep alloc] initWithData:pdfData];
      if (pdfImageRep)
      {
        self->pdfCachedImage = [[NSImage alloc] initWithSize:pdfImageRep.size];
        self->pdfCachedImage.cacheMode = NSImageCacheNever;
        [self->pdfCachedImage addRepresentation:pdfImageRep];
        if (![self->pdfCachedImage bitmapImageRepresentationWithMaxSize:NSMakeSize(0, 128)])//to help drawing in library
          [self->pdfCachedImage bitmapImageRepresentation];
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
  NSString* result = [[self class] latexModeToString:self.mode];
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
  return [NSString stringWithFormat:@"%@\n\\begin{document}\n%@\n\\end{document}", self.preamble.string, self.sourceText.string];
}
//end string

-(NSAttributedString*) encapsulatedSource//the body, with \[...\], $...$ or nothing according to the mode
{
  NSMutableAttributedString* result = [[NSMutableAttributedString alloc] initWithAttributedString:self.sourceText];
  switch(self.mode)
  {
    case LATEX_MODE_DISPLAY:
      [result insertAttributedString:[[NSAttributedString alloc] initWithString:@"\\["] atIndex:0];
      [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\\]"]];
      break;
    case LATEX_MODE_INLINE:
      [result insertAttributedString:[[NSAttributedString alloc] initWithString:@"$"] atIndex:0];
      [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"$"]];
      break;
    case LATEX_MODE_EQNARRAY:
      [result insertAttributedString:[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}"] atIndex:0];
      [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\\end{eqnarray*}"]];
      break;
    case LATEX_MODE_ALIGN:
      [result insertAttributedString:[[NSAttributedString alloc] initWithString:@"\\begin{align*}"] atIndex:0];
      [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\\end{align*}"]];
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
  NSString* result = [self.sourceText.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSUInteger endIndex = MIN(17U, [result length]);
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
    self.pdfData = newData;
  }//end if (![self isUpdating])
}
//end reannotatePDFDataUsingPDFKeywords:

-(NSData*) annotatedPDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords
{
  NSData* result = self.pdfData;
  DebugLog(1, @"annotatedPDFDataUsingPDFKeywords %p, from %llu", result, (unsigned long long)[result length]);

  //annotate in LEE format
  export_format_t exportFormat = EXPORT_FORMAT_PDF;
  result = [[LaTeXProcessor sharedLaTeXProcessor] annotatePdfDataInLEEFormat:result exportFormat:exportFormat
              preamble:[[self preamble] string] source:[[self sourceText] string]
                 color:[self color] mode:[self mode] magnification:[self pointSize] baseline:[self baseline]
       backgroundColor:[self backgroundColor] title:[self title] annotateWithTransparentData:NO];
  DebugLog(1, @"annotatedPDFDataUsingPDFKeywords %p, to %llu", result, (unsigned long long)[result length]);
  return result;
}
//end annotatedPDFDataUsingPDFKeywords:usingPDFKeywords

//to feed a pasteboard. It needs a document, because there may be some temporary files needed for certain kind of data
//the lazyDataProvider, if not nil, is the one who will call [pasteboard:provideDataForType] *as needed* (to save time)
-(void) writeToPasteboard:(NSPasteboard *)pboard exportFormat:(export_format_t)exportFormat isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider options:(NSDictionary*)options
{
  //LinkBack pasteboard
  DebugLog(1, @"lazyDataProvider = %p(%@)>", lazyDataProvider, lazyDataProvider);

  NSArray* latexitEquationArray = @[self];
  NSData*  latexitEquationData  = [NSKeyedArchiver archivedDataWithRootObject:latexitEquationArray];
  NSDictionary* linkBackPlist =
    isLinkBackRefresh ? [NSDictionary linkBackDataWithServerName:[[NSWorkspace sharedWorkspace] applicationName] appData:latexitEquationData
                                      actionName:LinkBackRefreshActionName suggestedRefreshRate:0]
                      : [NSDictionary linkBackDataWithServerName:[[NSWorkspace sharedWorkspace] applicationName] appData:latexitEquationData]; 
  
  if (isLinkBackRefresh)
    [pboard declareTypes:@[LinkBackPboardType] owner:self];
  else
    [pboard addTypes:@[LinkBackPboardType] owner:self];
  [pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];

  NSData* pdfData = self.pdfData;
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
                                 @(preferencesController.exportJpegQualityPercent), @"jpegQuality",
                                 @(preferencesController.exportScalePercent), @"scaleAsPercent",
                                 @(preferencesController.exportIncludeBackgroundColor), @"exportIncludeBackgroundColor",
                                 @(preferencesController.exportTextExportPreamble), @"textExportPreamble",
                                 @(preferencesController.exportTextExportEnvironment), @"textExportEnvironment",
                                 @(preferencesController.exportTextExportBody), @"textExportBody",
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
        compositionConfiguration:preferencesController.compositionConfigurationDocument
        uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  
  //feeds the right pasteboard according to the type (pdf, eps, tiff, jpeg, png...)
  NSString* extension = getFileExtensionForExportFormat(exportFormat);
  NSString* uti = getUTIForExportFormat(exportFormat);
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
      [pboard addTypes:@[NSPasteboardTypePDF, (NSString*)kUTTypePDF] owner:lazyDataProvider];
      if (!lazyDataProvider)
      {
        [pboard setData:data forType:NSPasteboardTypePDF];
        [pboard setData:data forType:(NSString*)kUTTypePDF];
      }//end if (!lazyDataProvider)
      break;
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
      [pboard addTypes:@[NSPasteboardTypePDF, (NSString*)kUTTypePDF]
                 owner:lazyDataProvider ? lazyDataProvider : self];
      if (data && (!lazyDataProvider || (lazyDataProvider != self)))
      {
        [pboard setData:data forType:NSPasteboardTypePDF];
        [pboard setData:data forType:(NSString*)kUTTypePDF];
      }//end if (data && (!lazyDataProvider || (lazyDataProvider != self)))
      break;
    case EXPORT_FORMAT_EPS:
      [pboard addTypes:@[NSPostScriptPboardType, @"com.adobe.encapsulated-postscript"] owner:lazyDataProvider];
      if (!lazyDataProvider)
      {
        [pboard setData:data forType:NSPostScriptPboardType];
        [pboard setData:data forType:@"com.adobe.encapsulated-postscript"];
      }//end if (!lazyDataProvider)
      break;
    case EXPORT_FORMAT_PNG:
      [pboard addTypes:@[(NSString*)kUTTypePNG] owner:lazyDataProvider];
      if (!lazyDataProvider)
        [pboard setData:data forType:(NSString*)kUTTypePNG];
      break;
    case EXPORT_FORMAT_JPEG:
      [pboard addTypes:@[(NSString*)kUTTypeJPEG] owner:lazyDataProvider];
      if (!lazyDataProvider)
        [pboard setData:data forType:(NSString*)kUTTypeJPEG];
      break;
    case EXPORT_FORMAT_TIFF:
      [pboard addTypes:@[NSPasteboardTypeTIFF, (NSString*)kUTTypeTIFF] owner:lazyDataProvider];
      if (!lazyDataProvider)
      {
        [pboard setData:data forType:NSPasteboardTypeTIFF];
        [pboard setData:data forType:(NSString*)kUTTypeTIFF];
      }//end if (!lazyDataProvider)
      break;
    case EXPORT_FORMAT_MATHML:
      {
        extension = @"mathml";//override default HTML
        uti = @"public.mathml";//override default HTML
        NSString* documentString = !data ? nil : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString* blockquoteString = [documentString stringByMatching:@"<blockquote(.*?)>.*</blockquote>" options:RKLMultiline|RKLDotAll|RKLCaseless inRange:NSMakeRange(0, documentString.length) capture:0 error:0];
        //[pboard addTypes:[NSArray arrayWithObjects:NSHTMLPboardType, kUTTypeHTML, nil] owner:lazyDataProvider];
        [pboard addTypes:@[NSPasteboardTypeString, (id)kUTTypeText] owner:lazyDataProvider];
        if (blockquoteString)
        {
          NSError* error = nil;
          NSString* mathString =
            [blockquoteString stringByReplacingOccurrencesOfRegex:@"<blockquote(.*?)style=(.*?)>(.*?)<math(.*?)>(.*?)</math>(.*)</blockquote>"
                                                       withString:@"<math$4 style=$2>$3$5</math>"
                                                          options:RKLMultiline|RKLDotAll|RKLCaseless range:[blockquoteString range] error:&error];
          if (error)
            DebugLog(1, @"error = <%@>", error);
          /*if (!lazyDataProvider)
          {
            [pboard setString:blockquoteString forType:NSHTMLPboardType];
            [pboard setString:blockquoteString forType:kUTTypeHTML];
          }//end if (!lazyDataProvider)*/
          if (!lazyDataProvider)
          {
            [pboard setString:(!mathString ? blockquoteString : mathString) forType:NSPasteboardTypeString];
            [pboard setString:(!mathString ? blockquoteString : mathString) forType:(NSString*)kUTTypeText];
          }//end if (!lazyDataProvider)
        }//end if (blockquoteString)
      }
      break;
    case EXPORT_FORMAT_SVG:
      [pboard addTypes:@[GetMySVGPboardType(), (id)kUTTypeScalableVectorGraphics, NSPasteboardTypeString] owner:lazyDataProvider];
      if (!lazyDataProvider)
      {
        [pboard setData:data forType:GetMySVGPboardType()];
        [pboard setData:data forType:@"public.svg-image"];
        [pboard setData:data forType:NSPasteboardTypeString];
      }//end if (!lazyDataProvider)
      break;
    case EXPORT_FORMAT_TEXT:
      [pboard addTypes:@[NSPasteboardTypeString, (NSString*)kUTTypeText] owner:lazyDataProvider];
      if (!lazyDataProvider)
      {
        [pboard setData:data forType:NSPasteboardTypeString];
        [pboard setData:data forType:(NSString*)kUTTypeText];
      }//end if (!lazyDataProvider)
      break;
  }//end switch(exportFormat)
  
  BOOL fillFilenames = [[PreferencesController sharedController] exportAddTempFileCurrentSession];
  if (fillFilenames)
  {
    [pboard addTypes:[NSArray arrayWithObjects:NSFileContentsPboardType, NSFilenamesPboardType, NSURLPboardType, nil] owner:lazyDataProvider];
    if (!lazyDataProvider)
    {
      NSString* folder = [[NSWorkspace sharedWorkspace] temporaryDirectory];
      NSString* filePrefix = [self computeFileName];
      if (!filePrefix || [filePrefix isEqualToString:@""])
        filePrefix = @"latexit-drag";
      NSString* filePath = !extension ? nil :
        [[NSFileManager defaultManager] getUnusedFilePathFromPrefix:filePrefix extension:extension folder:folder startSuffix:0];
      if (filePath)
      {
        [data writeToFile:filePath atomically:YES];
        NSURL* fileURL = !filePath ? nil : [NSURL fileURLWithPath:filePath];
        [pboard writeObjects:@[fileURL]];
        [fileURL writeToPasteboard:pboard];
        FileManagerHelper* fileManagerHelper = [FileManagerHelper defaultManager];
        [fileManagerHelper addSelfDestructingFile:filePath timeInterval:10];
      }//end if (filePath)
    }//end if (!lazyDataProvider)
  }//end if (fillFilenames)
}
//end writeToPasteboard:isLinkBackRefresh:lazyDataProvider:

//provides lazy data to a pasteboard
-(void) pasteboard:(NSPasteboard *)pasteboard provideDataForType:(NSString*)type
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  DebugLog(1, @">pasteboard:%p provideDataForType:%@", pasteboard, type);
  NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                 @([preferencesController exportJpegQualityPercent]), @"jpegQuality",
                                 @([preferencesController exportScalePercent]), @"scaleAsPercent",
                                 @([preferencesController exportIncludeBackgroundColor]), @"exportIncludeBackgroundColor",
                                 @([preferencesController exportTextExportPreamble]), @"textExportPreamble",
                                 @([preferencesController exportTextExportEnvironment]), @"textExportEnvironment",
                                 @([preferencesController exportTextExportBody]), @"textExportBody",
                                 [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                 nil];
  export_format_t exportFormat = preferencesController.exportFormatCurrentSession;
  NSData* data = (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) ?
    [self->exportPrefetcher fetchDataForFormat:exportFormat wait:YES] :
    nil;
  if (!data)
    data = [[LaTeXProcessor sharedLaTeXProcessor]
            dataForType:exportFormat
                pdfData:self.pdfData
              exportOptions:exportOptions
            compositionConfiguration:preferencesController.compositionConfigurationDocument
            uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  
  NSString* extension = nil;
  NSString* uti = nil;
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
      extension = @"pdf";
      uti = (NSString*)kUTTypePDF;
      break;
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
      extension = @"pdf";
      uti = (NSString*)kUTTypePDF;
      break;
    case EXPORT_FORMAT_EPS:
      extension = @"eps";
      uti = @"com.adobe.encapsulated-​postscript";
      break;
    case EXPORT_FORMAT_PNG:
      extension = @"png";
      uti = (NSString*)kUTTypePNG;
      break;
    case EXPORT_FORMAT_JPEG:
      extension = @"jpeg";
      uti = (NSString*)kUTTypeJPEG;
      break;
    case EXPORT_FORMAT_TIFF:
      extension = @"tiff";
      uti = (NSString*)kUTTypeTIFF;
      break;
    case EXPORT_FORMAT_MATHML:
      extension = @"mathml";
      uti = @"public.mathml";
      break;
    case EXPORT_FORMAT_SVG:
      extension = @"svg";
      uti = GetMySVGPboardType();
      break;
    case EXPORT_FORMAT_TEXT:
      extension = @"txt";
      uti = (NSString*)kUTTypeText;
      break;
  }//end switch(exportFormat)
  
  if (exportFormat == EXPORT_FORMAT_MATHML)
  {
    NSString* documentString = !data ? nil : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString* blockquoteString = [documentString stringByMatching:@"<blockquote(.*?)>.*</blockquote>" options:RKLMultiline|RKLDotAll|RKLCaseless inRange:[documentString range] capture:0 error:0];
    if (blockquoteString)
    {
      NSError* error = nil;
      NSString* mathString =
      [blockquoteString stringByReplacingOccurrencesOfRegex:@"<blockquote(.*?)style=(.*?)>(.*?)<math(.*?)>(.*?)</math>(.*)</blockquote>"
                                                 withString:@"<math$4 style=$2>$3$5</math>"
                                                    options:RKLMultiline|RKLDotAll|RKLCaseless range:[blockquoteString range] error:&error];
      if (error)
        DebugLog(1, @"error = <%@>", error);
      BOOL isHTML = [type isEqualToString:(NSString*)kUTTypeHTML] || [type isEqualToString:NSPasteboardTypeHTML];
      if (isHTML)
        [pasteboard setString:blockquoteString forType:type];
      else//if (!isHTML)
        [pasteboard setString:(!mathString ? blockquoteString : mathString) forType:type];
    }//end if (blockquoteString)
  }//end if (exportFormat == EXPORT_FORMAT_MATHML)
  else
    [pasteboard setData:data forType:type];
  
  if (data)
  {
    if ([type isEqualToString:NSFileContentsPboardType])
      [pasteboard setData:data forType:NSFileContentsPboardType];
    else if ([type isEqualToString:NSFilenamesPboardType])
    {
      NSString* folder = [[NSWorkspace sharedWorkspace] temporaryDirectory];
      NSString* filePrefix = [self computeFileName];
      if (!filePrefix || [filePrefix isEqualToString:@""])
        filePrefix = @"latexit-drag";
      NSString* filePath = !extension ? nil :
        [[NSFileManager defaultManager] getUnusedFilePathFromPrefix:filePrefix extension:extension folder:folder startSuffix:0];
      if (filePath)
      {
        [data writeToFile:filePath atomically:YES];
        [pasteboard setPropertyList:[NSArray arrayWithObjects:filePath, nil] forType:type];
        FileManagerHelper* fileManagerHelper = [FileManagerHelper defaultManager];
        [fileManagerHelper addSelfDestructingFile:filePath timeInterval:10];
      }//end if (filePath)
    }//end if ([type isEqualToString:NSFilenamesPboardType])
    else if ([type isEqualToString:NSURLPboardType])
    {
      NSString* folder = [[NSWorkspace sharedWorkspace] temporaryDirectory];
      NSString* filePrefix = [self computeFileName];
      if (!filePrefix || [filePrefix isEqualToString:@""])
        filePrefix = @"latexit-drag";
      NSString* filePath = !extension ? nil :
        [[NSFileManager defaultManager] getUnusedFilePathFromPrefix:filePrefix extension:extension folder:folder startSuffix:0];
      if (filePath)
      {
        [data writeToFile:filePath atomically:YES];
        NSURL* fileURL = !filePath ? nil : [NSURL fileURLWithPath:filePath];
        [pasteboard writeObjects:@[fileURL]];
        FileManagerHelper* fileManagerHelper = [FileManagerHelper defaultManager];
        [fileManagerHelper addSelfDestructingFile:filePath timeInterval:10];
      }//end if (filePath)
    }//end if ([type isEqualToString:NSURLPboardType])
  }//end if (data)
  
  DebugLog(1, @"<pasteboard:%p provideDataForType:%@", pasteboard, type);
}
//end pasteboard:provideDataForType:
-(id) plistDescription
{
  NSString* applicationVersion = [[NSWorkspace sharedWorkspace] applicationVersion];
  NSMutableDictionary* plist = 
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
       applicationVersion, @"version",
       [self pdfData], @"pdfData",
       [[self preamble] string], @"preamble",
       [[self sourceText] string], @"sourceText",
       [[self color] rgbaString], @"color",
       @(self.pointSize), @"pointSize",
       [self modeAsString], @"mode",
       self.date, @"date",
       nil];
  if (self.backgroundColor)
    plist[@"backgroundColor"] = [self.backgroundColor rgbaString];
  if (self.title)
    plist[@"title"] = self.title;
  return plist;
}
//end plistDescription

-(instancetype) initWithDescription:(id)description
{
  NSManagedObjectContext* managedObjectContext = [LatexitEquation currentManagedObjectContext];
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  [self beginUpdate];
  self.pdfData = description[@"pdfData"];
  NSString* string = description[@"preamble"];
  self.preamble = (!string ? nil : [[NSAttributedString alloc] initWithString:string]);
  string = description[@"sourceText"];
  self.sourceText = (!string ? nil : [[NSAttributedString alloc] initWithString:string]);
  self.color = [NSColor colorWithRgbaString:description[@"color"]];
  self.pointSize = [description[@"pointSize"] doubleValue];
  self.mode = [[self class] latexModeFromString:description[@"mode"]];
  self.date = description[@"date"];
  self.backgroundColor = [NSColor colorWithRgbaString:description[@"backgroundColor"]];
  self.title = description[@"title"];
  [self endUpdate];
  return self;
}
//end initWithDescription:

-(NSString*) computeFileName
{
  NSString* result = [[self title] copy];
  if (!result || [result isEqualToString:@""])
    result = [[self titleAuto] copy];
  if (!result || [result isEqualToString:@""])
    result = [[[self sourceText] string] copy];
  result = [[self class] computeFileNameFromContent:result];
  return result;
}
//end computeFileName

+(NSString*) computeFileNameFromContent:(NSString*)content
{
  NSString* result = nil;
  NSMutableString* mutableString = [content mutableCopy];
  NSUInteger oldLength = mutableString.length;
  BOOL stop = !oldLength;
  while(!stop)
  {
    [mutableString replaceOccurrencesOfRegex:@"\\\\begin\\{(.+)\\}(.*)\\\\end\\{\\1\\}" withString:@"$2" options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\\\" withString:@" " options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\{" withString:@" " options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\}" withString:@" " options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\[" withString:@" " options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\]" withString:@" " options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\:" withString:@" " options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"([[:space:]]+)" withString:@"_" options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"(_*)\\^(_*)" withString:@"\\^" options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"__" withString:@"_" options:RKLMultiline|RKLDotAll range:[mutableString range] error:nil];
    [mutableString replaceOccurrencesOfRegex:@"^([_%]+)" withString:@""];
    [mutableString replaceOccurrencesOfRegex:@"(_+)$" withString:@""];
    [mutableString replaceOccurrencesOfRegex:@"\\/" withString:@"\xE2\x88\x95"];
    NSUInteger newLength = mutableString.length;
    stop |= !newLength || (newLength >= oldLength);
    oldLength = newLength;
  }//end while(!stop)
  result = [mutableString trim];
  result = [result substringWithRange:NSMakeRange(0, MIN([result length], 16U))];
  return result;
}
//end computeFileNameFromContent:

@end
