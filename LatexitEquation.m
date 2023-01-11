//
//  LatexitEquation.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/10/08.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import "LatexitEquation.h"

#import "NSAttributedStringExtended.h"
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
#import "Utils.h"

#if !defined(CH_APP_EXTENSION) && !defined(CH_APP_XPC_SERVICE)
#import <LinkBack/LinkBack.h>
#endif

#import <Quartz/Quartz.h>

#import <libxml/parser.h>
#import <libxml/xpath.h>
#import <libxml/HTMLparser.h>

#ifdef ARC_ENABLED
#define CHBRIDGE __bridge
#else
#define CHBRIDGE
#endif

static NSDictionary* DictionaryForNode(xmlNodePtr currentNode, NSMutableDictionary* parentResult)
{
  NSDictionary* result = nil;
  if (currentNode)
  {
    NSMutableDictionary* resultForNode = [NSMutableDictionary dictionary];
    if (currentNode->name)
    {
      NSString* currentNodeContent = [NSString stringWithCString:(const char *)currentNode->name encoding:NSUTF8StringEncoding];
      [resultForNode setObject:currentNodeContent forKey:@"nodeName"];
    }//end if (currentNode->name)
    
    if (currentNode->content && (currentNode->type != XML_DOCUMENT_TYPE_NODE))
    {
      NSString* currentNodeContent =
        [NSString stringWithCString:(const char *)currentNode->content encoding:NSUTF8StringEncoding];
      if ([[resultForNode objectForKey:@"nodeName"] isEqual:@"text"] && parentResult)
      {
        currentNodeContent = [currentNodeContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString* existingContent = [parentResult objectForKey:@"nodeContent"];
        NSString* newContent = !existingContent ? currentNodeContent : [existingContent stringByAppendingString:currentNodeContent];
        if (newContent)
          [parentResult setObject:newContent forKey:@"nodeContent"];
        return nil;
      }
      [resultForNode setObject:currentNodeContent forKey:@"nodeContent"];
    }//end if (currentNode->content && (currentNode->type != XML_DOCUMENT_TYPE_NODE))
    
    NSMutableArray* attributeArray = [NSMutableArray array];
    for(xmlAttr* attribute = currentNode->properties ; attribute != 0 ; attribute = attribute->next)
    {
      NSMutableDictionary* attributeDictionary = [NSMutableDictionary dictionary];
      NSString *attributeName = [NSString stringWithCString:(const char *)attribute->name encoding:NSUTF8StringEncoding];
      if (attributeName)
        [attributeDictionary setObject:attributeName forKey:@"attributeName"];
      if (attribute->children)
      {
        NSDictionary *childDictionary = DictionaryForNode(attribute->children, attributeDictionary);
        if (childDictionary)
          [attributeDictionary setObject:childDictionary forKey:@"attributeContent"];
      }//end if (attribute->children)
      if ([attributeDictionary count] > 0)
        [attributeArray addObject:attributeDictionary];
    }//end for each attribute
    if ([attributeArray count] > 0)
      [resultForNode setObject:attributeArray forKey:@"nodeAttributeArray"];

    NSMutableArray* childContentArray = [NSMutableArray array];
    for(xmlNodePtr childNode = currentNode->children ; childNode != 0 ; childNode = childNode->next)
    {
      NSDictionary* childDictionary = DictionaryForNode(childNode, resultForNode);
      if (childDictionary)
        [childContentArray addObject:childDictionary];
    }//end for each childNode
    if ([childContentArray count] > 0)
      [resultForNode setObject:childContentArray forKey:@"nodeChildArray"];
    result = resultForNode;
	}//end if (currentNode)
	return result;
}
//end DictionaryForNode()

static NSArray* PerformXPathQuery(xmlDocPtr doc, NSString* query)
{
  NSArray* result = nil;
  xmlXPathContextPtr xpathCtx = xmlXPathNewContext(doc);
  if (xpathCtx != 0)
  {
    xmlChar *queryString = (xmlChar *)[query cStringUsingEncoding:NSUTF8StringEncoding];
    xmlXPathObjectPtr xpathObj = xmlXPathEvalExpression(queryString, xpathCtx);
    xmlNodeSetPtr nodes = !xpathObj ? 0 : xpathObj->nodesetval;
    if (nodes)
    {
      NSMutableArray* resultNodes = [NSMutableArray array];
      for(NSInteger i = 0; i < nodes->nodeNr; ++i)
      {
        NSDictionary* nodeDictionary = DictionaryForNode(nodes->nodeTab[i], nil);
        if (nodeDictionary)
          [resultNodes addObject:nodeDictionary];
      }//end for each node
      result = resultNodes;
    }//end if (nodes)
    if (xpathObj != 0)
      xmlXPathFreeObject(xpathObj);
    xmlXPathFreeContext(xpathCtx);
  }//end if (xpathCtx != 0)
  return result;
}
//end PerformXPathQuery(xmlDocPtr, NSString*)

static NSArray* PerformHTMLXPathQuery(NSData* document, NSString* query)
{
  NSArray *result = nil;
  xmlDocPtr doc = htmlReadMemory([document bytes], (int)[document length], "", 0, XML_PARSE_RECOVER);
  if (doc != 0)
  {
    result = PerformXPathQuery(doc, query);
    xmlFreeDoc(doc);
  }//end if (doc != 0)
  return result;
}
//end PerformHTMLXPathQuery(NSData*, NSString*)

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
-(void) setLatexitMetadata:(id)plist;
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

-(void) dealloc
{
#ifndef ARC_ENABLED
  [self->latexitMetadataString release];
  [self->latexitMetadata release];
#endif
  if (self->curvePoints)
    free(self->curvePoints);
#ifndef ARC_ENABLED
  [super dealloc];
#endif
}
//end dealloc

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
#ifndef ARC_ENABLED
  [candidateString release];
#endif
}
//end checkMetadataFromCurvePointBytes

