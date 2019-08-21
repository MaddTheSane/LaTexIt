//
//  LaTeXProcessor.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/09/08.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "LaTeXProcessor.h"

#import "AppController.h"
#import "Compressor.h"
#import "LatexitEquation.h"
#import "NSArrayExtended.h"
#import "NSColorExtended.h"
#import "NSDataExtended.h"
#import "NSDictionaryCompositionConfiguration.h"
#import "NSDictionaryExtended.h"
#import "NSFileManagerExtended.h"
#import "NSObjectExtended.h"
#import "NSStringExtended.h"
#import "NSTaskExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "SystemTask.h"
#import "TeXItemWrapper.h"
#import "Utils.h"

#import "RegexKitLite.h"

#import <Quartz/Quartz.h>
#import <libxml/parser.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

NSString* const LatexizationDidEndNotification = @"LatexizationDidEndNotification";

//In MacOS 10.4.0, 10.4.1 and 10.4.2, these constants are declared but not defined in the PDFKit.framework!
//So I define them myself, but it is ugly. I expect next versions of MacOS to fix that
//NSString* PDFDocumentCreatorAttribute = @"Creator";
//NSString* PDFDocumentKeywordsAttribute = @"Keywords";

static NSString* mathMLFix(NSString* value)
{
  NSString* result = value;
  if (value)
  {
    NSError* error = nil;
    NSArray* components = [value captureComponentsMatchedByRegex:@".*<math[^>]*xmlns=\"(.*?)\"" options:RKLDotAll|RKLCaseless range:[value range] error:&error];
    NSString* mmlXmlns = (components.count < 2) ? nil : [components[1] dynamicCastToClass:[NSString class]];
    if (error)
      DebugLogStatic(1, @"error = %@", error);
    const xmlChar* xmlTxt = BAD_CAST value.UTF8String;
    xmlDocPtr doc = xmlParseDoc(xmlTxt);
    xmlXPathInit();
    xmlXPathContextPtr ctxt = !doc ? 0 : xmlXPathNewContext(doc);
    xmlXPathObjectPtr xpathRes = 0;
    if (ctxt)
    {
      if (!mmlXmlns.length)
        xpathRes = !ctxt ? 0 : xmlXPathEvalExpression(BAD_CAST "//mtable/mrow", ctxt);
      else//if ([mmlXmlns length])
      {
        xmlXPathRegisterNs(ctxt, BAD_CAST "mml", BAD_CAST mmlXmlns.UTF8String);
        xpathRes = !ctxt ? 0 : xmlXPathEvalExpression(BAD_CAST "//mml:mtable/mml:mrow", ctxt);
      }//end if ([mmlXmlns length])
    }//end if (ctxt)
    if (xpathRes && (xpathRes->type == XPATH_NODESET))
    {
      NSInteger i = 0;
      for(i = 0 ; i< xpathRes->nodesetval->nodeNr ; ++i)
      {
        xmlNodePtr n = xpathRes->nodesetval->nodeTab[i];
        xmlNodeSetName(n, BAD_CAST "latexitDummyTableRow");
      }//end for each node
    }//end if (xpathRes && (xpathRes->type == XPATH_NODESET))
    xmlChar* mem = 0;
    int size = 0;
    if (doc)
      xmlDocDumpMemory(doc, &mem, &size);
    if (mem && size)
    {
      NSMutableString* modified = [[NSMutableString alloc] initWithBytes:mem length:size encoding:NSUTF8StringEncoding];
      [modified replaceOccurrencesOfRegex:@"<latexitDummyTableRow.*?>" withString:@"<mtr><mtd>" options:RKLDotAll|RKLMultiline|RKLCaseless range:[modified range] error:&error];
      if (error)
        DebugLogStatic(1, @"error = %@", error);
      [modified replaceOccurrencesOfRegex:@"</latexitDummyTableRow.*?>" withString:@"</mtd></mtr>" options:RKLDotAll|RKLMultiline|RKLCaseless range:[modified range] error:&error];
      if (error)
        DebugLogStatic(1, @"error = %@", error);
      result = [modified copy];
    }//end if (mem && size)
    if (mem)
      xmlFree(mem);
    if (xpathRes)
      xmlXPathFreeObject(xpathRes);
    if (ctxt)
      xmlXPathFreeContext(ctxt);
    if (doc)
      xmlFreeDoc(doc);
  }//end if (value)
  return result;
}
//end mathMLFix()

@interface LaTeXProcessor (PrivateAPI)
-(void) initializeEnvironment;
-(NSString*) getGSVersion:(NSDictionary*)compositionConfiguration;
@end

@implementation LaTeXProcessor

static LaTeXProcessor* sharedInstance = nil;

+(LaTeXProcessor*) sharedLaTeXProcessor
{
  if (!sharedInstance)
  {
    @synchronized(self)
    {
      if (!sharedInstance)
        sharedInstance = [[LaTeXProcessor alloc] init];
    }//end @synchronized(self)
  }//end if (!sharedInstance)
  return sharedInstance;
}
//end sharedLaTeXProcessor

-(instancetype) init
{
  if (!((self = [super init])))
    return nil;
  [self initializeEnvironment];
  return self;
}
//end init

-(void) initializeEnvironment
{
  if (!self->environmentsInitialized)
  {
    @synchronized(self)
    {
      if (!self->environmentsInitialized)
      {
        NSString* temporaryPathFileName = @"latexit-paths";
        NSString* temporaryPathFilePath = [[[NSWorkspace sharedWorkspace] temporaryDirectory] stringByAppendingPathComponent:temporaryPathFileName];
        NSString* systemCall = [NSString stringWithFormat:@". /etc/profile && /bin/echo \"$PATH\" >| %@",
                                temporaryPathFilePath];
        int error = system(systemCall.UTF8String);
        NSError* nserror = nil;
        NSStringEncoding encoding = NSUTF8StringEncoding;
        NSArray* profileBins =
          error ? @[] :
          [[[NSString stringWithContentsOfFile:temporaryPathFilePath guessEncoding:&encoding error:&nserror] trim] componentsSeparatedByString:@":"];
    
        self->unixBins = [[NSMutableArray alloc] initWithArray:profileBins];
  
        //usual unix PATH (to find latex)
        NSArray* usualBins = 
          @[@"/bin", @"/sbin",
            @"/usr/bin", @"/usr/sbin",
            @"/usr/local/bin", @"/usr/local/sbin",
            @"/usr/texbin", @"/usr/local/texbin", @"/Library/TeX/texbin",
            @"/sw/bin", @"/sw/sbin",
            @"/sw/usr/bin", @"/sw/usr/sbin",
            @"/sw/local/bin", @"/sw/local/sbin",
            @"/sw/usr/local/bin", @"/sw/usr/local/sbin",
            @"/opt/local/bin", @"/opt/local/sbin"];
        [self->unixBins addObjectsFromArray:usualBins];

        //add ~/.MacOSX/environment.plist
        NSMutableArray* macOSXEnvironmentPaths = [NSMutableArray array];
        NSString* filePath = [NSString pathWithComponents:@[NSHomeDirectory(), @".MacOSX", @"environment.plist"]];
        NSDictionary* propertyList = [NSDictionary dictionaryWithContentsOfFile:filePath];
        if (propertyList)
        {
          NSArray* components =
            [[[propertyList[@"PATH"] dynamicCastToClass:[NSString class]] trim] componentsSeparatedByString:@":"];
          if (components)
            [macOSXEnvironmentPaths setArray:components];
        }//end if (propertyList)

        //process environment
        NSMutableArray* processEnvironmentPaths = [NSMutableArray array];
        self->globalFullEnvironment  = [[NSProcessInfo processInfo].environment mutableCopy];
        NSString* pathEnv = [[self->globalFullEnvironment[@"PATH"] dynamicCastToClass:[NSString class]] trim];
        if (pathEnv)
        {
          NSArray* components = [pathEnv componentsSeparatedByString:@":"];
          if (components)
            [processEnvironmentPaths setArray:components];
        }//end if (pathEnv)

        NSMutableArray* allBins = [NSMutableArray arrayWithArray:self->unixBins];
        [allBins addObjectsFromArray:macOSXEnvironmentPaths];
        [allBins addObjectsFromArray:processEnvironmentPaths];
        NSMutableArray* allBinsUniqued = [NSMutableArray arrayWithCapacity:allBins.count];
        NSMutableSet* allBinsEncountered = [NSMutableSet setWithCapacity:allBins.count];
        NSEnumerator* enumerator = [allBins objectEnumerator];
        NSString* path = nil;
        while((path = [enumerator nextObject]))
        {
          if (![allBinsEncountered containsObject:path])
          {
            [allBinsUniqued addObject:path];
            [allBinsEncountered addObject:path];
          }//end if (![allBinsEncountered containsObject:path])
        }//end for each path

        
        self->globalEnvironmentPath  = [[allBinsUniqued componentsJoinedByString:@":"] mutableCopy];
        self->globalFullEnvironment[@"PATH"] = self->globalEnvironmentPath;
        self->globalExtraEnvironment = [[NSMutableDictionary alloc] init];
        self->globalExtraEnvironment[@"PATH"] = self->globalEnvironmentPath;

        self->environmentsInitialized = YES;
      }//end if (!self->environmentsInitialized)
    }//@synchronized(self)
  }//end if (!self->environmentsInitialized)
}
//end initializeEnvironment

-(NSManagedObjectModel*) managedObjectModel
{
  if (!self->managedObjectModel)
  {
    @synchronized(self)
    {
      if (!self->managedObjectModel)
      {
        //NSString* modelPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Latexit-2.4.0" ofType:@"mom"];
        NSString* modelPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Latexit" ofType:@"mom"];
        NSURL* modelURL = [NSURL fileURLWithPath:modelPath];
        self->managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
      }//end if (!self->managedObjectModel)
    }//end @synchronized(self)
  }//end if (!self->managedObjectModel)
  return self->managedObjectModel;
}
//end managedObjectModel

-(NSArray*)      unixBins         {return self->unixBins;}
-(NSString*)     environmentPath  {return self->globalEnvironmentPath;}
-(NSDictionary*) fullEnvironment  {return self->globalFullEnvironment;}
-(NSDictionary*) extraEnvironment {return self->globalExtraEnvironment;}

//increase environmentPath
-(void) addInEnvironmentPath:(NSString*)path
{
  NSMutableSet* componentsSet = [NSMutableSet setWithArray:[self->globalEnvironmentPath componentsSeparatedByString:@":"]];
  [componentsSet addObject:path];
  [componentsSet removeObject:@"."];
  [self->globalEnvironmentPath setString:[componentsSet.allObjects componentsJoinedByString:@":"]];
}
//end addInEnvironmentPath