-(void) checkMetadataFromString:(NSString*)string
{
  NSError* error = nil;
  NSArray* components =
    [string captureComponentsMatchedByRegex:@"^\\<latexit sha1_base64=\"(.*?)\"\\>(.*?)\\</latexit\\>\\x00*$"
                                    options:RKLMultiline|RKLDotAll
                                      range:string.range error:&error];
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
        CFDataRef data = CGPDFStreamCopyData(stream, &dataFormat);
        if (data && (dataFormat == CGPDFDataFormatRaw))
          #ifdef ARC_ENABLED
          [((CHBRIDGE NSMutableArray*) info) addObject:(CHBRIDGE NSData*)data];
          #else
          [((NSMutableArray*) info) addObject:[(NSData*)data autorelease]];
          #endif
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
      #ifdef ARC_ENABLED
      [((CHBRIDGE NSMutableArray*) info) addObject:(CHBRIDGE NSData*)data];
      #else
      [((NSMutableArray*) info) addObject:[(NSData*)data autorelease]];
      #endif
    else if (data)
      CFRelease(data);
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
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(CHBRIDGE id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
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
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(CHBRIDGE id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
  [pdfScanningContext checkMetadataFromCurvePointBytes];
  [pdfScanningContext resetCurvePoints];
}
//end CHCGPDFOperatorCallback_h()

static void CHCGPDFOperatorCallback_l(CGPDFScannerRef scanner, void *info)
{
  //lineto (1 point)
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(CHBRIDGE id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
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
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(CHBRIDGE id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
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
    
    LaTeXiTMetaDataParsingContext* pdfScanningContext = [(CHBRIDGE id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];

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
  LaTeXiTMetaDataParsingContext* pdfScanningContext = [(CHBRIDGE id)info dynamicCastToClass:[LaTeXiTMetaDataParsingContext class]];
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

NSString* const LatexitEquationsPboardType = @"LatexitEquationsPboardType";

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
      #ifdef ARC_ENABLED
      if (!cachedEntity)
        cachedEntity = [[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])];
      #else
      if (!cachedEntity)
        cachedEntity = [[[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])] retain];
      #endif
    }//end @synchronized(self)
  }//end if (!cachedEntity)
  return cachedEntity;
}
//end entity

+(BOOL) supportsSecureCoding {return YES;}

+(NSSet*) allowedSecureDecodedClasses
{
  static NSSet* _result = nil;
  if (!_result)
  {
    @synchronized(self)
    {
      if (!_result)
        _result = [[NSSet alloc] initWithObjects:
          [NSArray class], [NSMutableArray class],
          [NSDictionary class], [NSMutableDictionary class],
          [NSSet class], [NSMutableSet class],
          [NSData class], [NSMutableData class],
          [NSString class], [NSMutableString class],
          [NSAttributedString class], [NSMutableAttributedString class],
          [NSTextTab class],//needed by a bug in High Sierra
          [NSNumber class],
          [NSColor class],
          [NSDate class],
          [NSFont class],
          [LatexitEquation class],
          nil];
    }//end @synchronized(self)
  }//end if (!_result)
  return _result;
}
//end allowedSecureDecodedClasses

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
  DebugLog(1, @"shoudDecodeFromAnnotations = %d", shoudDecodeFromAnnotations);
  if (shoudDecodeFromAnnotations)
  {
    PDFDocument* pdfDocument = nil;
    NSDictionary* embeddedInfos = nil;
    @try{
      pdfDocument = [[PDFDocument alloc] initWithData:someData];
      PDFPage*     pdfPage     = [pdfDocument pageAtIndex:0];
      NSArray<PDFAnnotation*>* annotations     = [pdfPage annotations];
      NSUInteger i = 0;
      DebugLog(1, @"annotations = %@", annotations);
      for(i = 0 ; !embeddedInfos && (i < [annotations count]) ; ++i)
      {
        id annotation = [annotations objectAtIndex:i];
        if ([annotation isKindOfClass:[PDFAnnotation class]] && [((PDFAnnotation*)annotation).type isEqualToString:PDFAnnotationSubtypeText])
        {
          PDFAnnotation* annotationTextCandidate = (PDFAnnotation*)annotation;
          DebugLog(1, @"annotationTextCandidate = %@", annotationTextCandidate);
          if ([[annotationTextCandidate userName] isEqualToString:@"fr.chachatelier.pierre.LaTeXiT"])
          {
            NSString* contents = [annotationTextCandidate contents];
            NSData* data = !contents ? nil : [NSData dataWithBase64:contents];
            @try{
              NSError* decodingError = nil;
              embeddedInfos = !data ? nil :
                isMacOS10_13OrAbove() ? [[NSKeyedUnarchiver unarchivedObjectOfClasses:[self allowedSecureDecodedClasses] fromData:data error:&decodingError]  dynamicCastToClass:[NSDictionary class]]:
                [[NSKeyedUnarchiver unarchiveObjectWithData:data] dynamicCastToClass:[NSDictionary class]];
              if (decodingError != nil)
                DebugLog(0, @"decoding error : %@", decodingError);
              DebugLog(1, @"embeddedInfos = %@", embeddedInfos);
            }
            @catch(NSException* e){
              DebugLog(0, @"exception : %@", e);
            }
          }//end if ([[annotationTextCandidate userName] isEqualToString:@"fr.chachatelier.pierre.LaTeXiT"])
        }//end if ([annotation isKindOfClass:PDFAnnotation])
      }//end for each annotation
    }
    @catch(NSException* e) {
      DebugLog(0, @"exception : %@", e);
    }
    @finally{
      #ifdef ARC_ENABLED
      #else
      [pdfDocument release];
      #endif
    }
    if (embeddedInfos)
    {
      DebugLog(1, @"embeddedInfos found = %@", embeddedInfos);
      NSString* preambleAsString = [embeddedInfos objectForKey:@"preamble"];
      NSAttributedString* preamble = !preambleAsString ? nil :
        [[NSAttributedString alloc] initWithString:preambleAsString attributes:defaultAttributes];
      [result setObject:(!preamble ? defaultPreambleAttributedString : preamble) forKey:@"preamble"];
      #ifdef ARC_ENABLED
      preamble = nil;
      #else
      [preamble release];
      #endif

      id modeAsObject = [embeddedInfos objectForKey:@"mode"];
      NSNumber* modeAsNumber = [modeAsObject dynamicCastToClass:[NSNumber class]];
      NSString* modeAsString = [modeAsObject dynamicCastToClass:[NSString class]];
      if (!modeAsNumber && modeAsString)
        modeAsNumber = @([modeAsString integerValue]);
      latex_mode_t mode = modeAsNumber ? (latex_mode_t)[modeAsNumber integerValue] :
                                         (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : LATEX_MODE_TEXT);
      [result setObject:@((mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode) forKey:@"mode"];

      NSString* sourceAsString = [embeddedInfos objectForKey:@"source"];
      NSAttributedString* sourceText =
        [[NSAttributedString alloc] initWithString:(!sourceAsString ? @"" : sourceAsString) attributes:defaultAttributes];
      if (mode == LATEX_MODE_EQNARRAY)
      {
        NSMutableAttributedString* sourceText2 = [[NSMutableAttributedString alloc] init];
        #ifdef ARC_ENABLED
        [sourceText2 appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] ];
        [sourceText2 appendAttributedString:sourceText];
        [sourceText2 appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] ];
        #else

        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] autorelease]];
        [sourceText2 appendAttributedString:sourceText];
        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] autorelease]];
        [sourceText release];
        #endif
        sourceText = sourceText2;
      }
      [result setObject:sourceText forKey:@"sourceText"];
      #ifdef ARC_ENABLED
      sourceText = nil;
      #else
      [sourceText release];
      #endif
      
      NSNumber* pointSizeAsNumber = [embeddedInfos objectForKey:@"magnification"];
      [result setObject:(pointSizeAsNumber ? pointSizeAsNumber :
                         @(useDefaults ? [preferencesController latexisationFontSize] : 0))
                 forKey:@"magnification"];

      NSNumber* baselineAsNumber = [embeddedInfos objectForKey:@"baseline"];
      [result setObject:(baselineAsNumber ? baselineAsNumber : @(0.))
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
      isLaTeXiTPDF = YES;
      DebugLog(1, @"decodedFromAnnotation = %d", decodedFromAnnotation);
    }//end if (embeddedInfos)
  }//end if (shoudDecodeFromAnnotations)
  
  BOOL shouldDecodeLEE = !isLaTeXiTPDF;
  DebugLog(1, @"shouldDecodeLEE = %d", shouldDecodeLEE);
  if (!isLaTeXiTPDF && shouldDecodeLEE)
  {
    #ifdef ARC_ENABLED
    NSString* dataAsString = [[NSString alloc] initWithData:someData encoding:NSMacOSRomanStringEncoding];
    #else
    NSString* dataAsString = [[[NSString alloc] initWithData:someData encoding:NSMacOSRomanStringEncoding] autorelease];
    #endif
    NSArray*  testArray    = nil;
    
    NSMutableString* preambleString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Preamble (ESannop"];
    if (testArray && ([testArray count] >= 2))
    {
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
      isLaTeXiTPDF |= YES;
      preambleString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [preambleString rangeOfString:@"ESannopend"];
      range.length = (range.location != NSNotFound) ? [preambleString length]-range.location : 0;
      [preambleString deleteCharactersInRange:range];
      [preambleString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:preambleString.range];
      [preambleString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:preambleString.range];
      [preambleString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:preambleString.range];
      [preambleString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:preambleString.range];
    }
    #ifdef ARC_ENABLED
    NSAttributedString* preamble =
      preambleString ? [[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes]
                     : (useDefaults ? defaultPreambleAttributedString
                                    : [[NSAttributedString alloc] initWithString:@"" attributes:defaultAttributes]);
    #else
    NSAttributedString* preamble =
      preambleString ? [[[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes] autorelease]
                     : (useDefaults ? defaultPreambleAttributedString
                                    : [[[NSAttributedString alloc] initWithString:@"" attributes:defaultAttributes] autorelease]);
    #endif

    //test escaped preample from version 1.13.0
    testArray = [dataAsString componentsSeparatedByString:@"/EscapedPreamble (ESannoep"];
    if (testArray && ([testArray count] >= 2))
    {
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
      isLaTeXiTPDF |= YES;
      preambleString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [preambleString rangeOfString:@"ESannoepend"];
      range.length = (range.location != NSNotFound) ? [preambleString length]-range.location : 0;
      [preambleString deleteCharactersInRange:range];
      NSString* unescapedPreamble = [preambleString stringByRemovingPercentEncoding];
      [preambleString setString:unescapedPreamble];
    }
    #ifdef ARC_ENABLED
    preamble = preambleString ? [[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes]
                              : preamble;
    #else
    preamble = preambleString ? [[[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes] autorelease]
                              : preamble;
    #endif
    [result setObject:preamble forKey:@"preamble"];

    NSMutableString* modeAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Type (EEtype"];
    if (testArray && ([testArray count] >= 2))
    {
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
      isLaTeXiTPDF |= YES;
      modeAsString  = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [modeAsString rangeOfString:@"EEtypeend"];
      range.length = (range.location != NSNotFound) ? [modeAsString length]-range.location : 0;
      [modeAsString deleteCharactersInRange:range];
    }
    latex_mode_t mode = modeAsString ? (latex_mode_t) [modeAsString integerValue]
                        : (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : 0);
    mode = (mode == LATEX_MODE_EQNARRAY) ? mode : validateLatexMode(mode); //Added starting from version 1.7.0
    [result setObject:@((mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode) forKey:@"mode"];

    NSMutableString* sourceString = [NSMutableString string];
    testArray = [dataAsString componentsSeparatedByString:@"/Subject (ESannot"];
    if (testArray && ([testArray count] >= 2))
    {
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
      isLaTeXiTPDF |= YES;
      [sourceString appendString:[testArray objectAtIndex:1]];
      NSRange range = [sourceString rangeOfString:@"ESannotend"];
      range.length = (range.location != NSNotFound) ? [sourceString length]-range.location : 0;
      [sourceString deleteCharactersInRange:range];
      [sourceString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:sourceString.range];
      [sourceString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:sourceString.range];
      [sourceString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:sourceString.range];
      [sourceString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:sourceString.range];
    }
    #ifdef ARC_ENABLED
    NSAttributedString* sourceText =
      [[NSAttributedString alloc] initWithString:(!sourceString ? @"" : sourceString) attributes:defaultAttributes] ;
    #else
    NSAttributedString* sourceText =
      [[NSAttributedString alloc] initWithString:(!sourceString ? @"" : sourceString) attributes:defaultAttributes];
    #endif

    //test escaped source from version 1.13.0
    testArray = [dataAsString componentsSeparatedByString:@"/EscapedSubject (ESannoes"];
    if (testArray && ([testArray count] >= 2))
    {
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
      isLaTeXiTPDF |= YES;
      [sourceString setString:@""];
      [sourceString appendString:[testArray objectAtIndex:1]];
      NSRange range = !sourceString ? NSMakeRange(0, 0) : [sourceString rangeOfString:@"ESannoesend"];
      range.length = (range.location != NSNotFound) ? [sourceString length]-range.location : 0;
      [sourceString deleteCharactersInRange:range];
      NSString* unescapedSource = [sourceString stringByRemovingPercentEncoding];
      [sourceString setString:unescapedSource];
    }
    #ifdef ARC_ENABLED
    sourceText = sourceString ? [[NSAttributedString alloc] initWithString:sourceString attributes:defaultAttributes]
                              : sourceText;
    #else
    sourceText = sourceString ? [[[NSAttributedString alloc] initWithString:sourceString attributes:defaultAttributes] autorelease]
                              : sourceText;
    #endif

    if (mode == LATEX_MODE_EQNARRAY)
    {
      #ifdef ARC_ENABLED
      NSMutableAttributedString* sourceText2 = [[NSMutableAttributedString alloc] init];
      [sourceText2 appendAttributedString:
        [[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] ];
      [sourceText2 appendAttributedString:sourceText];
      [sourceText2 appendAttributedString:
        [[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes]];
      #else
      NSMutableAttributedString* sourceText2 = [[[NSMutableAttributedString alloc] init] autorelease];
      [sourceText2 appendAttributedString:
        [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] autorelease]];
      [sourceText2 appendAttributedString:sourceText];
      [sourceText2 appendAttributedString:
        [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] autorelease]];
      #endif
      sourceText = sourceText2;
    }
    if (sourceText)
      [result setObject:sourceText forKey:@"sourceText"];

    NSMutableString* pointSizeAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Magnification (EEmag"];
    if (testArray && ([testArray count] >= 2))
    {
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
      isLaTeXiTPDF |= YES;
      pointSizeAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [pointSizeAsString rangeOfString:@"EEmagend"];
      range.length  = (range.location != NSNotFound) ? [pointSizeAsString length]-range.location : 0;
      [pointSizeAsString deleteCharactersInRange:range];
    }
    [result setObject:@(pointSizeAsString ? [pointSizeAsString doubleValue] : (useDefaults ? [preferencesController latexisationFontSize] : 0)) forKey:@"magnification"];

    NSColor* defaultColor = [preferencesController latexisationFontColor];
    NSMutableString* colorAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Color (EEcol"];
    if (testArray && ([testArray count] >= 2))
    {
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
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
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
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
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
      isLaTeXiTPDF |= YES;
      baselineAsString  = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [baselineAsString rangeOfString:@"EEbasend"];
      range.length = (range.location != NSNotFound) ? [baselineAsString length]-range.location : 0;
      [baselineAsString deleteCharactersInRange:range];
    }
    [result setObject:@(baselineAsString ? [baselineAsString doubleValue] : 0.) forKey:@"baseline"];

    NSMutableString* titleAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/Title (EEtitle"];
    if (testArray && ([testArray count] >= 2))
    {
      DebugLog(2, @"[testArray objectAtIndex:1] = %@", [testArray objectAtIndex:1]);
      isLaTeXiTPDF |= YES;
      titleAsString  = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [titleAsString rangeOfString:@"EEtitleend"];
      range.length = (range.location != NSNotFound) ? [titleAsString length]-range.location : 0;
      [titleAsString deleteCharactersInRange:range];
    }
    [result setObject:(!titleAsString ? @"" : titleAsString) forKey:@"title"];
    
    [result setObject:[NSDate date] forKey:@"date"];
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
        CGPDFDictionaryApplyFunction(catalog, extractStreamObjectsFunction, (CHBRIDGE void*)streamObjects);
      if (pageDictionary)
        CGPDFDictionaryApplyFunction(pageDictionary, extractStreamObjectsFunction, (CHBRIDGE void*)streamObjects);
      NSEnumerator* enumerator = [streamObjects objectEnumerator];
      id streamData = nil;
      NSData* pdfHeader = [@"%PDF" dataUsingEncoding:NSUTF8StringEncoding];
      while(!isLaTeXiTPDF && ((streamData = [enumerator nextObject])))
      {
        NSData* streamAsData = [streamData dynamicCastToClass:[NSData class]];
        NSData* streamAsPdfData = 
          ([streamAsData rangeOfData:pdfHeader options:NSDataSearchAnchored range:NSMakeRange(0, [streamAsData length])].location == NSNotFound) ?
          nil : streamAsData;
        NSData* pdfData2 = nil;
        #ifdef ARC_ENABLED
        NSDictionary* result2 = !streamAsPdfData ? nil :
          [[self metaDataFromPDFData:streamAsPdfData useDefaults:NO outPdfData:&pdfData2] mutableCopy];
        #else
        NSDictionary* result2 = !streamAsPdfData ? nil :
          [[[self metaDataFromPDFData:streamAsPdfData useDefaults:NO outPdfData:&pdfData2] mutableCopy] autorelease];
        #endif
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
        CGPDFScannerCreate(contentStream, operatorTable, (CHBRIDGE void * _Nullable)(pdfScanningContext));
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
      NSString* preambleAsString = [latexitMetadata objectForKey:@"preamble"];
      NSAttributedString* preamble = !preambleAsString ? nil :
        [[NSAttributedString alloc] initWithString:preambleAsString attributes:defaultAttributes];
      [result setObject:(!preamble ? defaultPreambleAttributedString : preamble) forKey:@"preamble"];
      #ifdef ARC_ENABLED
      #else
      [preamble release];
      #endif

      id modeAsObject = nil;
      if (!modeAsObject)
        modeAsObject = [latexitMetadata objectForKey:@"type"];
      if (!modeAsObject)
        modeAsObject = [latexitMetadata objectForKey:@"mode"];
      NSNumber* modeAsNumber = [modeAsObject dynamicCastToClass:[NSNumber class]];
      NSString* modeAsString = [modeAsObject dynamicCastToClass:[NSString class]];
      if (!modeAsNumber && modeAsString)
        modeAsNumber = @([modeAsString integerValue]);
      latex_mode_t mode = modeAsNumber ? (latex_mode_t)[modeAsNumber integerValue] :
                                         (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : LATEX_MODE_TEXT);
      [result setObject:@((mode == LATEX_MODE_EQNARRAY) ? LATEX_MODE_TEXT : mode) forKey:@"mode"];

      NSString* sourceAsString = [latexitMetadata objectForKey:@"source"];
      NSAttributedString* sourceText =
        [[NSAttributedString alloc] initWithString:(!sourceAsString ? @"" : sourceAsString) attributes:defaultAttributes];
      if (mode == LATEX_MODE_EQNARRAY)
      {
        NSMutableAttributedString* sourceText2 = [[NSMutableAttributedString alloc] init];
        #ifdef ARC_ENABLED
        [sourceText2 appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] ];
        [sourceText2 appendAttributedString:sourceText];
        [sourceText2 appendAttributedString:
          [[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] ];
        #else
        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:defaultAttributes] autorelease]];
        [sourceText2 appendAttributedString:sourceText];
        [sourceText2 appendAttributedString:
          [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:defaultAttributes] autorelease]];
        [sourceText release];
        #endif
        sourceText = sourceText2;
      }
      [result setObject:sourceText forKey:@"sourceText"];
      #ifdef ARC_ENABLED
      #else
      [sourceText release];
      #endif
      
      NSNumber* pointSizeAsNumber = [latexitMetadata objectForKey:@"magnification"];
      [result setObject:(pointSizeAsNumber ? pointSizeAsNumber :
                         @(useDefaults ? [preferencesController latexisationFontSize] : 0))
                 forKey:@"magnification"];

      NSNumber* baselineAsNumber = [latexitMetadata objectForKey:@"baseline"];
      [result setObject:(baselineAsNumber ? baselineAsNumber : @(0.))
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
      CGPDFScannerCreate(contentStream, operatorTable, (CHBRIDGE void * _Nullable)(pdfScanningContext));
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
  if (UTTypeConformsTo((CHBRIDGE CFStringRef)uti, CFSTR("com.adobe.pdf")))
    result = YES;
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)uti, CFSTR("public.tiff")))
    result = YES;
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)uti, CFSTR("public.png")))
    result = YES;
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)uti, CFSTR("public.jpeg")))
    result = YES;
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)uti, CFSTR("public.svg-image")))
    result = YES;
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)uti, CFSTR("public.html")))
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
  if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("com.adobe.pdf")))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.tiff")))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.png")))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.jpeg")))
    [equations safeAddObject:[self latexitEquationWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults]];
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.svg-image")))
  {
    NSError* error = nil;
    #ifdef ARC_ENABLED
    NSString* string = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
    #else
    NSString* string = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
    #endif
    NSArray* descriptions =
      [string componentsMatchedByRegex:@"<svg(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</svg>"
                               options:RKLCaseless|RKLMultiline|RKLDotAll
                                 range:string.range capture:0 error:&error];
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
  else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.html")))
  {
    NSError* error = nil;
    #ifdef ARC_ENABLED
    NSString* string = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
    #else
    NSString* string = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
    #endif
    NSArray* descriptions_legacy =
      [string componentsMatchedByRegex:@"<blockquote(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</blockquote>"
                               options:RKLCaseless|RKLMultiline|RKLDotAll
                                 range:string.range capture:0 error:&error];
    if (error)
      DebugLog(1, @"error : %@", error);
    NSArray* descriptions =
      [string componentsMatchedByRegex:@"<math(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</math>"
                               options:RKLCaseless|RKLMultiline|RKLDotAll
                                 range:string.range capture:0 error:&error];
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
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.html")))
  result = [NSArray arrayWithArray:equations];
  return result;
}
//end latexitEquationsWithData:sourceUTI:useDefaults

+(id) latexitEquationWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
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

+(id) latexitEquationWithMetaData:(NSDictionary*)metaData useDefaults:(BOOL)useDefaults
{
  #ifdef ARC_ENABLED
  return [[[self class] alloc] initWithMetaData:metaData useDefaults:useDefaults];
  #else
  return [[[[self class] alloc] initWithMetaData:metaData useDefaults:useDefaults] autorelease];
  #endif
}
//end latexitEquationWithData:sourceUTI:useDefaults:

+(id) latexitEquationWithData:(NSData*)someData sourceUTI:(NSString*)sourceUTI useDefaults:(BOOL)useDefaults
{
  #ifdef ARC_ENABLED
  return [[[self class] alloc] initWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults];
  #else
  return [[[[self class] alloc] initWithData:someData sourceUTI:sourceUTI useDefaults:useDefaults] autorelease];
  #endif
}
//end latexitEquationWithData:sourceUTI:useDefaults:

+(id) latexitEquationWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
{
  #ifdef ARC_ENABLED
  return [[[self class] alloc] initWithPDFData:someData useDefaults:useDefaults];
  #else
  return [[[[self class] alloc] initWithPDFData:someData useDefaults:useDefaults] autorelease];
  #endif
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
              backgroundColor:(NSColor*)aBackgroundColor title:(NSString*)aTitle
{
  if (!((self = [self initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
  [self beginUpdate];
  [self setPdfData:someData];
  [self setPreamble:aPreamble];
  [self setSourceText:aSourceText];
  [self setColor:aColor];
  [self setPointSize:aPointSize];
  #ifdef ARC_ENABLED
  [self setDate:aDate ? [aDate copy] : [NSDate date]];
  #else
  [self setDate:aDate ? [[aDate copy] autorelease] : [NSDate date]];
  #endif
  [self setMode:aMode];
  [self setTitle:aTitle];
    
  if (!aBackgroundColor && [[PreferencesController sharedController] documentUseAutomaticHighContrastedPreviewBackground])
    aBackgroundColor = ([aColor grayLevel] > .5) ? [NSColor blackColor] : nil;
  [self setBackgroundColor:aBackgroundColor];
  self->annotateDataDirtyState = NO;
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
    [self setMode:(latex_mode_t)[mode integerValue]];

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
    [self setMode:(latex_mode_t)[mode integerValue]];

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
  
  self->annotateDataDirtyState = NO;
  [self endUpdate];

  if (!isLaTeXiTPDF)
  {
    #ifdef ARC_ENABLED
    #else
    [self release];
    #endif
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
      [preambleString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:preambleString.range];
      [preambleString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:preambleString.range];
      [preambleString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:preambleString.range];
      [preambleString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:preambleString.range];
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
      [sourceString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:sourceString.range];
      [sourceString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:sourceString.range];
      [sourceString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:sourceString.range];
      [sourceString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:sourceString.range];
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
  {
    #ifdef ARC_ENABLED
    #else
    [self release];
    #endif
  }//end if (!sourceUTI)
  else//if (sourceUTI)
  {
    if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("com.adobe.pdf")))
      result = [self initWithPDFData:someData useDefaults:useDefaults];
    else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.tiff"))||
             UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.png"))||
             UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.jpeg")))
    {
      CGImageSourceRef imageSource = CGImageSourceCreateWithData((CHBRIDGE CFDataRef)someData,
        (CHBRIDGE CFDictionaryRef)@{(NSString*)kCGImageSourceShouldCache:@(NO)});
      CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil);
      DebugLog(1, @"properties = %@", properties);
      id infos = [(CHBRIDGE NSDictionary*)properties objectForKey:(NSString*)kCGImagePropertyExifDictionary];
      id annotationBase64 = ![infos isKindOfClass:[NSDictionary class]] ? nil : [infos objectForKey:(NSString*)kCGImagePropertyExifUserComment];
      NSData* annotationData = ![annotationBase64 isKindOfClass:[NSString class]] ? nil :
        [NSData dataWithBase64:annotationBase64];
      DebugLog(1, @"annotationData(64) = %@", annotationData);
      annotationData = [Compressor zipuncompress:annotationData];
      DebugLog(1, @"annotationData(z) = %@", annotationData);
      NSError* decodingError = nil;
      NSDictionary* metaData = !annotationData ? nil :
        isMacOS10_13OrAbove() ? [[NSKeyedUnarchiver unarchivedObjectOfClasses:[[self class] allowedSecureDecodedClasses] fromData:annotationData error:&decodingError] dynamicCastToClass:[NSDictionary class]] :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      if (decodingError != nil)
        DebugLog(0, @"decoding error : %@", decodingError);
      DebugLog(1, @"metaData = %@", metaData);
      result = [self initWithMetaData:metaData useDefaults:useDefaults];
      if (properties)
        CFRelease(properties);
      if (imageSource)
        CFRelease(imageSource);
    }//end if (tiff, png, jpeg)
    else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.svg-image")))
    {
      #ifdef ARC_ENABLED
      NSString* svgString = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
      #else
      NSString* svgString = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
      #endif
      NSString* annotationBase64 =
        [svgString stringByMatching:@"<!--latexit:(.*?)-->" options:RKLCaseless|RKLDotAll|RKLMultiline
          inRange:svgString.range capture:1 error:0];
      NSData* annotationData = !annotationBase64 ? nil : [NSData dataWithBase64:annotationBase64];
      annotationData = !annotationData ? nil : [Compressor zipuncompress:annotationData];
      NSError* decodingError = nil;
      NSDictionary* metaData = !annotationData ? nil :
        isMacOS10_13OrAbove() ? [NSKeyedUnarchiver unarchivedObjectOfClasses:[[self class] allowedSecureDecodedClasses] fromData:annotationData error:&decodingError] :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      if (decodingError != nil)
        DebugLog(0, @"decoding error : %@", decodingError);
      result = !metaData ? nil : [self initWithMetaData:metaData useDefaults:useDefaults];
      if (!result) {
#ifndef ARC_ENABLED
        [self release];
#endif
      }
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.svg-image")))
    else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.html")))
    {
      #ifdef ARC_ENABLED
      NSString* htmlString = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
      #else
      NSString* htmlString = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
      #endif
      //first, try LaTeXiT mathml
      NSString* annotationBase64 =
        [htmlString stringByMatching:@"<!--latexit:(.*?)-->" options:RKLCaseless|RKLDotAll|RKLMultiline
          inRange:NSMakeRange(0, [htmlString length]) capture:1 error:0];
      NSData* annotationData = !annotationBase64 ? nil : [NSData dataWithBase64:annotationBase64];
      annotationData = !annotationData ? nil : [Compressor zipuncompress:annotationData];
      NSError* decodingError = nil;
      NSDictionary* metaData = !annotationData ? nil :
        isMacOS10_13OrAbove() ? [[NSKeyedUnarchiver unarchivedObjectOfClasses:[[self class] allowedSecureDecodedClasses] fromData:annotationData error:&decodingError] dynamicCastToClass:[NSDictionary class]] :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      if (decodingError != nil)
        DebugLog(0, @"decoding error : %@", decodingError);
      result = !metaData ? nil : [self initWithMetaData:metaData useDefaults:useDefaults];
      if (!result)
      {
        NSArray* elements = PerformHTMLXPathQuery(someData, @"//span[@class=\"mwe-math-element\"]/img/@alt");
        NSDictionary* element = [[elements lastObject] dynamicCastToClass:[NSDictionary class]];
        NSString* nodeContent = [[element objectForKey:@"nodeContent"] dynamicCastToClass:[NSString class]];
        NSArray* components = !nodeContent ? nil :
          [nodeContent captureComponentsMatchedByRegex:@"\\s*\\{\\s*(.*)\\s*\\}\\s*|\\s*(.*)\\s*" options:RKLDotAll range:NSMakeRange(0, [nodeContent length]) error:nil];
        NSString* latexSourceCode = nil;
        if (components.count == 3)
        {
          if ([NSString isNilOrEmpty:latexSourceCode])
            latexSourceCode = [[components objectAtIndex:1] dynamicCastToClass:[NSString class]];
          if ([NSString isNilOrEmpty:latexSourceCode])
            latexSourceCode = [[components objectAtIndex:2] dynamicCastToClass:[NSString class]];
        }//end if (components.count == 3)
        if (![NSString isNilOrEmpty:latexSourceCode])
        {
          NSString* latexSubSourceCode = latexSourceCode;
          NSRange latexSourceCodeRange = latexSourceCode.range;
          latex_mode_t latexMode = LATEX_MODE_TEXT;
          if (latexMode == LATEX_MODE_TEXT)
          {
            components = [latexSourceCode captureComponentsMatchedByRegex:@"^\\s*\\begin\\{align\\}(.*)\\\\end\\{align\\}\\s*$" options:RKLDotAll range:latexSourceCodeRange error:nil];
            if (components.count == 2)
            {
              latexSubSourceCode = [[components lastObject] dynamicCastToClass:[NSString class]];
              latexMode = LATEX_MODE_ALIGN;
            }//end if (components.count == 2)
          }//end if (latexMode == LATEX_MODE_TEXT)
          if (latexMode == LATEX_MODE_TEXT)
          {
            components = [latexSourceCode captureComponentsMatchedByRegex:@"^\\s*\\$\\$(.*)\\$\\$\\s*$" options:RKLDotAll range:latexSourceCodeRange error:nil];
            if (components.count == 2)
            {
              latexSubSourceCode = [[components lastObject] dynamicCastToClass:[NSString class]];
              latexMode = LATEX_MODE_DISPLAY;
            }//end if (components.count == 2)
          }//end if (latexMode == LATEX_MODE_TEXT)
          if (latexMode == LATEX_MODE_TEXT)
          {
            components = [latexSourceCode captureComponentsMatchedByRegex:@"^\\s*\\\\[(.*)\\\\]\\s*$" options:RKLDotAll range:latexSourceCodeRange error:nil];
            if (components.count == 2)
            {
              latexSubSourceCode = [[components lastObject] dynamicCastToClass:[NSString class]];
              latexMode = LATEX_MODE_DISPLAY;
            }//end if (components.count == 2)
          }//end if (latexMode == LATEX_MODE_TEXT)
          if (latexMode == LATEX_MODE_TEXT)
          {
            components = [latexSourceCode captureComponentsMatchedByRegex:@"^\\s*\\\\displaystyle(.*)\\s*$" options:RKLDotAll range:latexSourceCodeRange error:nil];
            if (components.count == 2)
            {
              latexSubSourceCode = [[components lastObject] dynamicCastToClass:[NSString class]];
              latexMode = LATEX_MODE_DISPLAY;
            }//end if (components.count == 2)
          }//end if (latexMode == LATEX_MODE_TEXT)
          if (latexMode == LATEX_MODE_TEXT)
          {
            components = [latexSourceCode captureComponentsMatchedByRegex:@"^\\s*\\$(.*)\\$\\s*$" options:RKLDotAll range:latexSourceCodeRange error:nil];
            if (components.count == 2)
            {
              latexSubSourceCode = [[components lastObject] dynamicCastToClass:[NSString class]];
              latexMode = LATEX_MODE_INLINE;
            }//end if (components.count == 2)
          }//end if (latexMode == LATEX_MODE_TEXT)
          PreferencesController* preferencesController = [PreferencesController sharedController];
          NSAttributedString* latexSourceCodeAttributed = !latexSubSourceCode ? nil :
            [[NSAttributedString alloc] initWithString:latexSubSourceCode];
          metaData = !latexSourceCodeAttributed ? nil : @{
            @"mode":@(latexMode),
            @"sourceText":latexSourceCodeAttributed,
            @"magnification":@([preferencesController latexisationFontSize])
          };
          result = !metaData ? nil : [self initWithMetaData:metaData useDefaults:useDefaults];
#ifndef ARC_ENABLED
        [latexSourceCodeAttributed release];
#endif
        }//end if (![NSString isNilOrEmpty:latexSourceCode])
      }//end if (!result)
      if (!result) {
#ifndef ARC_ENABLED
        [self release];
#endif
      }
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.html")))
    else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.text")))
    {
      #ifdef ARC_ENABLED
      NSString* string = [[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding];
      #else
      NSString* string = [[[NSString alloc] initWithData:someData encoding:NSUTF8StringEncoding] autorelease];
      #endif
      NSString* annotationBase64 = nil;
      if (!annotationBase64)
        annotationBase64 = [string stringByMatching:@"<!--latexit:(.*?)-->" options:RKLCaseless|RKLDotAll|RKLMultiline
                                            inRange:string.range capture:1 error:0];
      if (!annotationBase64)
        annotationBase64 = [string stringByMatching:@"([A-Za-z0-9\\+\\/\\n])*\\=*" options:RKLCaseless|RKLDotAll|RKLMultiline
                                            inRange:string.range capture:0 error:0];
      NSData* annotationData = !annotationBase64 ? nil : [NSData dataWithBase64:annotationBase64];
      annotationData = !annotationData ? nil : [Compressor zipuncompress:annotationData];
      NSError* decodingError = nil;
      NSDictionary* metaData = !annotationData ? nil :
        isMacOS10_13OrAbove() ? [[NSKeyedUnarchiver unarchivedObjectOfClasses:[[self class] allowedSecureDecodedClasses] fromData:annotationData error:&decodingError] dynamicCastToClass:[NSDictionary class]] :
        [[NSKeyedUnarchiver unarchiveObjectWithData:annotationData] dynamicCastToClass:[NSDictionary class]];
      if (decodingError != nil)
        DebugLog(0, @"decoding error : %@", decodingError);
      if (!metaData)
        result = nil;
      else
        result = [self initWithMetaData:metaData useDefaults:useDefaults];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.text")))
    else
    {
      #ifdef ARC_ENABLED
      #else
      [self release];
      #endif
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
  [[self managedObjectContext] safeInsertObject:clone];
  return clone;
}
//end copyWithZone:

-(id) initWithCoder:(NSCoder*)coder
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
  #ifndef ARC_ENABLED
  [super dealloc];
  #endif
}
//end dealloc

-(void) dispose
{
  [[self class] cancelPreviousPerformRequestsWithTarget:self];
  #ifndef ARC_ENABLED
  [self->exportPrefetcher release];
  #endif
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
    #ifdef ARC_ENABLED
    [newSourceText appendAttributedString:
       [[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:attributes]];
    [newSourceText appendAttributedString:oldSourceText];
    [newSourceText appendAttributedString:
       [[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:attributes]];
    [self setSourceText:newSourceText];
    #else
    [newSourceText appendAttributedString:
       [[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}\n" attributes:attributes] autorelease]];
    [newSourceText appendAttributedString:oldSourceText];
    [newSourceText appendAttributedString:
       [[[NSAttributedString alloc] initWithString:@"\n\\end{eqnarray*}" attributes:attributes] autorelease]];
    [self setSourceText:newSourceText];
    [newSourceText release];
    #endif
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
    #ifdef ARC_ENABLED
    #else
    [self->pdfCachedImage release];
    #endif
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

@dynamic pdfData;

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
    #ifndef ARC_ENABLED
    [self->pdfCachedImage release];
    #endif
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
        #ifndef ARC_ENABLED
        [equationData release];
        #endif
      }//end if (!equationData)
      [equationData setPdfData:value];
    }//end //if (!self->isModelPrior250)
  }//end if (value != [self pdfData])
  [self didChangeValueForKey:@"pdfCachedImage"];
}
//end setPdfData:

@dynamic preamble;

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
    NSError* decodingError = nil;
    result = !archivedData ? nil :
      isMacOS10_13OrAbove() ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NSAttributedString class] fromData:archivedData error:&decodingError] :
      [[NSKeyedUnarchiver unarchiveObjectWithData:archivedData] dynamicCastToClass:[NSAttributedString class]];
    if (decodingError != nil)
      DebugLog(0, @"decoding error : %@", decodingError);
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
  NSData* archivedData =
    isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:nil] :
    [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"preambleAsData"];
  [self setPrimitiveValue:archivedData forKey:@"preambleAsData"];
  [self didChangeValueForKey:@"preambleAsData"];
  [self endUpdate];
}
//end setPreamble:

@dynamic sourceText;

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
    NSError* decodingError = nil;
    result = !archivedData ? nil :
      isMacOS10_13OrAbove() ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NSAttributedString class] fromData:archivedData error:&decodingError] :
      [[NSKeyedUnarchiver unarchiveObjectWithData:archivedData] dynamicCastToClass:[NSAttributedString class]];
    if (decodingError != nil)
      DebugLog(0, @"decoding error : %@", decodingError);
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
  NSData* archivedData =
    isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:nil] :
    [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"sourceTextAsData"];
  [self setPrimitiveValue:archivedData forKey:@"sourceTextAsData"];
  [self didChangeValueForKey:@"sourceTextAsData"];
  [self endUpdate];
}
//end setSourceText:

@dynamic color;

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
    NSError* decodingError = nil;
    result = !archivedData ? nil :
      isMacOS10_13OrAbove() ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:archivedData error:&decodingError] :
      [[NSKeyedUnarchiver unarchiveObjectWithData:archivedData] dynamicCastToClass:[NSColor class]];
    if (decodingError != nil)
      DebugLog(0, @"decoding error : %@", decodingError);
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
  NSData* archivedData =
    isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:nil] :
    [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"colorAsData"];
  [self setPrimitiveValue:archivedData forKey:@"colorAsData"];
  [self didChangeValueForKey:@"colorAsData"];
  [self endUpdate];
}
//end setColor:

@dynamic baseline;

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

@dynamic pointSize;

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

@dynamic date;

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

@dynamic mode;

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
    NSError* decodingError = nil;
    result = !archivedData ? nil :
      isMacOS10_13OrAbove() ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:archivedData error:&decodingError] :
      [[NSKeyedUnarchiver unarchiveObjectWithData:archivedData] dynamicCastToClass:[NSColor class]];
    if (decodingError != nil)
      DebugLog(0, @"decoding error : %@", decodingError);
    [self setPrimitiveValue:result forKey:@"backgroundColor"];
  }//end if (!result)
  return result;
}
//end backgroundColor

-(void) setBackgroundColor:(NSColor*)value
{
  value = [value isConsideredWhite] ? nil : value;
  [self beginUpdate];
  self->annotateDataDirtyState |= objectDiffers(value, [self backgroundColor]);
  [self willChangeValueForKey:@"backgroundColor"];
  [self setPrimitiveValue:value forKey:@"backgroundColor"];
  [self didChangeValueForKey:@"backgroundColor"];
  NSData* archivedData = !value ? nil :
    isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:nil] :
    [NSKeyedArchiver archivedDataWithRootObject:value];
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
  NSString* oldTitle = [self title];
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
      NSArray* representations = [result representations];
      NSUInteger i = 0;
      NSUInteger count = [representations count];
      for(i = 0 ; !hasPdfOrBitmapImageRep && (i<count) ; ++i)
      {
        id representation = [representations objectAtIndex:i];
        hasPdfOrBitmapImageRep |=
          [representation isKindOfClass:[NSPDFImageRep class]] |
          [representation isKindOfClass:[NSBitmapImageRep class]];
      }//end for each representation
      if (!hasPdfOrBitmapImageRep)
      {
        #ifndef ARC_ENABLED
        [self->pdfCachedImage release];
        #endif
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
        [self->pdfCachedImage addRepresentation:pdfImageRep];
        if (![self->pdfCachedImage bitmapImageRepresentationWithMaxSize:NSMakeSize(0, 128)])//to help drawing in library
          [self->pdfCachedImage bitmapImageRepresentation];
        #ifdef ARC_ENABLED
        #else
        [pdfImageRep release];
        #endif
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
  #ifdef ARC_ENABLED
  NSMutableAttributedString* result = [[NSMutableAttributedString alloc] initWithAttributedString:[self sourceText]];
  #else
  NSMutableAttributedString* result = [[[NSMutableAttributedString alloc] initWithAttributedString:[self sourceText]] autorelease];
  #endif
  switch([self mode])
  {
    case LATEX_MODE_DISPLAY:
      #ifdef ARC_ENABLED
      [result insertAttributedString:[[NSAttributedString alloc] initWithString:@"\\["] atIndex:0];
      [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\\]"]];
      #else
      [result insertAttributedString:[[[NSAttributedString alloc] initWithString:@"\\["] autorelease] atIndex:0];
      [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\\]"] autorelease]];
      #endif
      break;
    case LATEX_MODE_INLINE:
      #ifdef ARC_ENABLED
      [result insertAttributedString:[[NSAttributedString alloc] initWithString:@"$"] atIndex:0];
      [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"$"]];
      #else
      [result insertAttributedString:[[[NSAttributedString alloc] initWithString:@"$"] autorelease] atIndex:0];
      [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"$"] autorelease]];
      #endif
      break;
    case LATEX_MODE_EQNARRAY:
      #ifdef ARC_ENABLED
      [result insertAttributedString:[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}"] atIndex:0];
      [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\\end{eqnarray*}"]];
      #else
      [result insertAttributedString:[[[NSAttributedString alloc] initWithString:@"\\begin{eqnarray*}"] autorelease] atIndex:0];
      [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\\end{eqnarray*}"] autorelease]];
      #endif
      break;
    case LATEX_MODE_ALIGN:
      #ifdef ARC_ENABLED
      [result insertAttributedString:[[NSAttributedString alloc] initWithString:@"\\begin{align*}"] atIndex:0];
      [result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\\end{align*}"]];
      #else
      [result insertAttributedString:[[[NSAttributedString alloc] initWithString:@"\\begin{align*}"] autorelease] atIndex:0];
      [result appendAttributedString:[[[NSAttributedString alloc] initWithString:@"\\end{align*}"] autorelease]];
      #endif
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
    [self setPdfData:newData];
  }//end if (![self isUpdating])
}
//end reannotatePDFDataUsingPDFKeywords:

-(NSData*) annotatedPDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords
{
  NSData* result = [self pdfData];
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

  #if !defined(CH_APP_EXTENSION) && !defined(CH_APP_XPC_SERVICE)
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
  #else
  #endif

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
                                 @([preferencesController exportJpegQualityPercent]), @"jpegQuality",
                                 @([preferencesController exportScalePercent]), @"scaleAsPercent",
                                 @([preferencesController exportIncludeBackgroundColor]), @"exportIncludeBackgroundColor",
                                 @([preferencesController exportTextExportPreamble]), @"textExportPreamble",
                                 @([preferencesController exportTextExportEnvironment]), @"textExportEnvironment",
                                 @([preferencesController exportTextExportBody]), @"textExportBody",
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
  NSString* extension = getFileExtensionForExportFormat(exportFormat);
  NSString* uti = getUTIForExportFormat(exportFormat);
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
      [pboard addTypes:[NSArray arrayWithObjects:NSPasteboardTypePDF, (NSString*)kUTTypePDF, nil] owner:lazyDataProvider];
      if (!lazyDataProvider)
      {
        [pboard setData:data forType:NSPasteboardTypePDF];
        [pboard setData:data forType:(NSString*)kUTTypePDF];
      }//end if (!lazyDataProvider)
      break;
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
      [pboard addTypes:[NSArray arrayWithObjects:NSPasteboardTypePDF, (NSString*)kUTTypePDF, nil]
                 owner:lazyDataProvider ? lazyDataProvider : self];
      if (data && (!lazyDataProvider || (lazyDataProvider != self)))
      {
        [pboard setData:data forType:NSPasteboardTypePDF];
        [pboard setData:data forType:(NSString*)kUTTypePDF];
      }//end if (data && (!lazyDataProvider || (lazyDataProvider != self)))
      break;
    case EXPORT_FORMAT_EPS:
      [pboard addTypes:[NSArray arrayWithObjects:NSPostScriptPboardType, @"com.adobe.encapsulated-postscript", nil] owner:lazyDataProvider];
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
      [pboard addTypes:[NSArray arrayWithObjects:NSPasteboardTypeTIFF, (NSString*)kUTTypeTIFF, nil] owner:lazyDataProvider];
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
        #ifdef ARC_ENABLED
        NSString* documentString = !data ? nil : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        #else
        NSString* documentString = !data ? nil : [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        #endif
        NSString* blockquoteString = [documentString stringByMatching:@"<blockquote(.*?)>.*</blockquote>" options:RKLMultiline|RKLDotAll|RKLCaseless inRange:documentString.range capture:0 error:0];
        //[pboard addTypes:[NSArray arrayWithObjects:NSPasteboardTypeHTML, kUTTypeHTML, nil] owner:lazyDataProvider];
        [pboard addTypes:[NSArray arrayWithObjects:NSPasteboardTypeString, kUTTypeText, nil] owner:lazyDataProvider];
        if (blockquoteString)
        {
          NSError* error = nil;
          NSString* mathString =
            [blockquoteString stringByReplacingOccurrencesOfRegex:@"<blockquote(.*?)style=(.*?)>(.*?)<math(.*?)>(.*?)</math>(.*)</blockquote>"
                                                       withString:@"<math$4 style=$2>$3$5</math>"
                                                          options:RKLMultiline|RKLDotAll|RKLCaseless range:blockquoteString.range error:&error];
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
      [pboard addTypes:[NSArray arrayWithObjects:GetMySVGPboardType(), @"public.svg-image", NSPasteboardTypeString, nil] owner:lazyDataProvider];
      if (!lazyDataProvider)
      {
        [pboard setData:data forType:GetMySVGPboardType()];
        [pboard setData:data forType:@"public.svg-image"];
        [pboard setData:data forType:NSPasteboardTypeString];
      }//end if (!lazyDataProvider)
      break;
    case EXPORT_FORMAT_TEXT:
      [pboard addTypes:[NSArray arrayWithObjects:NSPasteboardTypeString, (NSString*)kUTTypeText, nil] owner:lazyDataProvider];
      if (!lazyDataProvider)
      {
        [pboard setData:data forType:NSPasteboardTypeString];
        [pboard setData:data forType:(NSString*)kUTTypeText];
      }//end if (!lazyDataProvider)
      break;
    case EXPORT_FORMAT_RTFD:
      [pboard addTypes:[NSArray arrayWithObjects:NSPasteboardTypeRTFD, nil] owner:lazyDataProvider];
      if (!lazyDataProvider)
      {
        CGFloat newBaseline = 0;
        BOOL useBaseline = YES;
        if (useBaseline)
          newBaseline -= self.baseline;
          
        NSString* attachedFilePath = nil;
        NSFileHandle* fileHandle =
          [[NSFileManager defaultManager] temporaryFileWithTemplate:[NSString stringWithFormat:@"%@-XXXXXXXX", @"latexit-rtfd-attachement"]
                                                          extension:@"pdf"
                                                        outFilePath:&attachedFilePath workingDirectory:NSTemporaryDirectory()];
        NSURL* attachedFileURL = !attachedFilePath ? nil : [NSURL fileURLWithPath:attachedFilePath];
        NSData* attachedData = pdfData;
        [fileHandle writeData:attachedData];
        [fileHandle closeFile];
        NSFileWrapper* fileWrapperOfImage = !attachedFileURL ? nil :
          [[NSFileWrapper alloc] initWithURL:attachedFileURL options:0 error:nil];
        NSTextAttachment*   textAttachmentOfImage     = [[NSTextAttachment alloc] initWithFileWrapper:fileWrapperOfImage];
        NSAttributedString* attributedStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachmentOfImage];
        NSMutableAttributedString* mutableAttributedStringWithImage =
          [[NSMutableAttributedString alloc] initWithAttributedString:attributedStringWithImage];
            
        //changes the baseline of the attachment to align it with the surrounding text
        [mutableAttributedStringWithImage addAttribute:NSFontSizeAttribute
                                                 value:@(self.pointSize)
                                                 range:mutableAttributedStringWithImage.range];
        [mutableAttributedStringWithImage addAttribute:NSBaselineOffsetAttributeName
                                                 value:@(newBaseline)
                                                 range:mutableAttributedStringWithImage.range];
          
        //add a space after the image, to restore the baseline of the surrounding text
        //Gee! It works with TextEdit but not with Pages. That is to say, in Pages, if I put this space, the baseline of
        //the equation is reset. And if do not put this space, the cursor stays in "tuned baseline" mode.
        //However, it works with Nisus Writer Express, so that I think it is a bug in Pages
        unichar invisibleSpace = 0xFEFF;
        NSString* invisibleSpaceString = [[NSString alloc] initWithCharacters:&invisibleSpace length:1];
        NSMutableAttributedString* space = [[NSMutableAttributedString alloc] initWithString:invisibleSpaceString];
        //[space setAttributes:contextAttributes range:space.range];
        [space addAttribute:NSBaselineOffsetAttributeName value:@(newBaseline)
                      range:space.range];
        [mutableAttributedStringWithImage insertAttributedString:space atIndex:0];
        [mutableAttributedStringWithImage appendAttributedString:space];
        //inserts the image in the global string
        NSData* data = [mutableAttributedStringWithImage dataFromRange:mutableAttributedStringWithImage.range documentAttributes:@{NSDocumentTypeDocumentAttribute:NSRTFDTextDocumentType} error:nil];
        [pboard setData:data forType:NSPasteboardTypeRTFD];
        [[NSFileManager defaultManager] removeItemAtURL:attachedFileURL error:nil];
#ifndef ARC_ENABLED
        [fileWrapperOfImage release];
        [textAttachmentOfImage release];
        [mutableAttributedStringWithImage release];
        [invisibleSpaceString release];
        [space release];
#endif
      }//end if (!lazyDataProvider)
      break;
  }//end switch(exportFormat)
  
  BOOL fillFilenames = [[PreferencesController sharedController] exportAddTempFileCurrentSession];
  if (fillFilenames)
  {
    [pboard addTypes:[NSArray arrayWithObjects:NSFileContentsPboardType, NSFilenamesPboardType, (NSString*)kUTTypeURL, nil] owner:lazyDataProvider];
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
  
  NSString* extension = nil;
  NSString* uti = nil;
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
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
    case EXPORT_FORMAT_RTFD:
      extension = @"rtfd";
      uti = (NSString*)kUTTypeRTFD;
      break;
  }//end switch(exportFormat)
  
  if (exportFormat == EXPORT_FORMAT_MATHML)
  {
    #ifdef ARC_ENABLED
    NSString* documentString = !data ? nil : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    #else
    NSString* documentString = !data ? nil : [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    #endif
    NSString* blockquoteString = [documentString stringByMatching:@"<blockquote(.*?)>.*</blockquote>" options:RKLMultiline|RKLDotAll|RKLCaseless inRange:documentString.range capture:0 error:0];
    if (blockquoteString)
    {
      NSError* error = nil;
      NSString* mathString =
      [blockquoteString stringByReplacingOccurrencesOfRegex:@"<blockquote(.*?)style=(.*?)>(.*?)<math(.*?)>(.*?)</math>(.*)</blockquote>"
                                                 withString:@"<math$4 style=$2>$3$5</math>"
                                                    options:RKLMultiline|RKLDotAll|RKLCaseless range:blockquoteString.range error:&error];
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
    else if ([type isEqualToString:(NSString*)kUTTypeFileURL])
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
    }//end if ([type isEqualToString:(NSString*)kUTTypeFileURL])
    else if ([type isEqualToString:(NSString*)kUTTypeURL])
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
    }//end if ([type isEqualToString:(NSString*)kUTTypeURL])
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
       @([self pointSize]), @"pointSize",
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
  #ifdef ARC_ENABLED
  [self setPreamble:(!string ? nil : [[NSAttributedString alloc] initWithString:string])];
  #else
  [self setPreamble:(!string ? nil : [[[NSAttributedString alloc] initWithString:string] autorelease])];
  #endif
  string = [description objectForKey:@"sourceText"];
  #ifdef ARC_ENABLED
  [self setSourceText:(!string ? nil : [[NSAttributedString alloc] initWithString:string])];
  #else
  [self setSourceText:(!string ? nil : [[[NSAttributedString alloc] initWithString:string] autorelease])];
  #endif
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

-(NSString*) computeFileName
{
#ifdef ARC_ENABLED
  NSString* result = [[self title] copy];
  if (!result || [result isEqualToString:@""])
    result = [[self titleAuto] copy];
  if (!result || [result isEqualToString:@""])
    result = [[[self sourceText] string] copy];
  result = [[self class] computeFileNameFromContent:result];
  return result;
#else
  NSString* result = [[[self title] copy] autorelease];
  if (!result || [result isEqualToString:@""])
    result = [[[self titleAuto] copy] autorelease];
  if (!result || [result isEqualToString:@""])
    result = [[[[self sourceText] string] copy] autorelease];
  result = [[self class] computeFileNameFromContent:result];
  return result;
#endif
}
//end computeFileName

+(NSString*) computeFileNameFromContent:(NSString*)content
{
  NSString* result = nil;
  #ifdef ARC_ENABLED
  NSMutableString* mutableString = [content mutableCopy];
  #else
  NSMutableString* mutableString = [[content mutableCopy] autorelease];
  #endif
  NSUInteger oldLength = [mutableString length];
  BOOL stop = !oldLength;
  while(!stop)
  {
    [mutableString replaceOccurrencesOfRegex:@"\\\\begin\\{(.+)\\}(.*)\\\\end\\{\\1\\}" withString:@"$2" options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\\\" withString:@" " options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\{" withString:@" " options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\}" withString:@" " options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\[" withString:@" " options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\]" withString:@" " options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"\\:" withString:@" " options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"([[:space:]]+)" withString:@"_" options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"(_*)\\^(_*)" withString:@"\\^" options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"__" withString:@"_" options:RKLMultiline|RKLDotAll range:mutableString.range error:nil];
    [mutableString replaceOccurrencesOfRegex:@"^([_%]+)" withString:@""];
    [mutableString replaceOccurrencesOfRegex:@"(_+)$" withString:@""];
    [mutableString replaceOccurrencesOfRegex:@"\\/" withString:@"\xE2\x88\x95"];
    NSUInteger newLength = [mutableString length];
    stop |= !newLength || (newLength >= oldLength);
    oldLength = newLength;
  }//end while(!stop)
  result = [mutableString trim];
  result = [result substringWithRange:NSMakeRange(0, MIN([result length], 16U))];
  return result;
}
//end computeFileNameFromContent:

@end