-(NSData*) annotatePdfDataInLEEFormat:(NSData*)data0 exportFormat:(export_format_t)exportFormat
                             preamble:(NSString*)preamble source:(NSString*)source color:(NSColor*)color
                                 mode:(mode_t)mode magnification:(double)magnification baseline:(double)baseline
                                 backgroundColor:(NSColor*)backgroundColor title:(NSString*)title
                                 annotateWithTransparentData:(BOOL)annotateWithTransparentData
{
  NSData* newData = nil;
  
  NSData* data2 = [self stripPdfData:data0];
  
  preamble = !preamble ? @"" : preamble;
  source   = !source   ? @"" : source;

  BOOL embeddAsAnnotation = YES;
  if (embeddAsAnnotation)
  {
    PDFDocument* pdfDocument = nil;
    PDFAnnotation* pdfAnnotation = nil;
    @try{
      pdfDocument = [[PDFDocument alloc] initWithData:data2];
      PDFPage* pdfPage = [pdfDocument pageAtIndex:0];
      pdfAnnotation = !pdfPage ? nil : [[PDFAnnotationText alloc] initWithBounds:NSZeroRect];
      [pdfAnnotation setShouldDisplay:NO];
      [pdfAnnotation setShouldPrint:NO];
      NSData* embeddedData = !pdfAnnotation ? nil :
        [NSKeyedArchiver archivedDataWithRootObject:
          [NSDictionary dictionaryWithObjectsAndKeys:
            preamble, @"preamble",
            source, @"source",
            [(!color ? [NSColor blackColor] : color) colorAsData], @"color",
            [NSNumber numberWithInteger:mode], @"mode",
            [NSNumber numberWithDouble:magnification], @"magnification",
            [NSNumber numberWithDouble:baseline], @"baseline",
            [(!backgroundColor ? [NSColor whiteColor] : backgroundColor) colorAsData], @"backgroundColor",            
            title, @"title",
            nil]];
      NSString* embeddedDataBase64 = [embeddedData encodeBase64];
      pdfAnnotation.userName = @"fr.chachatelier.pierre.LaTeXiT";
      pdfAnnotation.contents = embeddedDataBase64;
      [pdfPage addAnnotation:pdfAnnotation];
      NSData* dataWithAnnotation = [pdfDocument dataRepresentation];
      data2 = !dataWithAnnotation ? data2 : dataWithAnnotation;
    }
    @catch(NSException* e){
      DebugLog(0, @"exception : %@", e);
    }
  }//end if (embeddAsAnnotation)

  NSString* colorAsString   = [(color ? color : [NSColor blackColor]) rgbaString];
  NSString* bkColorAsString = [(backgroundColor ? backgroundColor : [NSColor whiteColor]) rgbaString];
  if (data2)
  {
    NSMutableString* replacedPreamble = [NSMutableString stringWithString:preamble];
    [replacedPreamble replaceOccurrencesOfString:@"\\" withString:@"ESslash"      options:0 range:NSMakeRange(0, replacedPreamble.length)];
    [replacedPreamble replaceOccurrencesOfString:@"{"  withString:@"ESleftbrack"  options:0 range:NSMakeRange(0, replacedPreamble.length)];
    [replacedPreamble replaceOccurrencesOfString:@"}"  withString:@"ESrightbrack" options:0 range:NSMakeRange(0, replacedPreamble.length)];
    [replacedPreamble replaceOccurrencesOfString:@"$"  withString:@"ESdollar"     options:0 range:NSMakeRange(0, replacedPreamble.length)];

    NSMutableString* escapedPreamble = [[preamble stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]] mutableCopy];

    NSMutableString* replacedSource = [NSMutableString stringWithString:source];
    [replacedSource replaceOccurrencesOfString:@"\\" withString:@"ESslash"      options:0 range:NSMakeRange(0, replacedSource.length)];
    [replacedSource replaceOccurrencesOfString:@"{"  withString:@"ESleftbrack"  options:0 range:NSMakeRange(0, replacedSource.length)];
    [replacedSource replaceOccurrencesOfString:@"}"  withString:@"ESrightbrack" options:0 range:NSMakeRange(0, replacedSource.length)];
    [replacedSource replaceOccurrencesOfString:@"$"  withString:@"ESdollar"     options:0 range:NSMakeRange(0, replacedSource.length)];

    NSMutableString* escapedSource = [[source stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]] mutableCopy];

    NSString* type = (@(mode)).stringValue;
    
    BOOL annotateWithXML = YES;
    if (annotateWithXML)
    {
      DebugLog(1, @"annotateWithXML");
      NSString* annotationContent =
          [NSMutableString stringWithFormat:
            @"/Encoding /MacRomanEncoding\n"\
             "/Preamble (ESannop%sESannopend)\n"\
             "/EscapedPreamble (ESannoep%sESannoepend)\n"\
             "/Subject (ESannot%sESannotend)\n"\
             "/EscapedSubject (ESannoes%sESannoesend)\n"\
             "/Type (EEtype%@EEtypeend)\n"\
             "/Color (EEcol%@EEcolend)\n"\
             "/BKColor (EEbkc%@EEbkcend)\n"\
             "/Title (EEtitle%@EEtitleend)\n"\
             "/Magnification (EEmag%fEEmagend)\n"\
             "/Baseline (EEbas%fEEbasend)\n",
            [replacedPreamble cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
            [escapedPreamble  cStringUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES],
            [replacedSource  cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
            [escapedSource   cStringUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES],
            type, colorAsString, bkColorAsString, (title ? title : @""), magnification, baseline];
      NSString* annotationContentBase64 = 
        [NSString stringWithFormat:
           @"<![CDATA[%@]]>",
           [[annotationContent dataUsingEncoding:NSUTF8StringEncoding] encodeBase64]];
      NSMutableString *annotation =
          [NSMutableString stringWithFormat:
            @"\nobj\n<<\n/Type /Metadata\n"\
             "/SubType /XML\n"\
             "/Length %@\n"\
             ">>\n"\
             "stream\n"\
             "%@\n"\
             "endstream\n"\
             "endobj\n",
             @(annotationContentBase64.length),
             annotationContentBase64];
      NSMutableString* pdfString = [[NSMutableString alloc] initWithData:data2 encoding:NSASCIIStringEncoding];
      
      NSRange r1 = [pdfString rangeOfString:@"\nxref" options:NSBackwardsSearch];
      NSRange r2 = [pdfString rangeOfString:@"startxref" options:NSBackwardsSearch];
      r2 = (r2.location == NSNotFound) ? r2 : [pdfString lineRangeForRange:r2];

      NSString* tail_of_tail = (r2.location == NSNotFound) ? @"" : [pdfString substringFromIndex:r2.location];
      NSArray*  tailarray    = [tail_of_tail componentsSeparatedByString:@"\n"];

      int byte_count = 0;
      NSScanner* scanner = (tailarray.count<2) ? nil : [NSScanner scannerWithString:tailarray[1]];
      [scanner scanInt:&byte_count];
      if (r1.location != NSNotFound)
        byte_count += annotation.length;

      NSRange r3 = (r2.location == NSNotFound) ? r2 : NSMakeRange(r1.location, r2.location - r1.location);
      NSString* stuff = (r3.location == NSNotFound) ? @"" : [pdfString substringWithRange:r3];

      [annotation appendString:stuff];
      [annotation appendString:[NSString stringWithFormat: @"startxref\n%d\n%%%%EOF", byte_count]];
      
      NSData* dataToAppend = [annotation dataUsingEncoding:NSMacOSRomanStringEncoding/*NSASCIIStringEncoding*/ allowLossyConversion:YES];

      newData = [NSMutableData dataWithData:[data2 subdataWithRange:
        (r1.location != NSNotFound) ? NSMakeRange(0, r1.location) :
        (r2.location != NSNotFound) ? NSMakeRange(0, r2.location) :
        NSMakeRange(0, 0)]];
      [(NSMutableData*)newData appendData:dataToAppend];
      data2 = newData;
    }//end if (annotateWithXML)

    NSRange r0 = NSMakeRange(0, data2.length);
    NSRange r1 = [data2 rangeOfData:[@"\nxref" dataUsingEncoding:NSUTF8StringEncoding] options:NSDataSearchBackwards range:r0];
    NSRange r2 = [data2 rangeOfData:[@"trailer" dataUsingEncoding:NSUTF8StringEncoding] options:NSDataSearchBackwards range:r0];
    NSRange r3 = [data2 rangeOfData:[@"startxref" dataUsingEncoding:NSUTF8StringEncoding] options:NSDataSearchBackwards range:r0];
    if (r0.location != NSNotFound)
    {
      if (r1.location != NSNotFound)
        r0.length = r1.location-r0.location;
      else if (r2.location != NSNotFound)
        r0.length = r2.location-r0.location;
      else if (r3.location != NSNotFound)
        r0.length = r3.location-r0.location;
      else
        r0.length = data2.length;
    }//end if (r1.location != NSNotFound)
    if (r1.location != NSNotFound)
    {
      r1 = NSMakeRange(r1.location+1, r1.length-1);//remove "\n"
      if (r2.location != NSNotFound)
        r1.length = r2.location-r1.location;
      else if (r3.location != NSNotFound)
        r1.length = r3.location-r1.location;
    }//end if (r1.location != NSNotFound)
    if (r2.location != NSNotFound)
    {
      if (r3.location != NSNotFound)
        r2.length = r3.location-r2.location;
    }//end if (r2.location != NSNotFound)
    if (r3.location != NSNotFound)
      r3.length = data2.length-r3.location;

    NSData* xrefData = (r1.location == NSNotFound) ? nil : [data2 subdataWithRange:r1];
    NSString* xrefString = [[NSString alloc] initWithData:xrefData encoding:NSASCIIStringEncoding];
    NSString* afterObjCountString = [xrefString stringByMatching:@"xref\\s*[0-9]+\\s+[0-9]+\\s+(.*)" options:RKLDotAll inRange:NSMakeRange(0, xrefString.length) capture:1 error:0];

    NSData* trailerData = (r2.location == NSNotFound) ? nil : [data2 subdataWithRange:r2];
    NSString* trailerString = [[NSString alloc] initWithData:trailerData encoding:NSASCIIStringEncoding];
    NSString* trailerAfterSize = [trailerString stringByMatching:@"trailer\\s+<<\\s+/Size\\s+[0-9]+(.*)" options:RKLDotAll inRange:NSMakeRange(0, trailerString.length) capture:1 error:0];
    
    NSUInteger nbObjects = 0;
    if ((r1.location != NSNotFound) && (r2.location != NSNotFound))
    {
      const unsigned char* bytes = (const unsigned char*)data2.bytes;
      NSString* s = [[NSString alloc] initWithBytesNoCopy:(unsigned char*)bytes+r1.location length:r2.location-r1.location encoding:NSUTF8StringEncoding freeWhenDone:NO];
      NSArray* components = [s componentsMatchedByRegex:@"^[0-9]+\\s+[0-9]+\\s[^0-9]+$" options:RKLMultiline range:NSMakeRange(0, s.length) capture:0 error:0];
      nbObjects = components.count;
    }//end if ((r1.location != NSNotFound) && (r2.location != NSNotFound))
    NSUInteger annotationObjectIndex = !nbObjects ? 100000 : nbObjects;
    BOOL useAnnotationObjectIndex = YES;
    NSMutableString *annotation =
      [NSMutableString stringWithFormat:
       @"\n%@obj\n<<\n/Encoding /MacRomanEncoding\n"
       "/Preamble (ESannop%sESannopend)\n"
       "/EscapedPreamble (ESannoep%sESannoepend)\n"
       "/Subject (ESannot%sESannotend)\n"
       "/EscapedSubject (ESannoes%sESannoesend)\n"
       "/Type (EEtype%@EEtypeend)\n"
       "/Color (EEcol%@EEcolend)\n"
       "/BKColor (EEbkc%@EEbkcend)\n"
       "/Title (EEtitle%@EEtitleend)\n"
       "/Magnification (EEmag%fEEmagend)\n"
       "/Baseline (EEbas%fEEbasend)\n"
       ">>\nendobj\n",
       !useAnnotationObjectIndex ? @"" : [NSString stringWithFormat:@"%lu 0 ", (unsigned long)annotationObjectIndex],
       [replacedPreamble cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
       [escapedPreamble  cStringUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES],
       [replacedSource  cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
       [escapedSource   cStringUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES],
       type, colorAsString, bkColorAsString, (title ? title : @""), magnification, baseline];
    
    NSData* startxrefData = (r3.location == NSNotFound) ? nil : [data2 subdataWithRange:r3];
    NSString* startxrefString = [[NSString alloc] initWithData:startxrefData encoding:NSASCIIStringEncoding];
    NSString* byteCountString = [startxrefString stringByMatching:@"[^0-9]*([0-9]*).*" options:RKLDotAll inRange:NSMakeRange(0, startxrefString.length) capture:1 error:0];
    NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.formatterBehavior = NSNumberFormatterBehaviorDefault;
    numberFormatter.minimum = @0U;
    numberFormatter.maximum = @((unsigned int)(-1));
    NSNumber* number = !byteCountString ? nil : [numberFormatter numberFromString:byteCountString];
    NSUInteger byte_count = number.unsignedIntegerValue;

    BOOL annotateWithPDF = YES;
    if (!annotateWithPDF)
      newData = data0;
    else//if (annotateWithPDF)
    {
      NSMutableData* buildData = [NSMutableData data];
      if (r0.location != NSNotFound)
        [buildData appendData:[data2 subdataWithRange:r0]];
      if (annotation)
        [buildData appendData:[annotation dataUsingEncoding:NSMacOSRomanStringEncoding]];
      if (r1.location != NSNotFound)
      {
        [buildData appendData:[[NSString stringWithFormat:@"xref\n%u %lu\n", 0, (unsigned long)annotationObjectIndex+1] dataUsingEncoding:NSUTF8StringEncoding]];
        [buildData appendData:[afterObjCountString dataUsingEncoding:NSUTF8StringEncoding]];
        [buildData appendData:[[NSString stringWithFormat:@"%010lu %05lu n \n", (unsigned long)r1.location, 0UL] dataUsingEncoding:NSUTF8StringEncoding]];
      }//end if (r1.location != NSNotFound)
      if (r2.location != NSNotFound)
      {
        [buildData appendData:[[NSString stringWithFormat:@"trailer\n<< /Size %lu",
                                (unsigned long)annotationObjectIndex+(useAnnotationObjectIndex ? 1 : 0)] dataUsingEncoding:NSUTF8StringEncoding]];
        [buildData appendData:[trailerAfterSize dataUsingEncoding:NSUTF8StringEncoding]];
      }//end if (r2.location != NSNotFound)
      if (r3.location != NSNotFound)
      {
        NSUInteger newByteCount = byte_count;
        if (r1.location != NSNotFound)
          newByteCount += [annotation length]-1;
        [buildData appendData:[[NSString stringWithFormat:@"startxref\n%llu\n%%%%EOF", (unsigned long long)newByteCount] dataUsingEncoding:NSUTF8StringEncoding]];
      }//end if (r3.location != NSNotFound)
      newData = buildData;
    }//end if (annotateWithPDF)
    
    if (annotateWithTransparentData)
    {
      NSString* applicationVersion = [[NSWorkspace sharedWorkspace] applicationVersion];
      NSDictionary* dictionaryContent = [NSDictionary dictionaryWithObjectsAndKeys:
        applicationVersion, @"version",
        !preamble ? @"" : preamble, @"preamble",
        !source ? @"" : source, @"source",
        type, @"type",
        colorAsString, @"color",
        bkColorAsString, @"bkColor",
        !title ? @"" : title, @"title",
        [NSNumber numberWithDouble:magnification], @"magnification",
        [NSNumber numberWithDouble:baseline], @"baseline",
        nil];
      NSData* dictionaryContentPlistData =
      [NSPropertyListSerialization dataWithPropertyList:dictionaryContent format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
      NSData* annotationContentRawData = dictionaryContentPlistData;
      NSData* annotationContentCompressedData = [Compressor zipcompress:annotationContentRawData];
      NSString* annotationContentBase64 = [annotationContentCompressedData encodeBase64WithNewlines:NO];
      NSString* annotationContentBase64CompleteString =
        [NSString stringWithFormat:@"<latexit sha1_base64=\"%@\">%@</latexit>",
          [[annotationContentBase64 dataUsingEncoding:NSUTF8StringEncoding] sha1Base64],
          annotationContentBase64];
      NSMutableData* dataConsumerData = [NSMutableData data];
      CGDataConsumerRef dataConsumer = !dataConsumerData ? 0 :
        CGDataConsumerCreateWithCFData((CFMutableDataRef)dataConsumerData);
      CGDataProviderRef dataProvider = !newData ? 0 :
        CGDataProviderCreateWithCFData((CFDataRef)newData);
      DebugLog(1, @"original pdf data :%lu bytes", (unsigned long)[newData length]);
      CGPDFDocumentRef pdfDocument = !dataProvider ? 0 :
        CGPDFDocumentCreateWithProvider(dataProvider);
      CGPDFPageRef pdfPage = !pdfDocument || !CGPDFDocumentGetNumberOfPages(pdfDocument) ? 0 :
        CGPDFDocumentGetPage(pdfDocument, 1);
      CGRect mediaBox = !pdfPage ? CGRectZero :
        CGPDFPageGetBoxRect(pdfPage, kCGPDFMediaBox);
      CGContextRef cgPDFContext = !dataConsumer || !pdfPage ? 0 :
        CGPDFContextCreate(dataConsumer, &mediaBox, 0);
      BOOL dataRewritten = NO;
      if (cgPDFContext && pdfPage)
      {
        CFMutableDictionaryRef pageDictionary = CFDictionaryCreateMutable(0, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        CFDataRef boxData = CFDataCreate(0, (const UInt8*)&mediaBox, sizeof(CGRect)/sizeof(const UInt8));
        if (pageDictionary && boxData)
          CFDictionarySetValue(pageDictionary, kCGPDFContextMediaBox, boxData);
        CGPDFContextBeginPage(cgPDFContext, pageDictionary);
        BOOL debugVisibleAnnotations = NO;
        BOOL debugLargeAnnotations = NO;
        CGContextSetRGBStrokeColor(cgPDFContext, debugVisibleAnnotations ? 1. : 0., 0, 0, debugVisibleAnnotations ? 1. : 0.);
        CGContextSetRGBFillColor(cgPDFContext, debugVisibleAnnotations ? 1. : 0., 0, 0, debugVisibleAnnotations ? 1. : 0.);
        CGContextSetTextDrawingMode(cgPDFContext, debugVisibleAnnotations ? kCGTextFill : kCGTextInvisible);
        CGContextDrawPDFPage(cgPDFContext, pdfPage);
        //CGContextFlush(cgPDFContext);
        BOOL useFullyGraphicMetadata = (exportFormat == EXPORT_FORMAT_EPS) || (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS);
        DebugLog(1, @"useFullyGraphicMetadata = %d", (int)useFullyGraphicMetadata);
        if (useFullyGraphicMetadata)
        {
          const unsigned char* annotationBytes = (const unsigned char*)[annotationContentBase64CompleteString UTF8String];
          size_t annotationBytesLength = [annotationContentBase64CompleteString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
          CGFloat tmp[6] = {0};
          const unsigned char* src = annotationBytes;
          size_t remainingBytes = annotationBytesLength;
          CGContextSaveGState(cgPDFContext);
          CGMutablePathRef path = CGPathCreateMutable();
          CGPathMoveToPoint(path, 0, 0, 0);
          while(remainingBytes)
          {
            int i = 0 ;
            for(i = 0 ; i<6 ; ++i)
            {
              tmp[i] = 0;
              if (remainingBytes)
              {
                tmp[i] = (float)(*src++);
                --remainingBytes;
              }//end if (remainingBytes)
            }//end for each i
            CGPathAddCurveToPoint(path, 0, tmp[0], tmp[1], tmp[2], tmp[3], tmp[4], tmp[5]);
          }//end while(remainingBytes)
          CGPathCloseSubpath(path);
          CGContextConcatCTM(cgPDFContext, CGAffineTransformMakeTranslation(mediaBox.origin.x+mediaBox.size.width/2, mediaBox.origin.y+mediaBox.size.height/2));
          CGContextConcatCTM(cgPDFContext, CGAffineTransformMakeScale(1e-6, 1e-6));
          CGContextAddPath(cgPDFContext, path);
          CGContextSetRGBStrokeColor(cgPDFContext, 0, 0, 0, 0);
          CGContextStrokePath(cgPDFContext);
          CGPathRelease(path);
          CGContextRestoreGState(cgPDFContext);
        }//end if (useFullyGraphicMetadata)
        else//if (!useFullyGraphicMetadata)
        {
          CGFloat fontSize = debugLargeAnnotations ? 10 : 1e-6;
          CGContextSetTextPosition(cgPDFContext, mediaBox.origin.x, mediaBox.origin.y);
          DebugLog(1, @"mediaBox = %@", NSStringFromRect(NSRectFromCGRect(mediaBox)));
          NSFont* font = [NSFont fontWithName:@"Courier" size:fontSize];
          CGFontRef cgFont = CGFontCreateWithFontName(CFSTR("Courier"));
          BOOL useOldFonts = NO;
          if (useOldFonts)
            CGContextSelectFont(cgPDFContext, "Courier", fontSize, kCGEncodingMacRoman);
          else//if (!useOldFonts)
          {
            CGContextSetFont(cgPDFContext, cgFont);
            CGContextSetFontSize(cgPDFContext, fontSize);
          }//end if (!useOldFonts)

          size_t charactersCount = [annotationContentBase64CompleteString length];
          unichar* unichars = (unichar*)calloc(charactersCount, sizeof(unichar));
          CGGlyph* glyphs = (CGGlyph*)calloc(charactersCount, sizeof(CGGlyph));
          if (unichars && glyphs)
          {
            [annotationContentBase64CompleteString getCharacters:unichars];
            bool ok = CTFontGetGlyphsForCharacters((CTFontRef)font, unichars, glyphs, charactersCount);
            DebugLog(1, @"ok = %d", ok);
            if (ok)
            {
              if (useOldFonts)
              {
                NSData* annotationContentBase64CompleteUTF8 = [annotationContentBase64CompleteString dataUsingEncoding:NSUTF8StringEncoding];
                DebugLog(1, @"annotationContentBase64CompleteUTF8 = %@", annotationContentBase64CompleteUTF8);
                CGContextShowTextAtPoint(cgPDFContext, mediaBox.origin.x, mediaBox.origin.y, [annotationContentBase64CompleteUTF8 bytes], [annotationContentBase64CompleteUTF8 length]);
              }//end if (useOldFonts)
              else//if (!useOldFonts)
              {
                DebugLog(1, @"Show %lu glyphs", (unsigned long)charactersCount);
                CGContextShowGlyphsAtPoint(cgPDFContext, mediaBox.origin.x, mediaBox.origin.y, glyphs, charactersCount);
              }//end if (!useOldFonts)
            }//end if (ok)
          }//end if (unichars && glyphs)
          if (unichars)
            free(unichars);
          if (glyphs)
            free(glyphs);
          CGFontRelease(cgFont);
        }//end if (!useFullyGraphicMetadata)
        CGPDFContextEndPage(cgPDFContext);
        if (boxData)
          CFRelease(boxData);
        if (pageDictionary)
          CFRelease(pageDictionary);
        CGContextFlush(cgPDFContext);
        CGContextRelease(cgPDFContext);
        dataRewritten = YES;
      }//end if (cgPDFContext && pdfPage)
      CGPDFDocumentRelease(pdfDocument);
      CGDataProviderRelease(dataProvider);
      CGDataConsumerRelease(dataConsumer);
      if (dataRewritten)
        newData = dataConsumerData;
    }//end if (annotateWithTransparentData)
  }//end if (data2)
  
  return newData;
}
//end annotatePdfDataInLEEFormat:preamble:source:color:mode:magnification:baseline:backgroundColor:title:

//modifies the \usepackage{color} line of the preamble to use the given color
-(NSString*) insertColorInPreamble:(NSString*)thePreamble color:(NSColor*)theColor isColorStyAvailable:(BOOL)isColorStyAvailable
{
  NSColor* color = theColor ? theColor : [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:0];
  color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  CGFloat rgba[4] = {0};
  [color getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
  NSString* colorString = [color isRGBEqualTo:[NSColor blackColor]] ? @"" :
    [NSString stringWithFormat:@"\\color[rgb]{%1.3f,%1.3f,%1.3f}", rgba[0], rgba[1], rgba[2]];
  NSMutableString* preamble = [NSMutableString stringWithString:thePreamble];
  
  NSString* token = @"%__TEXTCOLOR__";
  [preamble replaceOccurrencesOfString:token withString:colorString options:0 range:NSMakeRange(0, preamble.length)];
  
  NSRange colorRange = [preamble rangeOfString:@"{color}"];
  BOOL xcolor = NO;
  if (colorRange.location == NSNotFound)
    colorRange = [preamble rangeOfString:@"[pdftex]{color}"]; //because of old versions of LaTeXiT
  if (colorRange.location == NSNotFound)
  {
    colorRange = [preamble rangeOfString:@"{xcolor}"]; //if the user prefers xcolor
    xcolor = (colorRange.location != NSNotFound);
  }
  if (isColorStyAvailable)
  {
    if (colorRange.location != NSNotFound)
    {
      //int insertionPoint = pdftexColorRange.location+pdftexColorRange.length;
      //[preamble insertString:colorString atIndex:insertionPoint];
      colorString = xcolor ? [NSString stringWithFormat:@"{xcolor}%@", colorString] : [NSString stringWithFormat:@"{color}%@", colorString];
      if (colorString)
        [preamble replaceCharactersInRange:colorRange withString:colorString];
    }
    else //try to find a good place of insertion.
    {
      colorString = [NSString stringWithFormat:@"\\usepackage{color}%@", colorString];
      NSRange firstUsePackage = [preamble rangeOfString:@"\\usepackage"];
      if (firstUsePackage.location != NSNotFound)
        [preamble insertString:colorString atIndex:firstUsePackage.location];
      else
        [preamble appendString:colorString];
    }
  }//end insert color
  return preamble;
}
//end insertColorInPreamble:color:isColorStyAvailable:

-(void) latexiseTeXItems:(NSArray*)teXItems backgroundly:(BOOL)backgroundly delegate:(id)delegate itemDidEndSelector:(SEL)itemDidEndSelector groupDidEndSelector:(SEL)groupDidEndSelector
{
  id object = nil;
  id appControllerClass = NSClassFromString(@"AppController");
  id appController = [appControllerClass valueForKey:@"appController"];
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSEnumerator* enumerator = [teXItems objectEnumerator];
  while((object = [enumerator nextObject]))
  {
    TeXItemWrapper* teXItem = [object dynamicCastToClass:[TeXItemWrapper class]];
    if (![teXItem equation])
    {
      NSDictionary* data = [teXItem data];
      NSString* preamble = [data[@"preamble"] dynamicCastToClass:[NSString class]];
      NSString* sourceText = [data[@"sourceText"] dynamicCastToClass:[NSString class]];
      NSNumber* latexMode = [data[@"mode"] dynamicCastToClass:[NSNumber class]]; 
      NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
      NSDictionary* fullEnvironment = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];
      CGFloat leftMargin   = [[[appController valueForKey:@"marginsCurrentLeftMargin"] dynamicCastToClass:[NSNumber class]] doubleValue];
      CGFloat rightMargin  = [[[appController valueForKey:@"marginsCurrentRightMargin"] dynamicCastToClass:[NSNumber class]] doubleValue];
      CGFloat bottomMargin = [[[appController valueForKey:@"marginsCurrentBottomMargin"] dynamicCastToClass:[NSNumber class]] doubleValue];
      CGFloat topMargin    = [[[appController valueForKey:@"marginsCurrentTopMargin"] dynamicCastToClass:[NSNumber class]] doubleValue];
      NSMutableDictionary* configuration = !preamble || !sourceText ? nil :
      [[NSMutableDictionary alloc] initWithObjectsAndKeys:
        @(backgroundly), @"runInBackgroundThread",
        preamble, @"preamble",
        sourceText, @"body",
        [preferencesController latexisationFontColor], @"color",
        !latexMode ? [NSNumber numberWithInteger:LATEX_MODE_AUTO] : latexMode, @"mode",
        @([preferencesController latexisationFontSize]), @"magnification",
        [preferencesController compositionConfigurationDocument], @"compositionConfiguration",
        [NSNull null], @"backgroundColor",
        [NSNull null], @"title",
        @(leftMargin), @"leftMargin",
        @(rightMargin), @"rightMargin",
        @(topMargin), @"topMargin",
        @(bottomMargin), @"bottomMargin",
        [appController valueForKey:@"additionalFilesPaths"], @"additionalFilesPaths",
        !workingDirectory ? @"" : workingDirectory, @"workingDirectory",
        !fullEnvironment ? @{} : fullEnvironment, @"fullEnvironment",
        [NSString stringWithFormat:@"latexit-import-lib-from-text-%p", teXItem], @"uniqueIdentifier",
        @"", @"outFullLog",
        @[], @"outErrors",
        [NSData data], @"outPdfData",
        @NO, @"applyToPasteboard",
        teXItem, @"context",
        nil];
      if (configuration)
      {
        teXItem.importState = 1;
        [[LaTeXProcessor sharedLaTeXProcessor] latexiseWithConfiguration:configuration];
        if (delegate && itemDidEndSelector && [delegate respondsToSelector:itemDidEndSelector])
          [delegate performSelector:itemDidEndSelector withObject:configuration];
      }//end if (configuration)
    }//end if (![teXItem equation])
  }//end for each (teXItem)
  if (delegate && groupDidEndSelector && [delegate respondsToSelector:groupDidEndSelector])
    [delegate performSelector:groupDidEndSelector withObject:self];
}
//end latexiseTeXItems:backgroundly:delegate:itemDidEndSelector:groupDidEndSelector:

-(void) latexiseWithConfiguration:(NSMutableDictionary*)configuration
{
  BOOL runInBackgroundThread = [configuration[@"runInBackgroundThread"] boolValue];
  if (runInBackgroundThread)
  {
    configuration[@"runInBackgroundThread"] = @NO;
    [NSApplication detachDrawingThread:@selector(latexiseWithConfiguration:) toTarget:self withObject:configuration];
  }//end if (runInBackgroundThread)
  else//if (!runInBackgroundThread)
  {
    NSMutableDictionary* configuration2 = [configuration deepMutableCopy];//will protect from preferences changes
    NSString* fullLog = [configuration2 objectForKey:@"outFullLog"];
    NSArray*  errors  = [configuration2 objectForKey:@"outErrors"];
    NSData*   pdfData = [configuration2 objectForKey:@"outPdfData"];
    id backgroundColor = [configuration2 objectForKey:@"backgroundColor"];
    id title = [configuration2 objectForKey:@"title"];
    NSString* result = [self latexiseWithPreamble:[configuration2 objectForKey:@"preamble"]
                          body:[configuration objectForKey:@"body"] color:[configuration2 objectForKey:@"color"]
                          mode:(latex_mode_t)[[configuration2 objectForKey:@"mode"] integerValue]
                          magnification:[[configuration2 objectForKey:@"magnification"] doubleValue]
                          compositionConfiguration:[configuration2 objectForKey:@"compositionConfiguration"]
                          backgroundColor:(backgroundColor == [NSNull null]) ? nil : backgroundColor
                          title:(title == [NSNull null]) ? nil : title
                          leftMargin:[[configuration2 objectForKey:@"leftMargin"] doubleValue]
                         rightMargin:[[configuration2 objectForKey:@"rightMargin"] doubleValue]
                           topMargin:[[configuration2 objectForKey:@"topMargin"] doubleValue]
                        bottomMargin:[[configuration2 objectForKey:@"bottomMargin"] doubleValue]
                additionalFilesPaths:[configuration2 objectForKey:@"additionalFilesPaths"]
                    workingDirectory:[configuration2 objectForKey:@"workingDirectory"]
                     fullEnvironment:[configuration2 objectForKey:@"fullEnvironment"]
                    uniqueIdentifier:[configuration2 objectForKey:@"uniqueIdentifier"]
                    outFullLog:&fullLog outErrors:&errors outPdfData:&pdfData];
    if (fullLog) configuration2[@"outFullLog"] = fullLog;
    if (errors)  configuration2[@"outErrors"] = errors;
    if (pdfData) configuration2[@"outPdfData"] = pdfData;
    if (result)  configuration2[@"result"] = result;
    [configuration setDictionary:configuration2];
    [[NSNotificationCenter defaultCenter] postNotificationName:LatexizationDidEndNotification object:configuration];
  }//end if (!runInBackgroundThread)
}
//end latexiseWithConfiguration:

//latexise and returns the pdf result, cropped, magnified, coloured, with pdf meta-data
-(NSString*) latexiseWithPreamble:(NSString*)preamble body:(NSString*)body color:(NSColor*)color mode:(latex_mode_t)latexMode 
                    magnification:(double)magnification compositionConfiguration:(NSDictionary*)compositionConfiguration
                    backgroundColor:(NSColor*)backgroundColor
                    title:(NSString*)title
                    leftMargin:(CGFloat)leftMargin rightMargin:(CGFloat)rightMargin
                    topMargin:(CGFloat)topMargin bottomMargin:(CGFloat)bottomMargin
                    additionalFilesPaths:(NSArray*)additionalFilesPaths
                    workingDirectory:(NSString*)workingDirectory fullEnvironment:(NSDictionary*)fullEnvironment
                    uniqueIdentifier:(NSString*)uniqueIdentifier
                    outFullLog:(NSString**)outFullLog outErrors:(NSArray<NSString*>**)outErrors outPdfData:(NSData**)outPdfData
{
  NSData* pdfData = nil;
  
  preamble = [preamble stringWithFilteredStringForLatex];
  body     = [body stringWithFilteredStringForLatex];

  //this function is rather long, because it is not quite easy to get a tight image (well cropped)
  //and magnification.
  //The principle used is the following one :
  //  -first, we compute a very simple latex file, without cropping or magnification. If there are no syntax errors
  //   from the user, it will be ok. Otherwise, it will be useful to report errors to the user.
  //  -second, we must crop and magnify. There is a very fast an efficient method, using boxes that will automagically
  //   know their size, and even compute the *baseline* (what is the baseline ? it is the line on which your equation should be
  //   aligned to fit well inside some text. For instance, a fraction would be shifted down, thanks to a negative baseline)
  //   The problem is that, this fast and efficient method may fail with certain kinds of equations (especially multi-lines)
  //   So it is just a try; if it works, that's great, we keep the result. Otherwise, we will use a heavy but more robust method
  //  -third; in case that the second step failed, there is as a last resort a heavy and robust method to compute a bounding box
  //   (to crop), and magnify the document. We compute the bounding box by calling gs (GhostScript) on the result of the first step.
  //   Then, we use the latex template of the second step, with the magical boxes, but its body will just be the pdf image generated
  //   during the first step ! So it can be cropped and magnify.
  //
  //All these steps need many intermediate files, so don't be surprised if you feel a little lost

  //prepare file names
  NSString* filePrefix     = uniqueIdentifier; //file name, related to the current document

  //latex files for step 1 (simple latex file useful to report errors, log file and pdf result)
  NSString* latexFile             = [NSString stringWithFormat:@"%@.tex", filePrefix];
  NSString* latexFilePath         = [workingDirectory stringByAppendingPathComponent:latexFile];
  NSString* latexAuxFile          = [NSString stringWithFormat:@"%@.aux", filePrefix];
  NSString* latexAuxFilePath      = [workingDirectory stringByAppendingPathComponent:latexAuxFile];
  NSString* pdfFile               = [NSString stringWithFormat:@"%@.pdf", filePrefix];
  NSString* pdfFilePath           = [workingDirectory stringByAppendingPathComponent:pdfFile];
  NSString* dviFile               = [NSString stringWithFormat:@"%@.dvi", filePrefix];
  NSString* dviFilePath           = [workingDirectory stringByAppendingPathComponent:dviFile];
  
  //the files useful for step 2 (tex file with magical boxes, pdf result, and a file summarizing the bounding box and baseline)
  NSString* latexBaselineFile        = [NSString stringWithFormat:@"%@-baseline.tex", filePrefix];
  NSString* latexBaselineFilePath    = [workingDirectory stringByAppendingPathComponent:latexBaselineFile];
  NSString* latexAuxBaselineFile     = [NSString stringWithFormat:@"%@-baseline.aux", filePrefix];
  NSString* latexAuxBaselineFilePath = [workingDirectory stringByAppendingPathComponent:latexAuxBaselineFile];
  NSString* pdfBaselineFile          = [NSString stringWithFormat:@"%@-baseline.pdf", filePrefix];
  NSString* pdfBaselineFilePath      = [workingDirectory stringByAppendingPathComponent:pdfBaselineFile];
  NSString* sizesFile                = [NSString stringWithFormat:@"%@-baseline.sizes", filePrefix];
  NSString* sizesFilePath            = [workingDirectory stringByAppendingPathComponent:sizesFile];
  
  //the files useful for step 3 (tex file with magical boxes encapsulating the image generated during step 1), and pdf result
  NSString* latexFile2         = [NSString stringWithFormat:@"%@-2.tex", filePrefix];
  NSString* latexFilePath2     = [workingDirectory stringByAppendingPathComponent:latexFile2];
  NSString* latexAuxFile2      = [NSString stringWithFormat:@"%@-2.aux", filePrefix];
  NSString* latexAuxFilePath2  = [workingDirectory stringByAppendingPathComponent:latexAuxFile2];
  NSString* pdfFile2           = [NSString stringWithFormat:@"%@-2.pdf", filePrefix];
  NSString* pdfFilePath2       = [workingDirectory stringByAppendingPathComponent:pdfFile2];
  NSString* pdfCroppedFile     = [NSString stringWithFormat:@"%@-crop.pdf", filePrefix];
  NSString* pdfCroppedFilePath = [workingDirectory stringByAppendingPathComponent:pdfCroppedFile];

  //trash old files
  NSFileManager* fileManager = [NSFileManager defaultManager];
  [fileManager removeItemAtPath:latexFilePath            error:0];
  [fileManager removeItemAtPath:latexAuxFilePath         error:0];
  [fileManager removeItemAtPath:latexFilePath2           error:0];
  [fileManager removeItemAtPath:latexAuxFilePath2        error:0];
  [fileManager removeItemAtPath:pdfFilePath              error:0];
  [fileManager removeItemAtPath:dviFilePath              error:0];
  [fileManager removeItemAtPath:pdfFilePath2             error:0];
  [fileManager removeItemAtPath:pdfCroppedFilePath       error:0];
  [fileManager removeItemAtPath:latexBaselineFilePath    error:0];
  [fileManager removeItemAtPath:latexAuxBaselineFilePath error:0];
  [fileManager removeItemAtPath:pdfBaselineFilePath      error:0];
  [fileManager removeItemAtPath:sizesFilePath            error:0];
  
  //trash *.*pk, *.mf, *.tfm, *.mp, *.script, *.[[:digit:]], *.t[[:digit:]]+
  NSArray* files = [fileManager contentsOfDirectoryAtPath:workingDirectory error:0];
  NSEnumerator* enumerator = [files objectEnumerator];
  NSString* file = nil;
  while((file = [enumerator nextObject]))
  {
    file = [workingDirectory stringByAppendingPathComponent:file];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:file isDirectory:&isDirectory] && !isDirectory)
    {
      NSString* extension = file.pathExtension.lowercaseString;
      BOOL mustDelete = [extension isEqualToString:@"mf"] ||  [extension isEqualToString:@"mp"] ||
                        [extension isEqualToString:@"tfm"] || [extension endsWith:@"pk" options:NSCaseInsensitiveSearch] ||
                        [extension isEqualToString:@"script"] ||
                        [extension isMatchedByRegex:@"^[[:digit:]]+$"] ||
                        [extension isMatchedByRegex:@"^t[[:digit:]]+$"];
      if (mustDelete)
        [fileManager removeItemAtPath:file error:0];
    }
  }
  
  //add additional files
  NSMutableArray* additionalFilesPathsLinksCreated = [NSMutableArray arrayWithCapacity:additionalFilesPaths.count];
  enumerator = [additionalFilesPaths objectEnumerator];
  NSString* additionalFilePath = nil;
  NSString* outLinkPath = nil;
  while((additionalFilePath = [enumerator nextObject]))
  {
    [fileManager createLinkInDirectory:workingDirectory toTarget:additionalFilePath linkName:nil outLinkPath:&outLinkPath];
    if (outLinkPath)
      [additionalFilesPathsLinksCreated addObject:outLinkPath];
  }

  //some tuning due to parameters; note that \[...\] is replaced by $\displaystyle because of
  //incompatibilities with the magical boxes
  NSString* addSymbolLeft  = (latexMode == LATEX_MODE_ALIGN) ? @"\\begin{align*}" :
                             (latexMode == LATEX_MODE_EQNARRAY) ? @"\\begin{eqnarray*}" :
                             (latexMode == LATEX_MODE_DISPLAY) ? @"$\\displaystyle " :
                             (latexMode == LATEX_MODE_INLINE) ? @"$" : @"";
  NSString* addSymbolRight = (latexMode == LATEX_MODE_ALIGN) ? @"\\end{align*}" :
                             (latexMode == LATEX_MODE_EQNARRAY) ? @"\\end{eqnarray*}" :
                             (latexMode == LATEX_MODE_DISPLAY) ? @"$" :
                             (latexMode == LATEX_MODE_INLINE) ? @"$" : @"";
  id appControllerClass = NSClassFromString(@"AppController");
  BOOL isColorStyAvailable = !appControllerClass || [[appControllerClass valueForKey:@"appController"] valueForKey:@"isColorStyAvailable"];
  NSString* colouredPreamble = [self insertColorInPreamble:preamble color:color isColorStyAvailable:isColorStyAvailable];
  NSMutableString* fullLog = [NSMutableString string];
  
  CGFloat ptSizeBase = 10.;
  composition_mode_t compositionMode = [compositionConfiguration compositionConfigurationCompositionMode];

  //add extra margins (empirically)
  if (((latexMode == LATEX_MODE_DISPLAY) || (latexMode == LATEX_MODE_INLINE)) &&
      (compositionMode == COMPOSITION_MODE_PDFLATEX))
  {
    topMargin    += .05f*magnification/ptSizeBase;
    bottomMargin += .05f*magnification/ptSizeBase;
  }
  
  NSString* ptSizeString =
    [colouredPreamble stringByMatching:@"(^|\n)[^%\n]*\\\\documentclass\\[(.*)pt\\].*" options:RKLMultiline|RKLDotAll
                               inRange:NSMakeRange(0, colouredPreamble.length) capture:2 error:nil];
  if (ptSizeString && ptSizeString.length)
  {
    CGFloat floatValue = ptSizeString.floatValue;
    if (floatValue > 0)
      ptSizeBase = floatValue;
  }

  //STEP 1
  //first, creates simple latex source text to compile and report errors (if there are any)
  
  //the body is trimmed to avoid some latex problems (sometimes, a newline at the end of the equation makes it fail!)
  NSString* trimmedBody = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  trimmedBody = [trimmedBody stringByAppendingString:@"\n"];//in case that a % is on the last line
  //the problem is that now, the error lines must be shifted ! How many new lines have been removed ?
  NSString* firstChar = trimmedBody.length ? [trimmedBody substringWithRange:NSMakeRange(0, 1)] : @"";
  NSRange firstCharLocation = [body rangeOfString:firstChar];
  NSRange rangeOfTrimmedHeader = NSMakeRange(0, (firstCharLocation.location != NSNotFound) ? firstCharLocation.location : 0);
  NSString* trimmedHeader = [body substringWithRange:rangeOfTrimmedHeader];
  NSUInteger nbNewLinesInTrimmedHeader = MAX(1U, [[trimmedHeader componentsSeparatedByString:@"\n"] count]);
  NSInteger errorLineShift = MAX((NSInteger)0, (NSInteger)nbNewLinesInTrimmedHeader-1);
  
  NSDictionary* additionalProcessingScripts = [compositionConfiguration compositionConfigurationAdditionalProcessingScripts];
  
  //xelatex requires to insert the color in the body, so we compute the color as string...
  color = [(color ? color : [NSColor blackColor]) colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  CGFloat rgba[4] = {0, 0, 0, 0};
  [color getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
  NSString* colorString = [color isRGBEqualTo:[NSColor blackColor]] ? @"" :
    [NSString stringWithFormat:@"\\color[rgb]{%1.3f,%1.3f,%1.3f}", rgba[0], rgba[1], rgba[2]];
  NSString* normalSourceToCompile =
    [NSString stringWithFormat:
      @"%@\n\\pagestyle{empty} "\
       "\\begin{document}"\
       "%@%@%@%@\n"\
       "\\end{document}",
       [colouredPreamble stringByReplacingYenSymbol],
       (compositionMode == COMPOSITION_MODE_XELATEX) ? colorString : 
       (compositionMode == COMPOSITION_MODE_LUALATEX) ? colorString : @"",
       addSymbolLeft,
       [trimmedBody stringByReplacingYenSymbol],
       addSymbolRight];

  //creates the corresponding latex file
  NSData* latexData = [normalSourceToCompile dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
  BOOL failed = ![latexData writeToFile:latexFilePath atomically:NO];

  //if (!failed)
  //  [fullLog appendFormat:@"Source :\n%@\n", normalSourceToCompile];
      
  //PREPROCESSING
  NSDictionary* extraEnvironment =
    @{@"CURRENTDIRECTORY": latexFilePath.stringByDeletingLastPathComponent,
                                                @"INPUTFILE": latexFilePath.stringByDeletingPathExtension,
                                                @"INPUTTEXFILE": latexFilePath,
                                                @"OUTPUTPDFFILE": pdfFilePath,
                                                @"OUTPUTPDFFILE2": pdfFilePath2,
                                                @"OUTPUTDVIFILE": (compositionMode == COMPOSITION_MODE_LATEXDVIPDF)
                                                  ? dviFilePath : nil};
  NSMutableDictionary* environment1 = [NSMutableDictionary dictionaryWithDictionary:fullEnvironment];
  [environment1 addEntriesFromDictionary:extraEnvironment];
  NSDictionary* script = additionalProcessingScripts[[NSString stringWithFormat:@"%d",SCRIPT_PLACE_PREPROCESSING]];
  if (script && [script[CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
  {
    [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Pre-processing", @"Pre-processing")];
    [fullLog appendFormat:@"%@\n", [self descriptionForScript:script]];
    [self executeScript:script setEnvironment:environment1 logString:fullLog workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
      compositionConfiguration:compositionConfiguration];
    if (outFullLog)
      *outFullLog = fullLog;
  }

  NSString* customLog = nil;
  NSString* stdoutLog = nil;
  NSString* stderrLog = nil;
  failed |= ![self composeLaTeX:latexFilePath customLog:&customLog stdoutLog:&stdoutLog stderrLog:&stderrLog
                compositionConfiguration:compositionConfiguration fullEnvironment:fullEnvironment];
  if (customLog)
    [fullLog appendString:customLog];
  if (outFullLog)
    *outFullLog = fullLog;

  NSArray* errors = [self filterLatexErrors:[stdoutLog stringByAppendingString:stderrLog] shiftLinesBy:errorLineShift];
  if (outErrors) *outErrors = errors;
  BOOL isDirectory = NO;
  failed |= errors && errors.count && (![fileManager fileExistsAtPath:pdfFilePath isDirectory:&isDirectory] || isDirectory);
  //STEP 1 is over. If it has failed, it is the fault of the user, and syntax errors will be reported

  //Middle-Processing
  if (!failed)
  {
    NSDictionary* script = additionalProcessingScripts[[NSString stringWithFormat:@"%d",SCRIPT_PLACE_MIDDLEPROCESSING]];
    if (script && [script[CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
    {
      [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Middle-processing", @"Middle-processing")];
      [fullLog appendFormat:@"%@\n", [self descriptionForScript:script]];
      [self executeScript:script setEnvironment:environment1 logString:fullLog workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
        compositionConfiguration:compositionConfiguration];
      if (outFullLog) *outFullLog = fullLog;
    }
  }

  //STEP 2
  CGFloat fontColorWhite = [color grayLevel];
  BOOL  fontColorIsWhite = (fontColorWhite == 1.f);
  BOOL shouldTryStep2 = !fontColorIsWhite &&
                         (latexMode != LATEX_MODE_TEXT) && (latexMode != LATEX_MODE_EQNARRAY) && (latexMode != LATEX_MODE_ALIGN) &&
                         (compositionMode != COMPOSITION_MODE_LATEXDVIPDF);
                         //&& (compositionMode != COMPOSITION_MODE_XELATEX);
  //But if the latex file passed this first latexisation, it is time to start step 2 and perform cropping and magnification.
  if (!failed)
  {
    if (shouldTryStep2) //we do not even try step 2 in TEXT mode, since we will perform step 3 to allow line breakings
    {
      //compute the bounding box of the pdf file generated during step 1
      NSRect boundingBox = [self computeBoundingBox:((compositionMode == COMPOSITION_MODE_LATEXDVIPDF) ? dviFilePath : pdfFilePath)
                                   workingDirectory:workingDirectory fullEnvironment:fullEnvironment compositionConfiguration:compositionConfiguration outFullLog:fullLog];
      boundingBox.origin.x    -= leftMargin/(magnification/ptSizeBase);
      boundingBox.size.width  += (leftMargin+rightMargin)/(magnification/ptSizeBase);
      boundingBox.origin.y    -= (bottomMargin)/(magnification/ptSizeBase);
      boundingBox.size.height += (topMargin+bottomMargin)/(magnification/ptSizeBase);
      boundingBox.size.width  = ceil(boundingBox.size.width)+(boundingBox.origin.x-floor(boundingBox.origin.x));
      boundingBox.size.height = ceil(boundingBox.size.height)+(boundingBox.origin.y-floor(boundingBox.origin.y));
      boundingBox.origin.x    = floor(boundingBox.origin.x);
      boundingBox.origin.y    = floor(boundingBox.origin.y);

      //this magical template uses boxes that scales and automagically find their own geometry
      //But it may fail for some kinds of equation, especially multi-lines equations. However, we try it because it is fast
      //and efficient. This will even generate a baseline if it works !
      NSString* magicSourceToFindBaseLine =
        [NSString stringWithFormat:
          @"%@\n" //preamble
          "\\pagestyle{empty}\n"
          "\\usepackage[papersize={%fbp,%fbp},margin=%fbp]{geometry}\n"
          "\\pagestyle{empty}\n"
          "\\usepackage{graphicx}\n"
          "\\newsavebox{\\latexitbox}\n"
          "\\newcommand{\\latexitscalefactor}{%f}\n" //magnification
          "\\newlength{\\latexitdepth}\n"
          "\\normalfont\n"
          "\\begin{lrbox}{\\latexitbox}\n"
          "%@%@%@\n" //source text
          "\\end{lrbox}\n"
          "\\settodepth{\\latexitdepth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"
          "\\newwrite\\foo\n"
          "\\immediate\\openout\\foo=\\jobname.sizes\n"
          "\\immediate\\write\\foo{\\the\\latexitdepth (Depth)}\n"
          "\\closeout\\foo\n"
          "\\begin{document}\\includegraphics*[scale=%f,clip=%@,viewport=%fbp %fbp %fbp %fbp]{%@}\n\\end{document}\n", 
          @"\\documentclass[10pt]{article}",//,[colouredPreamble replaceYenSymbol], //preamble
          ceil((boundingBox.origin.x+boundingBox.size.width)*magnification/ptSizeBase),
          ceil((boundingBox.origin.y+boundingBox.size.height)*magnification/ptSizeBase),
          0.f,
          magnification/ptSizeBase, //latexitscalefactor = magnification
          addSymbolLeft, [body stringByReplacingYenSymbol], addSymbolRight, //source text
          magnification/ptSizeBase,
          (compositionMode == COMPOSITION_MODE_XELATEX) ? @"false" :
          (compositionMode == COMPOSITION_MODE_LUALATEX) ? @"false" :
          @"true",
          boundingBox.origin.x,
          boundingBox.origin.y,
          boundingBox.origin.x+boundingBox.size.width,
          boundingBox.origin.y+boundingBox.size.height,
          pdfFile
        ];

      //try to latexise that file
      NSData* latexData = [magicSourceToFindBaseLine dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];  
      failed |= ![latexData writeToFile:latexBaselineFilePath atomically:NO];
      if (!failed)
        pdfData = [self composeLaTeX:latexBaselineFilePath customLog:&customLog stdoutLog:&stdoutLog stderrLog:&stderrLog
                     compositionConfiguration:compositionConfiguration fullEnvironment:fullEnvironment];
      failed |= !pdfData;
      if (!failed)
      {
        NSString* pdfLaTeXPath = [compositionConfiguration compositionConfigurationProgramPathPdfLaTeX];
        NSString* xeLaTeXPath  = [compositionConfiguration compositionConfigurationProgramPathXeLaTeX];
        NSString* luaLaTeXPath  = [compositionConfiguration compositionConfigurationProgramPathLuaLaTeX];
        NSString* gsPath       = [compositionConfiguration compositionConfigurationProgramPathGs];
        
        NSString* texcmdtype =
          (compositionMode == COMPOSITION_MODE_XELATEX) ? @"--xetex" :
          (compositionMode == COMPOSITION_MODE_LUALATEX) ? @"--pdftex" :
          @"--pdftex";
        NSString* texcmd =
          (compositionMode == COMPOSITION_MODE_XELATEX) ? @"--xetexcmd" :
        (compositionMode == COMPOSITION_MODE_LUALATEX) ? @"--pdftexcmd" :
          @"--pdftexcmd";
        NSString* texcmdparameter =
          (compositionMode == COMPOSITION_MODE_XELATEX) ? xeLaTeXPath :
          (compositionMode == COMPOSITION_MODE_LUALATEX) ? luaLaTeXPath :
          pdfLaTeXPath;
        NSArray*  extraArguments = @[@"--gscmd", gsPath, texcmdtype, texcmd, texcmdparameter,
          @"--margins", [NSString stringWithFormat:@"\"%f %f %f %f\"", leftMargin, topMargin, rightMargin, bottomMargin]];
        BOOL canClip = (compositionMode != COMPOSITION_MODE_XELATEX);// && (compositionMode != COMPOSITION_MODE_LUALATEX);
        [self crop:pdfBaselineFilePath to:pdfCroppedFilePath canClip:canClip extraArguments:extraArguments compositionConfiguration:compositionConfiguration
          workingDirectory:workingDirectory environment:fullEnvironment outFullLog:fullLog outPdfData:&pdfData];
      }
    }//end of step 2
    
    //Now, step 2 may have failed. We check it. If it has not failed, that's great, the pdf result is the one we wanted !
    float baseline = 0;
    if (!failed && shouldTryStep2)
    {
      NSStringEncoding encoding = NSUTF8StringEncoding;
      NSError* error = nil;
      //try to read the baseline in the "sizes" file magically generated
      NSString* sizes = [NSString stringWithContentsOfFile:sizesFilePath guessEncoding:&encoding error:&error];
      NSScanner* scanner = [NSScanner scannerWithString:sizes];
      [scanner scanFloat:&baseline];
      //Step 2 is over, it has worked, so step 3 is useless.
    }
    //STEP 3
    else //if step 2 failed, we must use the heavy method of step 3
    {
      failed = NO; //since step 3 is a resort, step 2 is not a real failure, so we reset <failed> to NO
      pdfData = nil;
      NSRect boundingBox = [self computeBoundingBox:((compositionMode == COMPOSITION_MODE_LATEXDVIPDF) ? dviFilePath : pdfFilePath)
                                   workingDirectory:workingDirectory fullEnvironment:fullEnvironment compositionConfiguration:compositionConfiguration outFullLog:fullLog];
      BOOL boundingBoxCouldNotBeComputed = (!boundingBox.size.width || !boundingBox.size.height);

      boundingBox.origin.x    -= leftMargin/(magnification/ptSizeBase)*(magnification/ptSizeBase);
      boundingBox.size.width  += (leftMargin+rightMargin)/(magnification/ptSizeBase)*(magnification/ptSizeBase);
      boundingBox.origin.y    -= bottomMargin/(magnification/ptSizeBase)*(magnification/ptSizeBase);
      boundingBox.size.height += (topMargin+bottomMargin)/(magnification/ptSizeBase)*(magnification/ptSizeBase);
      boundingBox.size.width  = ceil(ceil(boundingBox.size.width)+(boundingBox.origin.x-floor(boundingBox.origin.x)));
      boundingBox.size.height = ceil(ceil(boundingBox.size.height)+(boundingBox.origin.y-floor(boundingBox.origin.y)));
      boundingBox.origin.x    = floor(boundingBox.origin.x);
      boundingBox.origin.y    = floor(boundingBox.origin.y);

      //then use the bounding box and the magnification on the pdf file of step 1
      NSString* magicSourceToProducePDF =
        [NSString stringWithFormat:
          @"\\documentclass[%dpt]{article}\n"
          "\\usepackage[papersize={%fbp,%fbp},margin=%fbp]{geometry}\n"
          "\\pagestyle{empty}\n"
          "\\usepackage{graphicx}\n"
          "\\begin{document}\\includegraphics*[scale=%f,clip=%@,viewport=%fbp %fbp %fbp %fbp,hiresbb=true]{%@}\n\\end{document}\n", 
          (int)ptSizeBase,
          ceil((boundingBox.origin.x+boundingBox.size.width)*magnification/ptSizeBase),
          ceil((boundingBox.origin.y+boundingBox.size.height)*magnification/ptSizeBase),
          0.f,
          magnification/ptSizeBase,
          (compositionMode == COMPOSITION_MODE_XELATEX) ? @"false" :
          (compositionMode == COMPOSITION_MODE_LUALATEX) ? @"false" :
          @"true",
          boundingBox.origin.x,
          boundingBox.origin.y,
          boundingBox.origin.x+boundingBox.size.width,
          boundingBox.origin.y+boundingBox.size.height,
          pdfFile
        ];

      //Latexisation of step 3. Should never fail. Should always be performed in PDFLATEX mode to get a proper bounding box
      NSData* latexData = [magicSourceToProducePDF dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];  
      failed |= ![latexData writeToFile:latexFilePath2 atomically:NO];
      
      if (!failed)
        pdfData = [self composeLaTeX:latexFilePath2 customLog:&customLog stdoutLog:&stdoutLog stderrLog:&stderrLog
                     compositionConfiguration:[compositionConfiguration dictionaryByAddingObjectsAndKeys:
                       @(COMPOSITION_MODE_PDFLATEX), CompositionConfigurationCompositionModeKey,
                       [NSNumber numberWithUnsignedInteger:(isMacOS10_14OrAbove() ? 5 : 3)], @"pdfMinorVersion",
                       nil]
                     fullEnvironment:fullEnvironment];
      failed |= !pdfData;
      //call pdfcrop
      if (!failed)
      {
        NSString* pdfLaTeXPath = [compositionConfiguration compositionConfigurationProgramPathPdfLaTeX];
        NSString* xeLaTeXPath  = [compositionConfiguration compositionConfigurationProgramPathXeLaTeX];
        NSString* luaLaTeXPath = [compositionConfiguration compositionConfigurationProgramPathLuaLaTeX];
        NSString* gsPath       = [compositionConfiguration compositionConfigurationProgramPathGs];
        
        NSString* texcmdtype =
          (compositionMode == COMPOSITION_MODE_XELATEX) ? @"--xetex" :
          (compositionMode == COMPOSITION_MODE_LUALATEX) ? @"--pdftex" :
          @"--pdftex";
        NSString* texcmd =
          (compositionMode == COMPOSITION_MODE_XELATEX) ? @"--xetexcmd" :
        (compositionMode == COMPOSITION_MODE_LUALATEX) ? @"--pdftexcmd" :
          @"--pdftexcmd";
        NSString* texcmdparameter =
          (compositionMode == COMPOSITION_MODE_XELATEX) ? xeLaTeXPath :
          (compositionMode == COMPOSITION_MODE_LUALATEX) ? luaLaTeXPath :
          pdfLaTeXPath;
        NSArray*  extraArguments = @[@"--gscmd", gsPath, texcmdtype, texcmd, texcmdparameter,
          @"--margins", [NSString stringWithFormat:@"\"%f %f %f %f\"", leftMargin, topMargin, rightMargin, bottomMargin]];
        BOOL canClip = (compositionMode != COMPOSITION_MODE_XELATEX);//&& (compositionMode != COMPOSITION_MODE_LUALATEX)
        failed = fontColorIsWhite || boundingBoxCouldNotBeComputed ||
                 ![self crop:pdfFilePath2 to:pdfCroppedFilePath canClip:canClip extraArguments:extraArguments
                     compositionConfiguration:compositionConfiguration workingDirectory:workingDirectory environment:fullEnvironment outFullLog:fullLog outPdfData:&pdfData];
        if (failed)//use old method
        {
          failed = NO; //since step 3 is a resort, step 2 is not a real failure, so we reset <failed> to NO
          pdfData = nil;
          NSRect boundingBox = [self computeBoundingBox:pdfFilePath workingDirectory:workingDirectory fullEnvironment:fullEnvironment
                                compositionConfiguration:compositionConfiguration outFullLog:fullLog];

          //compute the bounding box of the pdf file generated during step 1
          boundingBox.origin.x    -= leftMargin/(magnification/ptSizeBase);
          boundingBox.origin.y    -= bottomMargin/(magnification/ptSizeBase);
          boundingBox.size.width  += (rightMargin+leftMargin)/(magnification/ptSizeBase);
          boundingBox.size.height += (bottomMargin+topMargin)/(magnification/ptSizeBase);
          boundingBox.size.width  = ceil(ceil(boundingBox.size.width)+(boundingBox.origin.x-floor(boundingBox.origin.x)));
          boundingBox.size.height = ceil(ceil(boundingBox.size.height)+(boundingBox.origin.y-floor(boundingBox.origin.y)));
          boundingBox.origin.x    = floor(boundingBox.origin.x);
          boundingBox.origin.y    = floor(boundingBox.origin.y);
        
          //then use the bounding box and the magnification in the magic-box-template, the body of which will be a mere \includegraphics
          //of the pdf file of step 1
          NSString* magicSourceToProducePDF =
            [NSString stringWithFormat:
              @"%@\n"
              "\\pagestyle{empty}\n"
              "\\usepackage{geometry}\n"
              "\\usepackage{graphicx}\n"
              "\\newsavebox{\\latexitbox}\n"
              "\\newcommand{\\latexitscalefactor}{%f}\n"
              "\\newlength{\\latexitwidth}\n\\newlength{\\latexitheight}\n\\newlength{\\latexitdepth}\n"
              "\\setlength{\\topskip}{0pt}\n\\setlength{\\parindent}{0pt}\n\\setlength{\\abovedisplayskip}{0pt}\n"
              "\\setlength{\\belowdisplayskip}{0pt}\n"
              "\\normalfont\n"
              "\\begin{lrbox}{\\latexitbox}\n"
              "\\includegraphics[viewport = %f %f %f %f]{%@}\n"
              "\\end{lrbox}\n"
              "\\settowidth{\\latexitwidth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"
              "\\settoheight{\\latexitheight}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"
              "\\settodepth{\\latexitdepth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"
              "\\newwrite\\foo \\immediate\\openout\\foo=\\jobname.sizes \\immediate\\write\\foo{\\the\\latexitdepth (Depth)}\n"
              "\\immediate\\write\\foo{\\the\\latexitheight (Height)}\n"
              "\\addtolength{\\latexitheight}{\\latexitdepth}\n"
              //"\\addtolength{\\latexitheight}{%f pt}\n" //little correction
              "\\immediate\\write\\foo{\\the\\latexitheight (TotalHeight)} \\immediate\\write\\foo{\\the\\latexitwidth (Width)}\n"
              "\\closeout\\foo \\geometry{paperwidth=\\latexitwidth,paperheight=\\latexitheight,margin=0pt}\n"
              "\\begin{document}\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}\\end{document}\n", 
              //[self _replaceYenSymbol:colouredPreamble],
              @"\\documentclass[10pt]{article}\n",//minimal preamble
              magnification/10.0,
              boundingBox.origin.x,
              boundingBox.origin.y,
              boundingBox.origin.x+boundingBox.size.width,
              boundingBox.origin.y+boundingBox.size.height,//+0.2,//little correction empiricaly found
              pdfFile
              //400*magnification/10000
              ]; //little correction to avoid cropping errors (empirically found)

          //Latexisation of step 3. Should never fail. Should always be performed in PDFLatexMode to get a proper bounding box
          NSData* latexData = [magicSourceToProducePDF dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];  
          failed |= ![latexData writeToFile:latexFilePath2 atomically:NO];
          if (!failed)
            pdfData = [self composeLaTeX:latexFilePath2 customLog:&customLog stdoutLog:&stdoutLog stderrLog:&stderrLog
                        compositionConfiguration:[compositionConfiguration dictionaryByAddingObjectsAndKeys:
                          @(COMPOSITION_MODE_PDFLATEX), CompositionConfigurationCompositionModeKey,
                          [NSNumber numberWithUnsignedInteger:(isMacOS10_14OrAbove() ? 5 : 3)], @"pdfMinorVersion",
                          nil]
                        fullEnvironment:fullEnvironment];
          failed |= !pdfData;
        }//if pdfcrop cropping fails
      }//end if step 2 failed
    }//end STEP 3
    
    //the baseline is affected by the bottom margin
    baseline += bottomMargin;

    //Now that we are here, either step 2 passed, or step 3 passed. (But if step 2 failed, step 3 should not have failed)
    //pdfData should contain the cropped/magnified/coloured wanted image
    if (!failed && pdfData)
    {
      PDFDocument* pdfDocument = nil;
      @try{
        //in the meta-data of the PDF we store as much info as we can : preamble, body, size, color, mode, baseline...
        pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
        NSDictionary* attributes =
          @{PDFDocumentCreatorAttribute: [[NSWorkspace sharedWorkspace] applicationName]};
        pdfDocument.documentAttributes = attributes;
        pdfData = [pdfDocument dataRepresentation];
      }
      @catch(NSException* e){
        DebugLog(0, @"exception : %@", e);
      }
    }//end if (!failed && pdfData)

    if (!failed && pdfData)
    {
      //POSTPROCESSING
      NSDictionary* script = additionalProcessingScripts[[NSString stringWithFormat:@"%d",SCRIPT_PLACE_POSTPROCESSING]];
      if (script && [script[CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
      {
        [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Post-processing", @"Post-processing")];
        [fullLog appendFormat:@"%@\n", [self descriptionForScript:script]];
        [self executeScript:script setEnvironment:environment1 logString:fullLog workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
          compositionConfiguration:compositionConfiguration];
        if (outFullLog) *outFullLog = fullLog;
      }
    }

    //adds some meta-data to be compatible with Latex Equation Editor
    export_format_t exportFormat = EXPORT_FORMAT_PDF;
    if (!failed && pdfData)
      pdfData = [self annotatePdfDataInLEEFormat:pdfData exportFormat:exportFormat preamble:preamble source:body color:color
                                            mode:latexMode magnification:magnification baseline:baseline
                                 backgroundColor:backgroundColor title:title
                     annotateWithTransparentData:NO];//prevent graphic metadata to be generated too early
    [pdfData writeToFile:pdfFilePath atomically:NO];//Recreates the document with the new meta-data
  }//end if latex source could be compiled

  //remove additional files
  enumerator = [additionalFilesPathsLinksCreated objectEnumerator];
  NSString* additionalFilePathLinkPath = nil;
  while((additionalFilePathLinkPath = [enumerator nextObject]))
    [fileManager removeItemAtPath:additionalFilePathLinkPath error:0];

  if (outPdfData)
    *outPdfData = pdfData;
  
  //returns the cropped/magnified/coloured image if possible; nil if it has failed. 
  return !pdfData ? nil : pdfFilePath;
}
//end latexiseWithPreamble:body:color:mode:magnification:

//computes the tight bounding box of a pdfFile
-(NSRect) computeBoundingBox:(NSString*)filePath workingDirectory:(NSString*)workingDirectory
             fullEnvironment:(NSDictionary*)fullEnvironment compositionConfiguration:(NSDictionary*)compositionConfiguration
                  outFullLog:(NSMutableString*)outFullLog
{
  NSRect boundingBoxRect = NSZeroRect;
  
  //We will rely on GhostScript (gs) to compute the bounding box
  NSFileManager* fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:filePath])
  {
    BOOL      useLoginShell   = [compositionConfiguration compositionConfigurationUseLoginShell];
    NSString* dviPdfPath      = [compositionConfiguration compositionConfigurationProgramPathDviPdf];
    NSArray*  dviPdfArguments = [compositionConfiguration compositionConfigurationProgramArgumentsDviPdf];
    NSString* gsPath          = [compositionConfiguration compositionConfigurationProgramPathGs];
    NSArray*  gsArguments     = [compositionConfiguration compositionConfigurationProgramArgumentsGs];
  
    SystemTask* boundingBoxTask = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
    boundingBoxTask.usingLoginShell = useLoginShell;
    boundingBoxTask.currentDirectoryPath = workingDirectory;
    boundingBoxTask.environment = fullEnvironment;
    if ([filePath.pathExtension.lowercaseString isEqualToString:@"dvi"])
      boundingBoxTask.launchPath = dviPdfPath;
    else
      boundingBoxTask.launchPath = gsPath;
    NSArray* defaultArguments = ([filePath.pathExtension.lowercaseString isEqualToString:@"dvi"]) ? dviPdfArguments : gsArguments;
    boundingBoxTask.arguments = [defaultArguments arrayByAddingObjectsFromArray:
      @[@"-sstdout=%stderr", @"-dNOPAUSE", @"-dSAFER", @"-dNOPLATFONTS", @"-sDEVICE=bbox",@"-dBATCH",@"-q", filePath]];
    [outFullLog appendString:[NSString stringWithFormat:@"\n--------------- %@ ---------------\n%@\n",
                                NSLocalizedString(@"bounding box computation", @"bounding box computation"),
                                [boundingBoxTask equivalentLaunchCommand]]];
    [boundingBoxTask launch];
    [boundingBoxTask waitUntilExit];
    NSData*   boundingBoxData = [boundingBoxTask dataForStdError];
    NSString* boundingBoxString = [[NSString alloc] initWithData:boundingBoxData encoding:NSUTF8StringEncoding];
    NSRange range = [boundingBoxString rangeOfString:@"%%HiResBoundingBox:"];
    if (range.location != NSNotFound)
      boundingBoxString = [boundingBoxString substringFromIndex:range.location+range.length];
    NSScanner* scanner = [NSScanner scannerWithString:boundingBoxString];
    float originX = 0;
    float originY = 0;
    float sizeWidth = 0;
    float sizeHeight = 0;
    [scanner scanFloat:&originX];
    [scanner scanFloat:&originY];
    [scanner scanFloat:&sizeWidth];//in fact, we read the right corner, not the width
    [scanner scanFloat:&sizeHeight];//idem for height
    sizeWidth  -= originX;//so we correct here
    sizeHeight -= originY;
    
    boundingBoxRect = NSMakeRect(originX, originY, sizeWidth, sizeHeight); //I have used a tmpRect because gcc version 4.0.0 (Apple Computer, Inc. build 5026) issues a strange warning
    //it considers <boundingBoxRect> to be const when the try/catch/finally above is here. If you just comment try/catch/finally, the
    //warning would disappear
  }
  return boundingBoxRect;
}
//end computeBoundingBox:workingDirectory:fullEnvironment:useLoginShell:dviPdfPath:gsPath:

//compose latex and returns pdf data. the options may specify to use pdflatex or latex+dvipdf
-(NSData*) composeLaTeX:(NSString*)filePath customLog:(NSString**)customLog
              stdoutLog:(NSString**)stdoutLog stderrLog:(NSString**)stderrLog
              compositionConfiguration:(NSDictionary*)compositionConfiguration
              fullEnvironment:(NSDictionary*)fullEnvironment
{
  NSData* pdfData = nil;
  
  NSString* workingDirectory = filePath.stringByDeletingLastPathComponent;
  NSString* texFile   = filePath;
  NSString* dviFile   = [filePath.stringByDeletingPathExtension stringByAppendingPathExtension:@"dvi"];
  NSString* pdfFile   = [filePath.stringByDeletingPathExtension stringByAppendingPathExtension:@"pdf"];
  //NSString* errFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"err"];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  [fileManager removeItemAtPath:dviFile error:0];
  [fileManager removeItemAtPath:pdfFile error:0];
  
  NSMutableString* customString = [NSMutableString string];
  NSMutableString* stdoutString = [NSMutableString string];
  NSMutableString* stderrString = [NSMutableString string];

  NSStringEncoding encoding = NSUTF8StringEncoding;
  NSError* error = nil;
  NSString* source = [NSString stringWithContentsOfFile:texFile guessEncoding:&encoding error:&error];
  [customString appendString:[NSString stringWithFormat:@"Source :\n%@\n", source ? source : @""]];

  composition_mode_t compositionMode = [compositionConfiguration compositionConfigurationCompositionMode];
  BOOL useLoginShell = [compositionConfiguration compositionConfigurationUseLoginShell];

  //it happens that the NSTask fails for some strange reason (fflush problem...), so I will use a simple and ugly system() call
  NSString* executablePath =
    (compositionMode == COMPOSITION_MODE_XELATEX) ? [compositionConfiguration compositionConfigurationProgramPathXeLaTeX] :
    (compositionMode == COMPOSITION_MODE_LUALATEX) ? [compositionConfiguration compositionConfigurationProgramPathLuaLaTeX] :
    (compositionMode == COMPOSITION_MODE_PDFLATEX) ? [compositionConfiguration compositionConfigurationProgramPathPdfLaTeX] :
    [compositionConfiguration compositionConfigurationProgramPathLaTeX];

  NSArray* defaultArguments =
    (compositionMode == COMPOSITION_MODE_XELATEX) ? [compositionConfiguration compositionConfigurationProgramArgumentsXeLaTeX] :
    (compositionMode == COMPOSITION_MODE_LUALATEX) ? [compositionConfiguration compositionConfigurationProgramArgumentsLuaLaTeX] :
    (compositionMode == COMPOSITION_MODE_PDFLATEX) ? [compositionConfiguration compositionConfigurationProgramArgumentsPdfLaTeX] :
    [compositionConfiguration compositionConfigurationProgramArgumentsLaTeX];
  
  NSNumber* pdfMinorVersionNumber = [[compositionConfiguration objectForKey:@"pdfMinorVersion"] dynamicCastToClass:[NSNumber class]];
  NSUInteger pdfMinorVersion = [pdfMinorVersionNumber unsignedIntegerValue];
  BOOL usePdfMinorVersion = pdfMinorVersion && (compositionMode == COMPOSITION_MODE_PDFLATEX);
  NSString* texFileArg = !usePdfMinorVersion ? texFile :
    [NSString stringWithFormat:@"\"\\pdfminorversion=%@ \\input \\\"%@\\\"\"", [NSNumber numberWithUnsignedInteger:pdfMinorVersion], texFile];

  SystemTask* systemTask = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
  systemTask.usingLoginShell = useLoginShell;
  [systemTask setTimeOut:120];
  [systemTask setCurrentDirectoryPath:workingDirectory];
  [systemTask setLaunchPath:executablePath];
  [systemTask setArguments:[defaultArguments arrayByAddingObjectsFromArray:
    [NSArray arrayWithObjects:@"-file-line-error", @"-interaction", @"nonstopmode", texFileArg, nil]]];
  [systemTask setEnvironment:fullEnvironment];
  [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n%@\n",
                                                        NSLocalizedString(@"processing", @"processing"),
                                                        executablePath.lastPathComponent,
                                                        [systemTask equivalentLaunchCommand]]];
  [systemTask launch];
  BOOL failed = (systemTask.terminationStatus != 0) && ![fileManager fileExistsAtPath:pdfFile];
  NSData* dataForStdOutput = [systemTask dataForStdOutput];
  NSString* stdOutputErrors = [[NSString alloc] initWithData:dataForStdOutput encoding:NSUTF8StringEncoding];
  [customString appendString:stdOutputErrors ? stdOutputErrors : @""];
  [stdoutString appendString:stdOutputErrors ? stdOutputErrors : @""];
  
  //NSData* dataForStdError  = [systemTask dataForStdError];
  //NSString* stdErrors = [[[NSString alloc] initWithData:dataForStdError encoding:NSUTF8StringEncoding] autorelease];
  //[customString appendString:stdErrors ? stdErrors : @""];
  //[stdoutString appendString:stdErrors ? stdErrors : @""];
  
  if (failed)
    [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n",
                               NSLocalizedString(@"error while processing", @"error while processing"),
                               executablePath.lastPathComponent]];

  //if !failed and must call dvipdf...
  if (!failed && (compositionMode == COMPOSITION_MODE_LATEXDVIPDF))
  {
    NSString* dviPdfPath      = [compositionConfiguration compositionConfigurationProgramPathDviPdf];
    NSArray*  dviPdfArguments = [compositionConfiguration compositionConfigurationProgramArgumentsDviPdf];
  
    SystemTask* dvipdfTask = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
    dvipdfTask.usingLoginShell = useLoginShell;
    dvipdfTask.currentDirectoryPath = workingDirectory;
    dvipdfTask.environment = fullEnvironment;
    dvipdfTask.launchPath = dviPdfPath;
    dvipdfTask.arguments = [dviPdfArguments arrayByAddingObjectsFromArray:@[dviFile]];
    NSString* executablePath = dvipdfTask.launchPath.lastPathComponent;
    @try
    {
      [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n%@\n",
                                                            NSLocalizedString(@"processing", @"processing"),
                                                            dvipdfTask.launchPath.lastPathComponent,
                                                            [dvipdfTask commandLine]]];
      [dvipdfTask launch];
      [dvipdfTask waitUntilExit];
      NSData* stdoutData = [dvipdfTask dataForStdOutput];
      NSData* stderrData = [dvipdfTask dataForStdError];
      NSString* tmp = nil;
      tmp = stdoutData ? [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] : nil;
      if (tmp)
      {
        [customString appendString:tmp];
        [stdoutString appendString:tmp];
      }
      tmp = stderrData ? [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] : nil;
      if (tmp)
      {
        [customString appendString:tmp];
        [stderrString appendString:tmp];
      }
      failed = (dvipdfTask.terminationStatus != 0);
    }
    @catch(NSException* e)
    {
      failed = YES;
      [customString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", e.name, e.reason]];
    }
    
    if (failed)
      [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n",
                                 NSLocalizedString(@"error while processing", @"error while processing"),
                                 executablePath]];

  }//end of dvipdf call
  
  if (customLog)
    *customLog = customString;
  if (stdoutLog)
    *stdoutLog = stdoutString;
  if (stderrLog)
    *stderrLog = stderrString;
  
  if (!failed && [[NSFileManager defaultManager] fileExistsAtPath:pdfFile])
    pdfData = [NSData dataWithContentsOfFile:pdfFile options:NSUncachedRead error:nil];

  return pdfData;
}
//end composeLaTeX:customLog:stdoutLog:stderrLog:compositionMode:fullEnvironment:

//returns an array of the errors. Each case will contain an error string
-(NSArray*) filterLatexErrors:(NSString*)fullErrorLog shiftLinesBy:(NSInteger)errorLineShift
{
  NSArray* rawLogLines = [fullErrorLog componentsSeparatedByString:@"\n"];
  NSMutableArray* errorLines = [NSMutableArray arrayWithCapacity:rawLogLines.count];
  for(NSString *line in rawLogLines)
  {
    if (errorLines.count && [errorLines.lastObject endsWith:@":" options:0])
      errorLines[errorLines.count-1] = [errorLines.lastObject stringByAppendingString:line];
    else
      [errorLines addObject:line];
  }
  
  //first pass : pdflatex truncates lines at COLUMN=80. This is stupid. I must try to concatenate lines
  NSUInteger errorLineIndex = 0;
  while(errorLineIndex<errorLines.count)
  {
    NSString* line = errorLines[errorLineIndex];
    if (line.length < 79)
      ++errorLineIndex;
    else//if ([line length] >= 79)
    {
      NSMutableString* restoredLine = [NSMutableString stringWithString:line];
      NSString* nextLine = (errorLineIndex+1<errorLines.count) ? errorLines[errorLineIndex+1] : nil;
      if (nextLine)
        [restoredLine appendString:nextLine];
      BOOL nextLineMayBeTruncated = nextLine && (nextLine.length >= 80);
      if (nextLine)
        [errorLines removeObjectAtIndex:errorLineIndex+1];
      while(nextLineMayBeTruncated)
      {
        nextLine = (errorLineIndex+1<errorLines.count) ? errorLines[errorLineIndex+1] : nil;
        if (nextLine)
          [restoredLine appendString:nextLine];
        nextLineMayBeTruncated = nextLine && (nextLine.length >= 80);
        if (nextLine)
          [errorLines removeObjectAtIndex:errorLineIndex+1];
      }//end while(nextLineMayBeTruncated)
      errorLines[errorLineIndex] = restoredLine;
      ++errorLineIndex;
    }//end if ([line length] >= 79)
  }//end for each line

  NSMutableArray* filteredErrors = [NSMutableArray arrayWithCapacity:errorLines.count];
  const NSUInteger errorLineIndexCount = errorLines.count;
  errorLineIndex = 0;
  for(errorLineIndex = 0 ; errorLineIndex<errorLineIndexCount ; ++errorLineIndex)
  {
    NSString* line = errorLines[errorLineIndex];
    NSArray* components = [line componentsSeparatedByString:@":"];
    if (components.count >= 3) 
    {
      NSString* fileComponent  = components[0];
      NSString* lineComponent  = components[1];
      BOOL      lineComponentIsANumber = ![lineComponent isEqualToString:@""] && 
        [[lineComponent stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] isEqualToString:@""];
      NSString* errorComponent = [[components subarrayWithRange:NSMakeRange(2, components.count-2)] componentsJoinedByString:@":"];
      if (lineComponentIsANumber)
        lineComponent = @(lineComponent.integerValue+errorLineShift).stringValue;
      if (lineComponentIsANumber || ([line rangeOfString:@"! LaTeX Error:"].location != NSNotFound))
      {
        NSArray* fixedErrorComponents = @[fileComponent, lineComponent, errorComponent];
        NSString* fixedError = [fixedErrorComponents componentsJoinedByString:@":"];
        NSMutableString* fullError = [NSMutableString stringWithString:fixedError];
        NSString* nextLine = (errorLineIndex+1<errorLineIndexCount) ? errorLines[errorLineIndex+1] : nil;
        while(nextLine && line.length && ([line characterAtIndex:line.length-1] != '.'))
        {
          [fullError appendString:nextLine];
          line = nextLine;
          nextLine = (errorLineIndex+1<errorLineIndexCount) ? errorLines[errorLineIndex+1] : nil;
          ++errorLineIndex;
        }
        [filteredErrors addObject:fullError];
      }//end if error seems ok
    }//end if >=3 components
    else if (components.count > 1) //if 1 < < 3 components
    {
      if ([line rangeOfString:@"! LaTeX Error:"].location != NSNotFound)
      {
        NSString* fileComponent = @"";
        NSString* lineComponent = @"";
        NSString* errorComponent = [[components subarrayWithRange:NSMakeRange(1, components.count-1)] componentsJoinedByString:@":"];
        NSArray* fixedErrorComponents = @[fileComponent, lineComponent, errorComponent];
        NSString* fixedError = [fixedErrorComponents componentsJoinedByString:@":"];
        NSMutableString* fullError = [NSMutableString stringWithString:fixedError];
        NSString* nextLine = (errorLineIndex+1<errorLineIndexCount) ? errorLines[errorLineIndex+1] : nil;
        while(nextLine && line.length && ([line characterAtIndex:line.length-1] != '.'))
        {
          [fullError appendString:nextLine];
          line = nextLine;
          nextLine = (errorLineIndex+1<errorLineIndexCount) ? errorLines[errorLineIndex+1] : nil;
          ++errorLineIndex;
        }
        [filteredErrors addObject:fullError];
      }//end if error seems ok
      else if (line)
      {
        NSString* fileComponent  = components[0];
        NSString* lineComponent  = components[1];
        NSString* nextLine       = (errorLineIndex+1<errorLineIndexCount) ? errorLines[errorLineIndex+1] : nil;
        NSString* errorComponent = nextLine && ![nextLine isEqualToString:@""] ? nextLine : nil;
        BOOL lineComponentIsANumber = ![lineComponent isEqualToString:@""] && 
          [[lineComponent stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] isEqualToString:@""];

        NSString* fullLine = line;
        if (lineComponentIsANumber && nextLine)
          fullLine = [line stringByAppendingString:nextLine];
          
          lineComponent = @(lineComponent.integerValue+errorLineShift).stringValue;
        if (lineComponentIsANumber && errorComponent)
        {
          NSArray* fixedErrorComponents = @[fileComponent, lineComponent, errorComponent];
          NSString* fixedError = [fixedErrorComponents componentsJoinedByString:@":"];
          NSMutableString* fullError = [NSMutableString stringWithString:fixedError];
          ++errorLineIndex;
          line = nextLine;
          nextLine = (errorLineIndex+1<errorLineIndexCount) ? errorLines[errorLineIndex+1] : nil;
          while(nextLine && line.length && ([line characterAtIndex:line.length-1] != '.'))
          {
            [fullError appendString:nextLine];
            line = nextLine;
            nextLine = (errorLineIndex+1<errorLineIndexCount) ? errorLines[errorLineIndex+1] : nil;
            ++errorLineIndex;
          }
          [filteredErrors addObject:fullError];
        }//end if error seems ok
      }
    }//end if > 1 component
    else if ([line rangeOfString:@"! File ended"].location != NSNotFound)
    {
      [filteredErrors addObject:[NSString stringWithFormat:@"::%@", line]];
    }//end if ([line rangeOfString:@"! File ended"].location != NSNotFound)
  }//end while line
  return filteredErrors;
}
//end filterLatexErrors:shiftLinesBy:

-(BOOL) crop:(NSString*)inoutPdfFilePath to:(NSString*)outputPdfFilePath canClip:(BOOL)canClip extraArguments:(NSArray*)extraArguments
        compositionConfiguration:(NSDictionary*)compositionConfiguration
        workingDirectory:(NSString*)workingDirectory
        environment:(NSDictionary*)environment
        outFullLog:(NSMutableString*)fullLog
        outPdfData:(NSData**)outPdfData
{
  BOOL result = YES;
  
  //Call pdfCrop
  NSString* pdfVersion = isMacOS10_14OrAbove() ? @"1.5" : @"1.3";
  BOOL useLoginShell = [compositionConfiguration compositionConfigurationUseLoginShell];
  NSString* pdfCropPath  = [[NSBundle bundleForClass:[self class]] pathForResource:@"pdfcrop" ofType:@"pl"];
  NSMutableArray* arguments = [NSMutableArray arrayWithObjects:
    [NSString stringWithFormat:@"\"%@\"", pdfCropPath], (canClip ? @"--clip" : nil), @"--pdfversion", pdfVersion, nil];
  if (extraArguments)
    [arguments addObjectsFromArray:extraArguments];
  [arguments addObjectsFromArray:@[inoutPdfFilePath, outputPdfFilePath]];
  SystemTask* pdfCropTask = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
  pdfCropTask.usingLoginShell = useLoginShell;
  pdfCropTask.environment = environment;
  pdfCropTask.launchPath = @"perl";
  pdfCropTask.arguments = arguments;
  pdfCropTask.currentDirectoryPath = workingDirectory;
  [fullLog appendString:@"--------------- pdfcrop call ---------------\n"];
  [fullLog appendString:[pdfCropTask equivalentLaunchCommand]];
  [fullLog appendString:@"------------------------------------------------\n"];
  [pdfCropTask launch];
  [pdfCropTask waitUntilExit];
  result = (pdfCropTask.terminationStatus == 0);
  if (result)
  {
    NSData* croppedData = [NSData dataWithContentsOfFile:outputPdfFilePath options:NSUncachedRead error:nil];
    if (!croppedData)
      result = NO;
    else//if (croppedData)
    {
      if (outPdfData)
        *outPdfData = croppedData;
      result = [croppedData writeToFile:inoutPdfFilePath atomically:YES];
    }//end if (croppedData)
  }//end if (result)
  return result;
}
//end crop:to:canClip:extraArguments:compositionConfiguration:workingDirectory:environment:outPdfData:

-(NSString*) descriptionForScript:(NSDictionary*)script
{
  NSMutableString* description = [NSMutableString string];
  if (script)
  {
    switch([[script objectForKey:CompositionConfigurationAdditionalProcessingScriptTypeKey] integerValue])
    {
      case SCRIPT_SOURCE_STRING :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"Shell", @"Shell"),
          script[CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Body", @"Body"),
          script[CompositionConfigurationAdditionalProcessingScriptContentKey]];
        break;
      case SCRIPT_SOURCE_FILE :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"File", @"File"),
          script[CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Content", @"Content"),
          script[CompositionConfigurationAdditionalProcessingScriptPathKey]];
        break;
    }//end switch
  }//end if script
  return description;
}
//end descriptionForScript:

-(void) executeScript:(NSDictionary*)script setEnvironment:(NSDictionary*)environment logString:(NSMutableString*)logString
        workingDirectory:(NSString*)workingDirectory uniqueIdentifier:(NSString*)uniqueIdentifier
        compositionConfiguration:(NSDictionary*)compositionConfiguration
{
  if (script && [script[CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
  {
    NSString* filePrefix      = uniqueIdentifier; //file name, related to the current document
    NSString* latexScript     = [NSString stringWithFormat:@"%@.script", filePrefix];
    NSString* latexScriptPath = [workingDirectory stringByAppendingPathComponent:latexScript];
    NSString* logScript       = [NSString stringWithFormat:@"%@.script.log", filePrefix];
    NSString* logScriptPath   = [workingDirectory stringByAppendingPathComponent:logScript];

    NSFileManager* fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:latexScriptPath error:0];
    [fileManager removeItemAtPath:logScriptPath   error:0];
    
    NSString* scriptBody = nil;

    NSNumber* scriptType = [script objectForKey:CompositionConfigurationAdditionalProcessingScriptTypeKey];
    script_source_t source = scriptType ? [scriptType integerValue] : SCRIPT_SOURCE_STRING;

    NSStringEncoding encoding = NSUTF8StringEncoding;
    NSError* error = nil;
    switch(source)
    {
      case SCRIPT_SOURCE_STRING: scriptBody = script[CompositionConfigurationAdditionalProcessingScriptContentKey];break;
      case SCRIPT_SOURCE_FILE: scriptBody = [NSString stringWithContentsOfFile:script[CompositionConfigurationAdditionalProcessingScriptPathKey] guessEncoding:&encoding error:&error]; break;
    }
    
    NSData* scriptData = [scriptBody dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    [scriptData writeToFile:latexScriptPath atomically:NO];

    NSMutableDictionary* fileAttributes =
    [NSMutableDictionary dictionaryWithDictionary:[fileManager attributesOfFileSystemForPath:latexScriptPath error:0]];
    NSNumber* posixPermissions = fileAttributes[NSFilePosixPermissions];
    posixPermissions = @(posixPermissions.unsignedLongValue | 0700);//add rwx flag
    fileAttributes[NSFilePosixPermissions] = posixPermissions;
    [fileManager setAttributes:fileAttributes ofItemAtPath:latexScriptPath error:0];

    NSString* scriptShell = nil;
    switch(source)
    {
      case SCRIPT_SOURCE_STRING:
        scriptShell = script[CompositionConfigurationAdditionalProcessingScriptShellKey];
        break;
      case SCRIPT_SOURCE_FILE:
        scriptShell = @"/bin/bash";
        break;
    }//end switch(source)
    
    BOOL useLoginShell = [compositionConfiguration compositionConfigurationUseLoginShell];

    SystemTask* task = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
    task.usingLoginShell = useLoginShell;
    task.currentDirectoryPath = workingDirectory;
    task.environment = environment;
    task.launchPath = scriptShell;
    task.arguments = @[useLoginShell ? @"" : @"-l", @"-c", latexScriptPath];
    task.currentDirectoryPath = latexScriptPath.stringByDeletingLastPathComponent;

    [logString appendFormat:@"----------------- %@ script -----------------\n", NSLocalizedString(@"executing", @"executing")];
    [logString appendFormat:@"%@\n", [task equivalentLaunchCommand]];

    @try {
      [task setTimeOut:30];
      [task launch];
      [task waitUntilExit];
      if (task.hasReachedTimeout)
        [logString appendFormat:@"\n%@\n\n", NSLocalizedString(@"Script too long : timeout reached",
                                                               @"Script too long : timeout reached")];
      else if (task.terminationStatus)
      {
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"Script failed")];
        NSString* outputLog1 = [[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding];
        NSString* outputLog2 = [[NSString alloc] initWithData:[task dataForStdError]  encoding:encoding];
        [logString appendFormat:@"%@\n%@\n----------------------------------------------------\n", outputLog1, outputLog2];
      }
      else
      {
        NSString* outputLog = [[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding];
        [logString appendFormat:@"\n%@\n----------------------------------------------------\n", outputLog];
      }
    }//end try task
    @catch(NSException* e) {
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"Script failed")];
        NSString* outputLog = [[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding];
        [logString appendFormat:@"%@\n----------------------------------------------------\n", outputLog];
    }
  }//end if (source != SCRIPT_SOURCE_NONE)
}
//end executeScript:setEnvironment:logString:workingDirectory:uniqueIdentifier:compositionConfiguration:

//returns a file icon to represent the given PDF data; if not specified (nil), the backcground color will be half-transparent
-(NSImage*) makeIconForData:(NSData*)pdfData backgroundColor:(NSColor*)backgroundColor
{
  NSImage* icon = nil;
  NSImage* image = [[NSImage alloc] initWithData:pdfData];
  NSSize imageSize = image.size;
  icon = [[NSImage alloc] initWithSize:NSMakeSize(128, 128)];
  NSRect imageRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);
  NSRect srcRect = imageRect;
  CGFloat maxAspectRatio = 5;
  if (imageRect.size.width >= imageRect.size.height)
    srcRect.size.width = MIN(srcRect.size.width, maxAspectRatio*srcRect.size.height);
  else
    srcRect.size.height = MIN(srcRect.size.height, maxAspectRatio*srcRect.size.width);
  srcRect.origin.y = imageSize.height-srcRect.size.height;

  CGFloat marginX = (srcRect.size.height > srcRect.size.width ) ? ((srcRect.size.height - srcRect.size.width )/2)*128/srcRect.size.height : 0;
  CGFloat marginY = (srcRect.size.width  > srcRect.size.height) ? ((srcRect.size.width  - srcRect.size.height)/2)*128/srcRect.size.width  : 0;
  NSRect dstRect = NSMakeRect(marginX, marginY, 128-2*marginX, 128-2*marginY);
  if (!backgroundColor)
    backgroundColor = [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:1.0];
  @try
  {
    [icon lockFocus];
      [backgroundColor set];
      NSRectFill(NSMakeRect(0, 0, 128, 128));
      [image drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1];
      if (imageSize.width > maxAspectRatio*imageSize.height) //if the equation is truncated, adds <...>
      {
        NSRectFill(NSMakeRect(100, 0, 28, 128));
        [[NSColor blackColor] set];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(102, 56, 6, 6)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(112, 56, 6, 6)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(122, 56, 6, 6)] fill];
      }
      else if (imageSize.height > maxAspectRatio*imageSize.width)
      {
        NSRectFill(NSMakeRect(0, 0, 128, 16));
        [[NSColor blackColor] set];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(51, 5, 6, 6)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(61, 5, 6, 6)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(71, 5, 6, 6)] fill];
      }
    [icon unlockFocus];
  }
  @catch(NSException* e)//may occur if lockFocus fails
  {
  }
  return icon;
}
//end makeIconForData:backgroundColor:

-(void) displayAlertError:(id)object
{
  NSDictionary* objects = [object dynamicCastToClass:[NSDictionary class]];
  NSString* informativeText1 = [[objects objectForKey:@"informativeText1"] dynamicCastToClass:[NSString class]];
  DebugLog(1, @"displayAlertError:informativeText1:<%@>", informativeText1);
  NSAlert* alert = [NSAlert new];
  alert.messageText = NSLocalizedString(@"Error", @"Error");
  [alert setInformativeText:!informativeText1 ? @"" : informativeText1];
  [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
  [alert addButtonWithTitle:NSLocalizedString(@"Display the error message", @"Display the error message")];
  [alert setAlertStyle:NSCriticalAlertStyle];
  NSInteger displayError = [alert runModal];
  if (displayError == NSAlertSecondButtonReturn)
  {
    NSString* informativeText2 = [[objects objectForKey:@"informativeText2"] dynamicCastToClass:[NSString class]];
    DebugLog(1, @"displayAlertError:informativeText2:<%@>", informativeText2);
    NSAlert* alert2 = [NSAlert new];
    alert2.messageText = NSLocalizedString(@"Error message", @"Error message");
    [alert2 setInformativeText:!informativeText2 ? @"" : informativeText2];
    [alert2 addButtonWithTitle:NSLocalizedString(@"OK", @"OK")];
    [alert2 setAlertStyle:NSInformationalAlertStyle];
    [alert2 runModal];
  }//end if (displayError == NSAlertSecondButtonReturn)
}
//end displayAlertError:

//returns data representing data derived from pdfData, but in the format specified (pdf, eps, tiff, png...)
-(NSData*) dataForType:(export_format_t)format pdfData:(NSData*)pdfData
             exportOptions:(NSDictionary*)exportOptions
             compositionConfiguration:(NSDictionary*)compositionConfiguration
             uniqueIdentifier:(NSString*)uniqueIdentifier
{
  NSData* data = nil;
  NSString* temporaryDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
  //@synchronized(self) //only one person may ask that service at a time //now using uniqueidentifier to allow thread safety
  {
    //prepare file names
    NSString* filePrefix     = [NSString stringWithFormat:@"latexit-controller-%@", uniqueIdentifier];
    NSString* pdfFile        = [NSString stringWithFormat:@"%@.pdf", filePrefix];
    NSString* pdfFilePath    = [temporaryDirectory stringByAppendingPathComponent:pdfFile];
    NSString* tmpEpsFile     = [NSString stringWithFormat:@"%@-2.eps", filePrefix];
    NSString* tmpEpsFilePath = [temporaryDirectory stringByAppendingPathComponent:tmpEpsFile];
    NSString* tmpPdfFile     = [NSString stringWithFormat:@"%@-2.pdf", filePrefix];
    NSString* tmpPdfFilePath = [temporaryDirectory stringByAppendingPathComponent:tmpPdfFile];
    NSString* tmpSvgFile     = [NSString stringWithFormat:@"%@-2.svg", filePrefix];
    NSString* tmpSvgFilePath = [temporaryDirectory stringByAppendingPathComponent:tmpSvgFile];
    
    NSColor* jpegColor = [exportOptions[@"jpegColor"] dynamicCastToClass:[NSColor class]];
    float jpegQuality = [[exportOptions[@"jpegQuality"] dynamicCastToClass:[NSNumber class]] floatValue];
    CGFloat scaleAsPercent = [[exportOptions[@"scaleAsPercent"] dynamicCastToClass:[NSNumber class]] doubleValue];
    BOOL exportIncludeBackgroundColor = [[[exportOptions objectForKey:@"exportIncludeBackgroundColor"] dynamicCastToClass:[NSNumber class]] boolValue];
    BOOL textExportPreamble = [[exportOptions[@"textExportPreamble"] dynamicCastToClass:[NSNumber class]] boolValue];
    BOOL textExportEnvironment = [[exportOptions[@"textExportEnvironment"] dynamicCastToClass:[NSNumber class]] boolValue];
    BOOL textExportBody = [[exportOptions[@"textExportBody"] dynamicCastToClass:[NSNumber class]] boolValue];
    
    if (pdfData)
    {
      NSDictionary* equationMetaData = [LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0];
      NSColor* backgroundColor = [equationMetaData objectForKey:@"backgroundColor"];
      
      PreferencesController* preferencesController = [PreferencesController sharedController];
      BOOL annotationsGraphicCommandsInvisibleEnabled =
        (format == EXPORT_FORMAT_PDF) ? [preferencesController exportPDFMetaDataInvisibleGraphicsEnabled] :
        (format == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) ? [preferencesController exportPDFWOFMetaDataInvisibleGraphicsEnabled] :
        NO;
      BOOL shouldRecreatePDF =
        (annotationsGraphicCommandsInvisibleEnabled && ![LatexitEquation hasInvisibleGraphicCommandsInPDFData:pdfData]) ||
        (backgroundColor && exportIncludeBackgroundColor) ||
        (scaleAsPercent != 100);
      if (shouldRecreatePDF)
      {
        CGDataProviderRef pdfOriginalDataProvider = !pdfData ? 0 : CGDataProviderCreateWithCFData((CFDataRef)pdfData);
        CGPDFDocumentRef pdfOriginalDocument = !pdfOriginalDataProvider ? 0 : CGPDFDocumentCreateWithProvider(pdfOriginalDataProvider);
        CGPDFPageRef pdfOriginalPage = !pdfOriginalDocument ? 0 : CGPDFDocumentGetPage(pdfOriginalDocument, 1);
        //CGRect pdfOriginalMediaBox = !pdfOriginalPage ? CGRectZero : CGPDFPageGetBoxRect(pdfOriginalPage, kCGPDFMediaBox);
        CGRect pdfOriginalCropBox = !pdfOriginalPage ? CGRectZero : CGPDFPageGetBoxRect(pdfOriginalPage, kCGPDFCropBox);
        CGRect pdfOriginalBox = pdfOriginalCropBox;
        
        NSMutableData* pdfScaledMutableData = [NSMutableData data];
        CGDataConsumerRef pdfScaledDataConsumer = !pdfScaledMutableData ? 0 :
          CGDataConsumerCreateWithCFData((CFMutableDataRef)pdfScaledMutableData);
        CGRect pdfScaledMediaBox = (scaleAsPercent == 100) ? pdfOriginalBox :
          CGRectMake(0, 0,
            ceil((scaleAsPercent/100)*pdfOriginalBox.size.width),
            ceil((scaleAsPercent/100)*pdfOriginalBox.size.height));
        CGContextRef pdfContext = !pdfScaledDataConsumer ? 0 : CGPDFContextCreate(pdfScaledDataConsumer, &pdfScaledMediaBox, 0);
        CGPDFContextBeginPage(pdfContext, 0);
        if (backgroundColor && exportIncludeBackgroundColor)
        {
          CGFloat backgroundColorRgba[4] = {0};
          [backgroundColor getRed:&backgroundColorRgba[0] green:&backgroundColorRgba[1] blue:&backgroundColorRgba[2] alpha:&backgroundColorRgba[3]];
          CGContextSetRGBFillColor(pdfContext, backgroundColorRgba[0], backgroundColorRgba[1], backgroundColorRgba[2], backgroundColorRgba[3]);
          CGContextFillRect(pdfContext, pdfScaledMediaBox);
        }//end if (backgroundColor && exportIncludeBackgroundColor)
        CGContextScaleCTM(pdfContext,
          !pdfOriginalBox.size.width ? 1 : pdfScaledMediaBox.size.width/pdfOriginalBox.size.width,
          !pdfOriginalBox.size.height ? 1 : pdfScaledMediaBox.size.height/pdfOriginalBox.size.height);
        CGContextTranslateCTM(pdfContext, -pdfOriginalBox.origin.x, -pdfOriginalBox.origin.y);
        CGContextDrawPDFPage(pdfContext, pdfOriginalPage);
        CGContextEndPage(pdfContext);
        CGContextFlush(pdfContext);
        CGContextRelease(pdfContext);
        CGDataConsumerRelease(pdfScaledDataConsumer);
       
       CGPDFDocumentRelease(pdfOriginalDocument);
       CGDataProviderRelease(pdfOriginalDataProvider);
       
       NSData* resizedPdfData = [pdfScaledMutableData copy];
        
        /*NSPDFImageRep* pdfImageRep = [[NSPDFImageRep alloc] initWithData:pdfData];
        NSSize originalSize = [pdfImageRep size];
        NSImage* pdfImage = [[NSImage alloc] initWithSize:originalSize];
        pdfImage.cacheMode = NSImageCacheNever;
        [pdfImage addRepresentation:pdfImageRep];
        NSImageView* imageView =
          [[NSImageView alloc] initWithFrame:
            NSMakeRect(0, 0, ceil(originalSize.width*scaleAsPercent/100), ceil(originalSize.height*scaleAsPercent/100))];
        imageView.imageScaling = NSImageScaleAxesIndependently;
        imageView.image = pdfImage;
        NSData* resizedPdfData = [imageView dataWithPDFInsideRect:[imageView bounds]];*/
                          
        pdfData =
          [self annotatePdfDataInLEEFormat:resizedPdfData exportFormat:format
            preamble:[[equationMetaData objectForKey:@"preamble"] string]
            source:[[equationMetaData objectForKey:@"sourceText"] string]
            color:[equationMetaData objectForKey:@"color"]
            mode:[[equationMetaData objectForKey:@"mode"] integerValue]
            magnification:[[equationMetaData objectForKey:@"magnification"] doubleValue]
            baseline:[[equationMetaData objectForKey:@"baseline"] doubleValue]
            backgroundColor:[equationMetaData objectForKey:@"backgroundColor"]
            title:[equationMetaData objectForKey:@"title"]
            annotateWithTransparentData:annotationsGraphicCommandsInvisibleEnabled];
        
        if (pdfData)
        {
          //in the meta-data of the PDF we store as much info as we can : preamble, body, size, color, mode, baseline...
          PDFDocument* pdfDocument = nil;
          @try{
            pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
            NSDictionary* attributes =
              @{PDFDocumentCreatorAttribute: [[NSWorkspace sharedWorkspace] applicationName]};
            pdfDocument.documentAttributes = attributes;
            pdfData = [pdfDocument dataRepresentation];
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
        }//end if (pdfData && !shouldDenyDueTo64Bitsproblem)

        #ifdef ARC_ENABLED
        #else
        /*[imageView release];
        [pdfImage release];
        [pdfImageRep release];*/
        #endif
      }//end if (shouldRecreatePDF)
      
      BOOL      useLoginShell    = [compositionConfiguration compositionConfigurationUseLoginShell];
      NSString* gsPath           = [compositionConfiguration compositionConfigurationProgramPathGs];
      NSArray*  gsArguments      = [compositionConfiguration compositionConfigurationProgramArgumentsGs];
      NSString* psToPdfPath      = [compositionConfiguration compositionConfigurationProgramPathPsToPdf];
      NSArray*  psToPdfArguments = [compositionConfiguration compositionConfigurationProgramArgumentsPsToPdf];
      NSString* pdf2svgPath      = [preferencesController exportSvgPdfToSvgPath];
    
      if (format == EXPORT_FORMAT_PDF)
      {
        data = pdfData;
        BOOL reannotate = NO;
        NSDictionary* metaData = !reannotate ? nil : [LatexitEquation metaDataFromPDFData:data useDefaults:NO outPdfData:nil];
        if (metaData)
        {
          NSAttributedString* preamble = [metaData[@"preamble"] dynamicCastToClass:[NSAttributedString class]];
          NSAttributedString* sourceText = [metaData[@"sourceText"] dynamicCastToClass:[NSAttributedString class]];
          NSColor* color = [metaData[@"color"] dynamicCastToClass:[NSColor class]];
          NSColor* backgroundColor = [metaData[@"backgroundColor"] dynamicCastToClass:[NSColor class]];
          NSNumber* mode = [metaData[@"mode"] dynamicCastToClass:[NSNumber class]];
          NSNumber* magnification = [metaData[@"magnification"] dynamicCastToClass:[NSNumber class]]; 
          NSString* title = [metaData[@"title"] dynamicCastToClass:[NSString class]];
          data = [self stripPdfData:data];
          data = [[LaTeXProcessor sharedLaTeXProcessor] annotatePdfDataInLEEFormat:data
                                                                      exportFormat:format
                                                                          preamble:[preamble string]
                                                                            source:[sourceText string]
                                                                             color:color mode:(latex_mode_t)[mode integerValue]
                                                                     magnification:[magnification doubleValue]
                                                                          baseline:0
                                                                   backgroundColor:backgroundColor title:title
                                                       annotateWithTransparentData:annotationsGraphicCommandsInvisibleEnabled];
        }//end if (metaData)
        /*CGDataProviderRef pdfOriginalDataProvider = !pdfData ? 0 :
          CGDataProviderCreateWithCFData((CFDataRef)pdfData);
        CGPDFDocumentRef pdfOriginalDocument = !pdfOriginalDataProvider ? 0 :
          CGPDFDocumentCreateWithProvider(pdfOriginalDataProvider);
        CGPDFPageRef pdfOriginalPage = !pdfOriginalDocument ? 0 :
          CGPDFDocumentGetPage(pdfOriginalDocument, 1);
        CGRect pdfOriginalMediaBox = !pdfOriginalPage ? CGRectZero :
          CGPDFPageGetBoxRect(pdfOriginalPage, kCGPDFMediaBox);
        CGRect pdfOriginalCropBox = !pdfOriginalPage ? CGRectZero :
        CGPDFPageGetBoxRect(pdfOriginalPage, kCGPDFCropBox);
        
        NSMutableData* pdfCroppedMutableData = [NSMutableData data];
        CGDataConsumerRef pdfCroppedDataConsumer = !pdfCroppedMutableData ? 0 :
          CGDataConsumerCreateWithCFData((CFMutableDataRef)pdfCroppedMutableData);
        CGRect pdfCroppedMediaBox =
          CGRectMake(0, 0,
                     ceil(pdfOriginalMediaBox.size.width),
                     ceil(pdfOriginalMediaBox.size.height));
        CGContextRef pdfContext = !pdfCroppedDataConsumer ? 0 :
          CGPDFContextCreate(pdfCroppedDataConsumer, &pdfCroppedMediaBox, 0);
        CGPDFContextBeginPage(pdfContext, 0);
        CGContextTranslateCTM(pdfContext, -pdfOriginalMediaBox.origin.x, -pdfOriginalMediaBox.origin.y);
        CGContextDrawPDFPage(pdfContext, pdfOriginalPage);
        CGContextEndPage(pdfContext);
        CGContextFlush(pdfContext);
        CGContextRelease(pdfContext);
        CGDataConsumerRelease(pdfCroppedDataConsumer);
        
        CGPDFDocumentRelease(pdfOriginalDocument);
        CGDataProviderRelease(pdfOriginalDataProvider);

        data = [[pdfCroppedMutableData copy] autorelease];*/
      }//end if (format == EXPORT_FORMAT_PDF)
      else if (format == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      {
        [pdfData writeToFile:pdfFilePath atomically:NO];
        if (gsPath && ![gsPath isEqualToString:@""] && psToPdfPath && ![psToPdfPath isEqualToString:@""])
        {
          NSString* tmpFilePath = nil;
          NSFileHandle* tmpFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"export.XXXXXXXX" extension:@"log" outFilePath:&tmpFilePath
                                                                                workingDirectory:temporaryDirectory];
          if (!tmpFilePath)
            tmpFilePath = @"/dev/null";
          PreferencesController* preferencesController = [PreferencesController sharedController];
          NSString* writeEngine = preferencesController.exportPDFWOFGsWriteEngine;
          NSString* compatibilityLevel = preferencesController.exportPDFWOFGsPDFCompatibilityLevel;
          NSString* systemCall =
            [NSString stringWithFormat:
              @"%@ -sstdout=%%stderr -sDEVICE=%@ -dNOCACHE -sOutputFile=- -q -dbatch -dNOPAUSE -dSAFER -dNOPLATFONTS -dNoOutputFonts=true %@ -c quit 2>|%@ | %@  -dSubsetFonts=false -dEmbedAllFonts=true -dDEVICEWIDTHPOINTS=100000 -dDEVICEHEIGHTPOINTS=100000 -dPDFSETTINGS=/prepress -dCompatibilityLevel=%@ %@ - %@ 1>>%@ 2>&1",
              //@"%@ -sstdout=%stderr -sDEVICE=epswrite -dNOCACHE -sOutputFile=- -q -dbatch -dNOPAUSE -dSAFER -dNOPLATFONTS %@ -c quit 2>|%@ | %@  -dSubsetFonts=false -dEmbedAllFonts=true -dDEVICEWIDTHPOINTS=100000 -dDEVICEHEIGHTPOINTS=100000 -dPDFSETTINGS=/prepress -dCompatibilityLevel=%@ %@ - %@ 1>>%@ 2>&1",
              gsPath,
             writeEngine,
             pdfFilePath, tmpFilePath, psToPdfPath,
             compatibilityLevel,
             [psToPdfArguments componentsJoinedByString:@" "], tmpPdfFilePath, tmpFilePath];
          DebugLog(1, @"command <%@>", systemCall);
          int error = system(systemCall.UTF8String);
          if (error)
          {
            NSString* output = [[NSString alloc] initWithData:tmpFileHandle.availableData encoding:NSUTF8StringEncoding];
            NSString* formatString1 = NSLocalizedString(@"An error occured while trying to create the file with command:\n%@", @"");
            DebugLog(1, @"formatString1 = %@", formatString1);
            NSString* informativeText1 = [NSString stringWithFormat:formatString1, systemCall];
            DebugLog(1, @"informativeText1 = %@", informativeText1);
            NSString* informativeText2 = [NSString stringWithFormat:@"%@ %d:\n%@", NSLocalizedString(@"Error", @"Error"), error, !output ? @"..." : output];
            DebugLog(1, @"informativeText2 = %@", informativeText2);
            NSDictionary* alertInformation = @{@"informativeText1": informativeText1,
              @"informativeText2": informativeText2};
            NSMutableDictionary* alertInformationWrapper =
              [exportOptions[@"alertInformationWrapper"] dynamicCastToClass:[NSMutableDictionary class]];
            if (alertInformationWrapper)
              alertInformationWrapper[@"alertInformation"] = alertInformation;
            else
              [self performSelectorOnMainThread:@selector(displayAlertError:)
                                     withObject:alertInformation
                                  waitUntilDone:YES];
            unlink(tmpFilePath.fileSystemRepresentation);
          }//end if (error)
          else//if (!error)
          {
            CGDataProviderRef pdfOriginalDataProvider = !pdfData ? 0 :
              CGDataProviderCreateWithCFData((CFDataRef)pdfData);
            CGPDFDocumentRef pdfOriginalDocument = !pdfOriginalDataProvider ? 0 :
              CGPDFDocumentCreateWithProvider(pdfOriginalDataProvider);
            CGPDFPageRef pdfOriginalPage = !pdfOriginalDocument ? 0 :
              CGPDFDocumentGetPage(pdfOriginalDocument, 1);
            CGRect pdfOriginalMediaBox = !pdfOriginalPage ? CGRectZero :
              CGPDFPageGetBoxRect(pdfOriginalPage, kCGPDFMediaBox);
            CGRect pdfOriginalBoundingBox =
              NSRectToCGRect([self computeBoundingBox:pdfFilePath workingDirectory:temporaryDirectory fullEnvironment:[self fullEnvironment] compositionConfiguration:compositionConfiguration outFullLog:nil]);
            CGPDFDocumentRelease(pdfOriginalDocument);
            CGDataProviderRelease(pdfOriginalDataProvider);
            
            LatexitEquation* latexitEquation = [LatexitEquation latexitEquationWithPDFData:pdfData useDefaults:YES];
            
            [self crop:tmpPdfFilePath to:tmpPdfFilePath canClip:YES extraArguments:@[]
              compositionConfiguration:compositionConfiguration workingDirectory:temporaryDirectory environment:self->globalExtraEnvironment outFullLog:nil outPdfData:&pdfData];
            data = [NSData dataWithContentsOfFile:tmpPdfFilePath options:NSUncachedRead error:nil];

            CGDataProviderRef pdfUncroppedDataProvider = !data ? 0 :
              CGDataProviderCreateWithCFData((CFDataRef)data);
            CGPDFDocumentRef pdfUncroppedDocument = !pdfUncroppedDataProvider ? 0 :
              CGPDFDocumentCreateWithProvider(pdfUncroppedDataProvider);
            CGPDFPageRef pdfUncroppedPage = !pdfUncroppedDocument ? 0 :
              CGPDFDocumentGetPage(pdfUncroppedDocument, 1);
            
            NSMutableData* pdfCroppedMutableData = [NSMutableData data];
            CGDataConsumerRef pdfCroppedDataConsumer = !pdfCroppedMutableData ? 0 :
              CGDataConsumerCreateWithCFData((CFMutableDataRef)pdfCroppedMutableData);
            CGRect pdfCroppedMediaBox =
              CGRectMake(0, 0,
                         ceil(pdfOriginalMediaBox.size.width),
                         ceil(pdfOriginalMediaBox.size.height));
            CGContextRef pdfContext = !pdfCroppedDataConsumer ? 0 :
              CGPDFContextCreate(pdfCroppedDataConsumer, &pdfCroppedMediaBox, 0);
            CGPDFContextBeginPage(pdfContext, 0);
            CGContextTranslateCTM(pdfContext,
              pdfOriginalBoundingBox.origin.x-pdfOriginalMediaBox.origin.x,
              pdfOriginalBoundingBox.origin.y-pdfOriginalMediaBox.origin.y);
            CGContextDrawPDFPage(pdfContext, pdfUncroppedPage);
            CGContextEndPage(pdfContext);
            CGContextFlush(pdfContext);
            CGContextRelease(pdfContext);
            CGDataConsumerRelease(pdfCroppedDataConsumer);
            CGPDFDocumentRelease(pdfUncroppedDocument);
            CGDataProviderRelease(pdfUncroppedDataProvider);
            
            data = [[LaTeXProcessor sharedLaTeXProcessor] annotatePdfDataInLEEFormat:pdfCroppedMutableData
                                       exportFormat:format
                                           preamble:latexitEquation.preamble.string
                                             source:latexitEquation.sourceText.string
                                              color:latexitEquation.color mode:latexitEquation.mode
                                      magnification:latexitEquation.pointSize
                                           baseline:0
                                    backgroundColor:latexitEquation.backgroundColor title:latexitEquation.title
                                    annotateWithTransparentData:annotationsGraphicCommandsInvisibleEnabled];
          }//end if (!error)
          [[NSFileManager defaultManager] removeItemAtPath:tmpFilePath error:0];
        }//if (gsPath && ![gsPath isEqualToString:@""] && psToPdfPath && ![psToPdfPath isEqualToString:@""])
        [[NSFileManager defaultManager] removeItemAtPath:pdfFilePath error:0];
        [[NSFileManager defaultManager] removeItemAtPath:tmpPdfFilePath error:0];
      }//end if (format == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      else if (format == EXPORT_FORMAT_EPS)
      {
        BOOL isGS915OrAbove = (compareVersions(@"9.15", [self getGSVersion:compositionConfiguration]) != NSOrderedDescending);
        [pdfData writeToFile:pdfFilePath atomically:NO];
        SystemTask* gsTask = [[SystemTask alloc] initWithWorkingDirectory:temporaryDirectory];
        NSMutableString* errorString = [NSMutableString string];
        @try
        {
          gsTask.usingLoginShell = useLoginShell;
          gsTask.currentDirectoryPath = temporaryDirectory;
          gsTask.environment = self->globalExtraEnvironment;
          gsTask.launchPath = gsPath;
          gsTask.arguments = [gsArguments arrayByAddingObjectsFromArray:
            @[@"-sstdout=%stderr -dNOPAUSE", @"-dNOCACHE", @"-dBATCH", @"-dSAFER", @"-dNOPLATFONTS",
               [NSString stringWithFormat:@"-sDEVICE=%@", isGS915OrAbove ? @"eps2write" : @"epswrite"],
               [NSString stringWithFormat:@"-sOutputFile=%@", tmpEpsFilePath], pdfFilePath]];
          [gsTask launch];
          [gsTask waitUntilExit];
        }
        @catch(NSException* e)
        {
          [errorString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", e.name, e.reason]];
        }
        @finally
        {
          NSData* errorData = [gsTask dataForStdError];
          [errorString appendString:[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding]];

          if (gsTask.terminationStatus != 0)
          {
            NSAlert *alert = [NSAlert new];
            alert.messageText = NSLocalizedString(@"Error", @"Error");
            alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file :\n%@",
                                                                                 @"An error occured while trying to create the file :\n%@"), errorString];
            [alert runModal];
          }
        }
        data = [NSData dataWithContentsOfFile:tmpEpsFilePath options:NSUncachedRead error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:tmpEpsFilePath error:0];
        [[NSFileManager defaultManager] removeItemAtPath:pdfFilePath error:0];
        DebugLog(1, @"create EPS data %p (%ld)", data, (unsigned long)[data length]);
      }//end if (format == EXPORT_FORMAT_EPS)
      else if (format == EXPORT_FORMAT_TIFF)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = image.TIFFRepresentation;
        NSData* annotationData =
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:(NSString*)kUTTypeTIFF withData:annotationDataCompressed];
        DebugLog(1, @"create TIFF data %p (%ld)", data, (unsigned long)[data length]);
      }//end if (format == EXPORT_FORMAT_TIFF)
      else if (format == EXPORT_FORMAT_PNG)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:15.0];
        NSBitmapImageRep* imageRep = [NSBitmapImageRep imageRepWithData:data];
    data = [imageRep representationUsingType:NSPNGFileType properties:@{}];
        NSData* annotationData =
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:(NSString*)kUTTypePNG withData:annotationDataCompressed];
        DebugLog(1, @"create PNG data %p (%ld)", data, (unsigned long)[data length]);
      }//end if (format == EXPORT_FORMAT_PNG)
      else if (format == EXPORT_FORMAT_JPEG)
      {
        CGDataProviderRef pdfDataProvider = !pdfData ? 0 :
          CGDataProviderCreateWithCFData((CFDataRef)pdfData);
        CGPDFDocumentRef pdfDocument = !pdfDataProvider ? 0 :
          CGPDFDocumentCreateWithProvider(pdfDataProvider);
        CGPDFPageRef pdfPage = !pdfDocument || !CGPDFDocumentGetNumberOfPages(pdfDocument) ? 0 :
          CGPDFDocumentGetPage(pdfDocument, 1);
        CGRect mediaBox = !pdfPage ? CGRectZero :
          CGPDFPageGetBoxRect(pdfPage, kCGPDFMediaBox);
        NSUInteger width = round(mediaBox.size.width);
        NSUInteger height = round(mediaBox.size.height);
        NSUInteger bytesPerRow = 16*((4*width+15)/16);
        NSUInteger bitmapBytesLength = bytesPerRow*height;
        void* bytes = isMacOS10_6OrAbove() ? 0 : calloc(bitmapBytesLength, sizeof(unsigned char));
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef cgContext = !colorSpace || !bytesPerRow || (!bytes && !isMacOS10_6OrAbove()) ? 0 :
          CGBitmapContextCreate(bytes, width, height, 8, !bytes ? 0 : bytesPerRow, colorSpace, kCGImageAlphaPremultipliedLast);
        CGImageRef cgImage = 0;
        if (cgContext)
        {
          NSColor* rgbColor = [jpegColor colorUsingColorSpaceName:NSDeviceRGBColorSpace];
          CGContextSetRGBFillColor(cgContext,
            rgbColor.redComponent, rgbColor.greenComponent, rgbColor.blueComponent, rgbColor.alphaComponent);
          CGContextFillRect(cgContext, CGRectMake(0, 0, width, height));
          CGContextDrawPDFPage(cgContext, pdfPage);
          CGContextFlush(cgContext);
          cgImage = CGBitmapContextCreateImage(cgContext);
          CGContextRelease(cgContext);
        }//end if (cgContext)
        if (bytes)
        {
          free(bytes);
          bytes = 0;
        }//end if (bytes)
        CGColorSpaceRelease(colorSpace);
        CGPDFDocumentRelease(pdfDocument);
        CGDataProviderRelease(pdfDataProvider);

        NSMutableData* mutableData = !cgImage ? nil : [NSMutableData data];
        CGImageDestinationRef cgImageDestination = !mutableData ? 0 : CGImageDestinationCreateWithData(
          (__bridge CFMutableDataRef)mutableData, kUTTypeJPEG, 1, 0);
        if (cgImageDestination && cgImage)
        {
          CGImageDestinationAddImage(cgImageDestination, cgImage,
            (__bridge CFDictionaryRef)@{(NSString*)kCGImageDestinationLossyCompressionQuality: @(jpegQuality/100.0f)});
          CGImageDestinationFinalize(cgImageDestination);
          CFRelease(cgImageDestination);
        }//end if (cgImageDestination && cgImage)
        CGImageRelease(cgImage);

        data = mutableData;
        NSData* annotationData =
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:(NSString*)kUTTypeJPEG withData:annotationDataCompressed];
        DebugLog(1, @"create JPEG data %p (%ld)", data, (unsigned long)[data length]);
      }//end if (format == EXPORT_FORMAT_JPEG)
      else if (format == EXPORT_FORMAT_SVG)
      {
        [pdfData writeToFile:pdfFilePath atomically:NO];
        SystemTask* svgTask = [[SystemTask alloc] initWithWorkingDirectory:temporaryDirectory];
        NSMutableString* errorString = [NSMutableString string];
        @try
        {
          svgTask.usingLoginShell = useLoginShell;
          svgTask.currentDirectoryPath = temporaryDirectory;
          svgTask.environment = self->globalExtraEnvironment;
          svgTask.launchPath = pdf2svgPath;
          svgTask.arguments = @[pdfFilePath, tmpSvgFilePath];
          [svgTask launch];
          [svgTask waitUntilExit];
        }
        @catch(NSException* e)
        {
          [errorString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", e.name, e.reason]];
        }
        @finally
        {
          NSData* errorData = [svgTask dataForStdError];
          [errorString appendString:[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding]];

          if (svgTask.terminationStatus != 0)
          {
            NSAlert *alert = [NSAlert new];
            alert.messageText = NSLocalizedString(@"Error", @"Error");
            alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file :\n%@",
                                                                                 @"An error occured while trying to create the file :\n%@"), errorString];
            [alert runModal];
          }//end if ([svgTask terminationStatus] != 0)
        }
        data = [NSData dataWithContentsOfFile:tmpSvgFilePath options:NSUncachedRead error:nil];
        NSData* annotationData =
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:(NSString*)kUTTypeScalableVectorGraphics withData:annotationDataCompressed];
        [[NSFileManager defaultManager] removeItemAtPath:tmpSvgFilePath error:0];
      }//end if (format == EXPORT_FORMAT_SVG)
      else if (format == EXPORT_FORMAT_MATHML)
      {
        NSDictionary* metaData = [LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0];
        NSAttributedString* sourceText = [metaData objectForKey:@"sourceText"];
        latex_mode_t latexMode = (latex_mode_t)[[metaData objectForKey:@"mode"] integerValue];
        NSString* addSymbolLeft  =
          (latexMode == LATEX_MODE_ALIGN) ? @"$\\begin{eqnarray}\n" ://unfortunately, align is not supported
          (latexMode == LATEX_MODE_EQNARRAY) ? @"$\\begin{eqnarray}\n" :
          (latexMode == LATEX_MODE_DISPLAY) ? @"$\\displaystyle " :
          (latexMode == LATEX_MODE_INLINE) ? @"$" :
          @"";
        NSString* addSymbolRight =
          (latexMode == LATEX_MODE_ALIGN) ? @"\n\\end{eqnarray}$" ://unfortunately, align is not supported
          (latexMode == LATEX_MODE_EQNARRAY) ? @"\n\\end{eqnarray}$" :
          (latexMode == LATEX_MODE_DISPLAY) ? @"$" :
          (latexMode == LATEX_MODE_INLINE) ? @"$" :
          @"";
        NSString* sourceString = sourceText.string;
        NSString* escapedSourceString = [sourceString stringByReplacingOccurrencesOfRegex:@"&(?!amp;)" withString:@"&amp;"];
        NSColor* rgbaColor = [metaData[@"color"] colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
        CGFloat rgba_f[4] = {0};
        [rgbaColor getRed:&rgba_f[0] green:&rgba_f[1] blue:&rgba_f[2] alpha:&rgba_f[3]];
        int rgba_i[4] = {0};
        NSUInteger i = 0;
        for(i = 0 ; i<4 ; ++i)
          rgba_i[i] = MAX(0, MIN(255, round(255*rgba_f[i])));
        NSString* inputString = [NSString stringWithFormat:@"<body><blockquote style=\"color:rgba(%d,%d,%d,%d);color:rgb(%d,%d,%d);font-size:%.2fpt;\">%@%@%@</blockquote></body>",
          (int)rgba_i[0], (int)rgba_i[1], (int)rgba_i[2], (int)rgba_i[3],
          (int)rgba_i[0], (int)rgba_i[1], (int)rgba_i[2],
          [[metaData[@"magnification"] dynamicCastToClass:[NSNumber class]] doubleValue],
          addSymbolLeft, escapedSourceString, addSymbolRight];
        NSData* inputData = [inputString dataUsingEncoding:NSUTF8StringEncoding];
        NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
        NSString* inputFile = [workingDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"input-mathml-%@.html", uniqueIdentifier]];
        BOOL ok = [inputData writeToFile:inputFile atomically:YES];
        if (ok)
        {
          NSString* outputFile = [workingDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"output-mathml-%@.html", uniqueIdentifier]];
          NSDictionary* fullEnvironment  = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];
          NSString* laTeXMathMLPath  = [[NSBundle bundleForClass:[self class]] pathForResource:@"LaTeXMathML" ofType:@"pl"];
          NSMutableArray* arguments = [NSMutableArray arrayWithObjects:
            [NSString stringWithFormat:@"\"%@\"", laTeXMathMLPath], @"inputfile", inputFile, @"outputfile", outputFile, nil];
          SystemTask* laTeXMathMLTask = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
          BOOL useLoginShell = [compositionConfiguration compositionConfigurationUseLoginShell];
          laTeXMathMLTask.usingLoginShell = useLoginShell;
          laTeXMathMLTask.environment = fullEnvironment;
          laTeXMathMLTask.launchPath = @"perl";
          laTeXMathMLTask.arguments = arguments;
          laTeXMathMLTask.currentDirectoryPath = workingDirectory;
          [laTeXMathMLTask launch];
          [laTeXMathMLTask waitUntilExit];
          int terminationStatus = laTeXMathMLTask.terminationStatus;
          ok = (terminationStatus == 0);
          NSString* logStdOut = ok ? nil :
            [[NSString alloc] initWithData:[laTeXMathMLTask dataForStdOutput] encoding:NSUTF8StringEncoding];
          NSString* logStdErr = ok ? nil :
            [[NSString alloc] initWithData:[laTeXMathMLTask dataForStdError] encoding:NSUTF8StringEncoding];
          if (!ok)
          {
            DebugLog(1, @"command = %@", [laTeXMathMLTask commandLine]);
            DebugLog(1, @"terminationStatus = %d", terminationStatus);
            DebugLog(1, @"logStdOut = %@", logStdOut);
            DebugLog(1, @"logStdErr = %@", logStdErr);
          }//end if (!ok)
          data = [NSData dataWithContentsOfFile:outputFile];
          NSString* rawResult = !data ? nil : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
          NSString* fixedResult = !rawResult ? nil : mathMLFix(rawResult);
          data = !fixedResult ? data : [fixedResult dataUsingEncoding:NSUTF8StringEncoding];
          NSData* annotationData = [NSKeyedArchiver archivedDataWithRootObject:metaData];
          NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
          data = [self annotateData:data ofUTI:(NSString*)kUTTypeHTML withData:annotationDataCompressed];
          [[NSFileManager defaultManager] removeItemAtPath:outputFile error:0];
        }//end if (ok)
        [[NSFileManager defaultManager] removeItemAtPath:inputFile error:0];
      }//end if (format == EXPORT_FORMAT_MATHML)
      else if (format == EXPORT_FORMAT_TEXT)
      {
        NSDictionary* equationMetaData = [LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0];
        NSString* preamble = [equationMetaData[@"preamble"] string];
        NSString* source = [equationMetaData[@"sourceText"] string];
        latex_mode_t latexMode = (latex_mode_t)[equationMetaData[@"mode"] integerValue];
        NSString* addSymbolLeft  =
          (latexMode == LATEX_MODE_ALIGN) ? @"\\begin{align*}" :
          (latexMode == LATEX_MODE_EQNARRAY) ? @"\\begin{eqnarray*}" :
          (latexMode == LATEX_MODE_DISPLAY) ? @"\\[" :
          (latexMode == LATEX_MODE_INLINE) ? @"$" :
          @"";
        NSString* addSymbolRight =
          (latexMode == LATEX_MODE_ALIGN) ? @"\\end{align*}" :
          (latexMode == LATEX_MODE_EQNARRAY) ? @"\\end{eqnarray*}" :
          (latexMode == LATEX_MODE_DISPLAY) ? @"\\]" :
          (latexMode == LATEX_MODE_INLINE) ? @"$" :
          @"";
        NSMutableString* string = [NSMutableString string];
        if (textExportPreamble && preamble)
          [string appendString:preamble];
        if (textExportPreamble && (textExportEnvironment || textExportBody) && preamble && source)
          [string appendString:@"\\begin{document}\n"];
        if (textExportEnvironment && addSymbolLeft)
          [string appendString:addSymbolLeft];
        if (textExportBody && source)
          [string appendString:source];
        if (textExportEnvironment && addSymbolRight)
          [string appendString:addSymbolRight];
        if (textExportPreamble && (textExportEnvironment || textExportBody) && preamble && source)
          [string appendString:@"\n\\end{document}"];
        data = [string dataUsingEncoding:NSUTF8StringEncoding];
      }//end if (format == EXPORT_FORMAT_TEXT)
    }//end if pdfData available
  }//end @synchronized
  return data;
}
//end dataForType:pdfData:exportOptions:compositionConfiguration:uniqueIdentifier:

-(NSData*) annotateData:(NSData*)inputData ofUTI:(NSString*)sourceUTI withData:(NSData*)annotationData
{
  NSData* result = nil;
  if (inputData && annotationData)
  {
    if (!sourceUTI ||//may be guessed
        UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeTIFF) ||
        UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypePNG) ||
        UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeJPEG))
    {
      NSString* annotationDataBase64 = [annotationData encodeBase64];
      NSMutableData* annotatedData = !annotationDataBase64 ? nil : [[NSMutableData alloc] initWithCapacity:inputData.length];
      CGImageSourceRef imageSource = !annotatedData ? 0 :
        CGImageSourceCreateWithData((__bridge CFDataRef)inputData, (__bridge CFDictionaryRef)
          @{(NSString*)kCGImageSourceShouldCache: @NO});
      CFStringRef detectedUTI = !imageSource ? 0 : CGImageSourceGetType(imageSource);
      if (( sourceUTI && UTTypeConformsTo(detectedUTI, (__bridge CFStringRef)sourceUTI)) ||
          (!sourceUTI && (UTTypeConformsTo(detectedUTI, kUTTypeTIFF) ||
                          UTTypeConformsTo(detectedUTI, kUTTypePNG) ||
                          UTTypeConformsTo(detectedUTI, kUTTypeJPEG))))
      {
        CGImageDestinationRef imageDestination = !imageSource ? 0 :
          CGImageDestinationCreateWithData((__bridge CFMutableDataRef)annotatedData,
                                           sourceUTI ? (__bridge CFStringRef)sourceUTI : detectedUTI, 1, 0);
        NSDictionary* propertiesImmutable = nil;
        NSMutableDictionary* properties = nil;
        if (imageSource && imageDestination)
        {
          propertiesImmutable = (NSDictionary*)CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, 0));
          properties = [propertiesImmutable deepMutableCopy];
          NSMutableDictionary* exifDictionary = properties[(NSString*)kCGImagePropertyExifDictionary];
          if (!exifDictionary)
          {
            exifDictionary = [NSMutableDictionary dictionaryWithCapacity:1];
            properties[(NSString*)kCGImagePropertyExifDictionary] = exifDictionary;
          }//end if (!exifDictionary)
          exifDictionary[(NSString*)kCGImagePropertyExifUserComment] = annotationDataBase64;
        }//if (imageSource && imageDestination)
        DebugLog(1, @"properties = %@", properties);
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, (CHBRIDGE CFDictionaryRef)properties);
        if (imageDestination)
          CGImageDestinationFinalize(imageDestination);
        if (imageDestination)
          CFRelease(imageDestination);
      }//end if (UTTypeConformsTo(detectedUTI, sourceUTI))
      if (imageSource)
        CFRelease(imageSource);
      if (annotatedData)
        result = [annotatedData copy];
    }//end if (tiff, png, jpeg)
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeScalableVectorGraphics))
    {
      NSString* annotationDataBase64 = [annotationData encodeBase64];
      NSMutableString* outputString = !annotationDataBase64 ? nil :
        [[NSMutableString alloc] initWithData:inputData encoding:NSUTF8StringEncoding];
      NSError* error = nil;
      [outputString
         replaceOccurrencesOfRegex:@"<svg(.*?)>(.*)</svg>"
         withString:[NSString stringWithFormat:@"<svg$1><!--latexit:%@-->$2</svg>", annotationDataBase64]
         options:RKLCaseless|RKLDotAll|RKLMultiline range:NSMakeRange(0, outputString.length) error:&error];
      if (error)
        DebugLog(0, @"error : %@", error);
      result = !outputString ? nil : [outputString dataUsingEncoding:NSUTF8StringEncoding];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeScalableVectorGraphics))
    else if (UTTypeConformsTo((__bridge CFStringRef)sourceUTI, kUTTypeHTML))
    {
      NSString* annotationDataBase64 = [annotationData encodeBase64];
      NSMutableString* outputString = !annotationDataBase64 ? nil :
        [[NSMutableString alloc] initWithData:inputData encoding:NSUTF8StringEncoding];
      NSError* error = nil;
      [outputString replaceOccurrencesOfRegex:@"<blockquote(.*?)>(.*?)</blockquote>"
         withString:[NSString stringWithFormat:@"<blockquote$1><!--latexit:%@-->$2</blockquote>", annotationDataBase64]
            options:RKLCaseless|RKLDotAll|RKLMultiline range:NSMakeRange(0, outputString.length) error:&error];
      if (error)
        DebugLog(0, @"error : %@", error);
      result = !outputString ? nil : [outputString dataUsingEncoding:NSUTF8StringEncoding];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeHTML))
  }//end if (inputData && annotationData)
  if (!result)
    result = inputData;
  return result;
}
//end annotateData:ofUTI:withData:

-(NSData*) stripPdfData:(NSData*)pdfData
{
  NSData* result = nil;
  if (pdfData)
  {
    CGDataProviderRef inputDataProvider = !pdfData ? 0 :
      CGDataProviderCreateWithCFData((CFDataRef)pdfData);
    CGPDFDocumentRef inputPdfDocument = !inputDataProvider ? 0 :
      CGPDFDocumentCreateWithProvider(inputDataProvider);
    CGPDFPageRef inputPage = !inputPdfDocument ? 0 :
      CGPDFDocumentGetPage(inputPdfDocument, 1);
    CGRect inputMediaBox = !inputPage ? CGRectZero :
      CGPDFPageGetBoxRect(inputPage, kCGPDFMediaBox);
    
    NSMutableData* outputData = [NSMutableData data];
    CGDataConsumerRef outputDataConsumer = !outputData ? 0 :
      CGDataConsumerCreateWithCFData((CFMutableDataRef)outputData);
    CGContextRef outputPdfContext = !outputDataConsumer ? 0 :
      CGPDFContextCreate(outputDataConsumer, &inputMediaBox, 0);
    CGContextBeginPage(outputPdfContext, &inputMediaBox);
    CGContextDrawPDFPage(outputPdfContext, inputPage);
    CGContextEndPage(outputPdfContext);
    CGContextFlush(outputPdfContext);

    CGContextRelease(outputPdfContext);
    CGDataConsumerRelease(outputDataConsumer);
    CGPDFDocumentRelease(inputPdfDocument);
    CGDataProviderRelease(inputDataProvider);

    result = outputData;
  }//end if (pdfData)
  if (!result)
    result = pdfData;
  return result;
}
//end stripPdfData:

-(NSString*) getGSVersion:(NSDictionary*)compositionConfiguration
{
  NSString* result = nil;
  NSString* temporaryDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
  BOOL useLoginShell = [compositionConfiguration compositionConfigurationUseLoginShell];
  NSString* gsPath   = [compositionConfiguration compositionConfigurationProgramPathGs];
  SystemTask* gsTask = [[SystemTask alloc] initWithWorkingDirectory:temporaryDirectory];
  @try
  {
    gsTask.usingLoginShell = useLoginShell;
    gsTask.currentDirectoryPath = temporaryDirectory;
    gsTask.environment = self->globalExtraEnvironment;
    gsTask.launchPath = gsPath;
    gsTask.arguments = @[@"--version"];
    [gsTask launch];
    [gsTask waitUntilExit];
    NSData* stdOutputData = [gsTask dataForStdOutput];
    result = !stdOutputData ? nil :
      [[[NSString alloc] initWithData:stdOutputData encoding:NSUTF8StringEncoding]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  }
  @catch(NSException* e)
  {
  }
  return result;
}
//end getGSVersion:
  
@end
