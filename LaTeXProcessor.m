//
//  LaTeXProcessor.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/09/08.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "LaTeXProcessor.h"

#if defined(CH_APP_EXTENSION)
#elif defined(CH_APP_XPC_SERVICE)
#else
#import "AppController.h"
#endif

#import "Compressor.h"
#import "LatexitEquation.h"
#import "NSArrayExtended.h"
#import "NSColorExtended.h"
#import "NSDataExtended.h"
#import "NSDictionaryCompositionConfiguration.h"
#import "NSDictionaryExtended.h"
#import "NSFileManagerExtended.h"
#import "NSImageExtended.h"
#import "NSObjectExtended.h"
#import "NSStringExtended.h"
#import "NSTaskExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "SystemTask.h"
#import "TeXItemWrapper.h"
#import "Utils.h"

#import <Quartz/Quartz.h>
#import <libxml/parser.h>
#import <libxml/xpath.h>
#import <libxml/xpathInternals.h>

#include <dlfcn.h>

NSString* LatexizationDidEndNotification = @"LatexizationDidEndNotification";

//In MacOS 10.4.0, 10.4.1 and 10.4.2, these constants are declared but not defined in the PDFKit.framework!
//So I define them myself, but it is ugly. I expect next versions of MacOS to fix that
#if __MAC_OS_X_VERSION_MAX_ALLOWED < 1050
NSString* PDFDocumentCreatorAttribute = @"Creator"; 
NSString* PDFDocumentKeywordsAttribute = @"Keywords";
#endif

static NSString* mathMLFix(NSString* value)
{
  NSString* result = value;
  if (value)
  {
    NSError* error = nil;
    NSArray* components = [value captureComponentsMatchedByRegex:@".*<math[^>]*xmlns=\"(.*?)\"" options:RKLDotAll|RKLCaseless range:value.range error:&error];
    NSString* mmlXmlns = ([components count] < 2) ? nil : [[components objectAtIndex:1] dynamicCastToClass:[NSString class]];
    if (error)
      DebugLogStatic(1, @"error = %@", error);
    const xmlChar* xmlTxt = BAD_CAST [value UTF8String];
    xmlDocPtr doc = xmlParseDoc(xmlTxt);
    xmlXPathInit();
    xmlXPathContextPtr ctxt = !doc ? 0 : xmlXPathNewContext(doc);
    xmlXPathObjectPtr xpathRes = 0;
    if (ctxt)
    {
      if (![mmlXmlns length])
        xpathRes = !ctxt ? 0 : xmlXPathEvalExpression(BAD_CAST "//mtable/mrow", ctxt);
      else//if ([mmlXmlns length])
      {
        xmlXPathRegisterNs(ctxt, BAD_CAST "mml", BAD_CAST [mmlXmlns UTF8String]);
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
      #ifdef ARC_ENABLED
      NSMutableString* modified = [[NSMutableString alloc] initWithBytes:mem length:size encoding:NSUTF8StringEncoding];
      #else
      NSMutableString* modified = [[[NSMutableString alloc] initWithBytes:mem length:size encoding:NSUTF8StringEncoding] autorelease];
      #endif
      [modified replaceOccurrencesOfRegex:@"<latexitDummyTableRow.*?>" withString:@"<mtr><mtd>" options:RKLDotAll|RKLMultiline|RKLCaseless range:modified.range error:&error];
      if (error)
        DebugLogStatic(1, @"error = %@", error);
      [modified replaceOccurrencesOfRegex:@"</latexitDummyTableRow.*?>" withString:@"</mtd></mtr>" options:RKLDotAll|RKLMultiline|RKLCaseless range:modified.range error:&error];
      if (error)
        DebugLogStatic(1, @"error = %@", error);
      #ifdef ARC_ENABLED
      result = [modified copy];
      #else
      result = [[modified copy] autorelease];
      #endif
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

-(id) init
{
  if (!((self = [super init])))
    return nil;
  [self initializeEnvironment];
  return self;
}
//end init

-(void) dealloc
{
  #ifdef ARC_ENABLED
  #else
  [self->managedObjectModel     release];
  [self->unixBins               release];
  [self->globalExtraEnvironment release];
  [self->globalFullEnvironment  release];
  [self->globalExtraEnvironment release];
  [super dealloc];
  #endif
}
//end dealloc

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
        NSString* systemCall = [NSString stringWithFormat:@". /etc/profile && /bin/echo \"$PATH\" >| %@", temporaryPathFilePath];
        int error = system([systemCall UTF8String]);
        NSError* nserror = nil;
        NSStringEncoding encoding = NSUTF8StringEncoding;
        NSArray* profileBins =
          error ? [NSArray array] :
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
        NSString* filePath = [NSString pathWithComponents:[NSArray arrayWithObjects:NSHomeDirectory(), @".MacOSX", @"environment.plist", nil]];
        NSDictionary* propertyList = [NSDictionary dictionaryWithContentsOfFile:filePath];
        if (propertyList)
        {
          NSArray* components =
            [[[[propertyList objectForKey:@"PATH"] dynamicCastToClass:[NSString class]] trim] componentsSeparatedByString:@":"];
          if (components)
            [macOSXEnvironmentPaths setArray:components];
        }//end if (propertyList)

        //process environment
        NSMutableArray* processEnvironmentPaths = [NSMutableArray array];
        self->globalFullEnvironment  = [[[NSProcessInfo processInfo] environment] mutableCopy];
        NSString* pathEnv = [[[self->globalFullEnvironment objectForKey:@"PATH"] dynamicCastToClass:[NSString class]] trim];
        if (pathEnv)
        {
          NSArray* components = [pathEnv componentsSeparatedByString:@":"];
          if (components)
            [processEnvironmentPaths setArray:components];
        }//end if (pathEnv)

        NSMutableArray* allBins = [NSMutableArray arrayWithArray:self->unixBins];
        [allBins addObjectsFromArray:macOSXEnvironmentPaths];
        [allBins addObjectsFromArray:processEnvironmentPaths];
        NSMutableArray* allBinsUniqued = [NSMutableArray arrayWithCapacity:[allBins count]];
        NSMutableSet* allBinsEncountered = [NSMutableSet setWithCapacity:[allBins count]];
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
        [self->globalFullEnvironment setObject:self->globalEnvironmentPath forKey:@"PATH"];
        self->globalExtraEnvironment = [[NSMutableDictionary alloc] init];
        [self->globalExtraEnvironment setObject:self->globalEnvironmentPath forKey:@"PATH"];

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
        NSURL* modelURL = !modelPath ? nil : [NSURL fileURLWithPath:modelPath];
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
  [self->globalEnvironmentPath setString:[[componentsSet allObjects] componentsJoinedByString:@":"]];
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

  #warning 64bits problem
  BOOL shouldDenyDueTo64Bitsproblem = (sizeof(NSInteger) != 4);
  BOOL embeddAsAnnotation = !shouldDenyDueTo64Bitsproblem;
  if (embeddAsAnnotation)
  {
    PDFDocument* pdfDocument = nil;
    PDFAnnotation* pdfAnnotation = nil;
    @try{
      pdfDocument = [[PDFDocument alloc] initWithData:data2];
      PDFPage* pdfPage = [pdfDocument pageAtIndex:0];
      pdfAnnotation = !pdfPage ? nil :
        isMacOS10_13OrAbove() ? [[PDFAnnotationText alloc] initWithBounds:NSZeroRect forType:PDFAnnotationSubtypeText withProperties:nil] :
        [[PDFAnnotationText alloc] initWithBounds:NSZeroRect];
      [pdfAnnotation setShouldDisplay:NO];
      [pdfAnnotation setShouldPrint:NO];
      NSDictionary* rootObject =
        [NSDictionary dictionaryWithObjectsAndKeys:
          preamble, @"preamble",
          source, @"source",
          [(!color ? [NSColor blackColor] : color) colorAsData], @"color",
          @(mode), @"mode",
          @(magnification), @"magnification",
          @(baseline), @"baseline",
          [(!backgroundColor ? [NSColor whiteColor] : backgroundColor) colorAsData], @"backgroundColor",
          title, @"title",
          nil];
      NSData* embeddedData =
        !pdfAnnotation ? nil :
        isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:rootObject requiringSecureCoding:YES error:nil] :
        [NSKeyedArchiver archivedDataWithRootObject:rootObject];
      NSString* embeddedDataBase64 = [embeddedData encodeBase64];
      [pdfAnnotation performSelector:@selector(setUserName:) withObject:@"fr.chachatelier.pierre.LaTeXiT"];
      [pdfAnnotation setContents:embeddedDataBase64];
      [pdfPage addAnnotation:pdfAnnotation];
      NSData* dataWithAnnotation = [pdfDocument dataRepresentation];
      data2 = !dataWithAnnotation ? data2 : dataWithAnnotation;
    }
    @catch(NSException* e){
      DebugLog(0, @"exception : %@", e);
    }
    @finally{
      #ifdef ARC_ENABLED
      #else
      [pdfAnnotation release];
      [pdfDocument release];
      #endif
    }
  }//end if (embeddAsAnnotation)

  NSString* colorAsString   = [(color ? color : [NSColor blackColor]) rgbaString];
  NSString* bkColorAsString = [(backgroundColor ? backgroundColor : [NSColor whiteColor]) rgbaString];
  if (data2)
  {
    NSMutableString* replacedPreamble = [NSMutableString stringWithString:preamble];
    [replacedPreamble replaceOccurrencesOfString:@"\\" withString:@"ESslash"      options:0 range:replacedPreamble.range];
    [replacedPreamble replaceOccurrencesOfString:@"{"  withString:@"ESleftbrack"  options:0 range:replacedPreamble.range];
    [replacedPreamble replaceOccurrencesOfString:@"}"  withString:@"ESrightbrack" options:0 range:replacedPreamble.range];
    [replacedPreamble replaceOccurrencesOfString:@"$"  withString:@"ESdollar"     options:0 range:replacedPreamble.range];
    NSString* escapedPreamble = [preamble stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];

    NSMutableString* replacedSource = [NSMutableString stringWithString:source];
    [replacedSource replaceOccurrencesOfString:@"\\" withString:@"ESslash"      options:0 range:replacedSource.range];
    [replacedSource replaceOccurrencesOfString:@"{"  withString:@"ESleftbrack"  options:0 range:replacedSource.range];
    [replacedSource replaceOccurrencesOfString:@"}"  withString:@"ESrightbrack" options:0 range:replacedSource.range];
    [replacedSource replaceOccurrencesOfString:@"$"  withString:@"ESdollar"     options:0 range:replacedSource.range];
    NSString* escapedSource = [source stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLPathAllowedCharacterSet]];

    NSString* type = [@(mode) stringValue];
    
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
             @([annotationContentBase64 length]),
             annotationContentBase64];
      #ifdef ARC_ENABLED
      NSMutableString* pdfString = [[NSMutableString alloc] initWithData:data2 encoding:NSASCIIStringEncoding];
      #else
      NSMutableString* pdfString = [[[NSMutableString alloc] initWithData:data2 encoding:NSASCIIStringEncoding] autorelease];
      #endif
      
      NSRange r1 = [pdfString rangeOfString:@"\nxref" options:NSBackwardsSearch];
      NSRange r2 = [pdfString rangeOfString:@"startxref" options:NSBackwardsSearch];
      r2 = (r2.location == NSNotFound) ? r2 : [pdfString lineRangeForRange:r2];

      NSString* tail_of_tail = (r2.location == NSNotFound) ? @"" : [pdfString substringFromIndex:r2.location];
      NSArray*  tailarray    = [tail_of_tail componentsSeparatedByString:@"\n"];

      int byte_count = 0;
      NSScanner* scanner = ([tailarray count]<2) ? nil : [NSScanner scannerWithString:[tailarray objectAtIndex:1]];
      [scanner scanInt:&byte_count];
      if (r1.location != NSNotFound)
        byte_count += [annotation length];

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

    NSRange r0 = NSMakeRange(0, [data2 length]);
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
        r0.length = [data2 length];
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
      r3.length = [data2 length]-r3.location;

    NSData* xrefData = (r1.location == NSNotFound) ? nil : [data2 subdataWithRange:r1];
    #ifdef ARC_ENABLED
    NSString* xrefString = [[NSString alloc] initWithData:xrefData encoding:NSASCIIStringEncoding];
    #else
    NSString* xrefString = [[[NSString alloc] initWithData:xrefData encoding:NSASCIIStringEncoding] autorelease];
    #endif
    NSString* afterObjCountString = [xrefString stringByMatching:@"xref\\s*[0-9]+\\s+[0-9]+\\s+(.*)" options:RKLDotAll inRange:xrefString.range capture:1 error:0];

    NSData* trailerData = (r2.location == NSNotFound) ? nil : [data2 subdataWithRange:r2];
    #ifdef ARC_ENABLED
    NSString* trailerString = [[NSString alloc] initWithData:trailerData encoding:NSASCIIStringEncoding];
    #else
    NSString* trailerString = [[[NSString alloc] initWithData:trailerData encoding:NSASCIIStringEncoding] autorelease];
    #endif
    NSString* trailerAfterSize = [trailerString stringByMatching:@"trailer\\s+<<\\s+/Size\\s+[0-9]+(.*)" options:RKLDotAll inRange:trailerString.range capture:1 error:0];
    
    NSUInteger nbObjects = 0;
    if ((r1.location != NSNotFound) && (r2.location != NSNotFound))
    {
      const unsigned char* bytes = (const unsigned char*)[data2 bytes];
      NSString* s = [[NSString alloc] initWithBytesNoCopy:(unsigned char*)bytes+r1.location length:r2.location-r1.location encoding:NSUTF8StringEncoding freeWhenDone:NO];
      NSArray* components = [s componentsMatchedByRegex:@"^[0-9]+\\s+[0-9]+\\s[^0-9]+$" options:RKLMultiline range:s.range capture:0 error:nil];
      nbObjects = [components count];
      #ifdef ARC_ENABLED
      #else
      [s release];
      #endif
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
    #ifdef ARC_ENABLED
    NSString* startxrefString = [[NSString alloc] initWithData:startxrefData encoding:NSASCIIStringEncoding];
    #else
    NSString* startxrefString = [[[NSString alloc] initWithData:startxrefData encoding:NSASCIIStringEncoding] autorelease];
    #endif
    NSString* byteCountString = [startxrefString stringByMatching:@"[^0-9]*([0-9]*).*" options:RKLDotAll inRange:startxrefString.range capture:1 error:0];
    #ifdef ARC_ENABLED
    NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
    #else
    NSNumberFormatter* numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
    #endif
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehaviorDefault];
    [numberFormatter setMinimum:@(0)];
    [numberFormatter setMaximum:@(NSUIntegerMax)];
    NSNumber* number = !byteCountString ? nil : [numberFormatter numberFromString:byteCountString];
    NSUInteger byte_count = [number unsignedIntegerValue];

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
        @(magnification), @"magnification",
        @(baseline), @"baseline",
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
        //CGContextDrawPDFPage(cgPDFContext, pdfPage);
        BOOL disableGraphicMetadata = NO;
        BOOL debugVisibleAnnotations = NO;
        BOOL debugLargeAnnotations = NO;
        CGContextSetRGBStrokeColor(cgPDFContext, debugVisibleAnnotations ? 1. : 0., 0., 0., debugVisibleAnnotations ? 1. : 0.);
        CGContextSetRGBFillColor(cgPDFContext, debugVisibleAnnotations ? 1. : 0., 0., 0., debugVisibleAnnotations ? 1. : 0.);
        CGContextSetTextDrawingMode(cgPDFContext, debugVisibleAnnotations ? kCGTextFill : kCGTextInvisible);
        BOOL useFullyGraphicMetadata =
          (exportFormat == EXPORT_FORMAT_EPS) ||
          //(exportFormat == EXPORT_FORMAT_PDF) ||
          (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS);
        DebugLog(1, @"useFullyGraphicMetadata = %d", (int)useFullyGraphicMetadata);
        if (disableGraphicMetadata){
        }
        else if (useFullyGraphicMetadata)
        {
          const unsigned char* annotationBytes = (const unsigned char*)[annotationContentBase64CompleteString UTF8String];
          size_t annotationBytesLength = [annotationContentBase64CompleteString lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
          float tmp[6] = {0};
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
          CGFloat scale = debugLargeAnnotations ? 1 : 1e-6;
          CGContextConcatCTM(cgPDFContext, CGAffineTransformMakeScale(scale, scale));
          CGContextAddPath(cgPDFContext, path);
          CGContextSetRGBStrokeColor(cgPDFContext, debugVisibleAnnotations ? 1. : 0., 0., 0., debugVisibleAnnotations ? 1. : 0.);
          CGContextStrokePath(cgPDFContext);
          CGPathRelease(path);
          CGContextRestoreGState(cgPDFContext);
        }//end if (useFullyGraphicMetadata)
        else//if (!useFullyGraphicMetadata)
        {
          CGFloat fontSize = debugLargeAnnotations ? 1 : 1e-6;
          CGFloat scale = 1;
          DebugLog(1, @"mediaBox = %@", NSStringFromRect(NSRectFromCGRect(mediaBox)));
          NSFont* font = [NSFont fontWithName:@"Courier" size:fontSize];
          DebugLog(1, @"font = %@", font);
          DebugLog(1, @"annotationContentBase64CompleteString = %@", annotationContentBase64CompleteString);
          if (annotationContentBase64CompleteString.length)
          {
            NSAttributedString* attributedString = [[NSAttributedString alloc] initWithString:annotationContentBase64CompleteString attributes:@{NSFontAttributeName:font}];
            CGRect drawRect = mediaBox;
            CTFramesetterRef frameSetter = !attributedString ? 0 : CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attributedString);
            CGPathRef path = CGPathCreateWithRect(drawRect, 0);
            CTFrameRef frame = !frameSetter ? 0 : CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, attributedString.length), path, 0);
            if (frame)
            {
              CGContextSaveGState(cgPDFContext);
              CGContextScaleCTM(cgPDFContext, scale, scale);
              CTFrameDraw(frame, cgPDFContext);
              CGContextRestoreGState(cgPDFContext);
            }//end if (frame)
            CGPathRelease(path);
            if (frame)
              CFRelease(frame);
            if (frameSetter)
              CFRelease(frameSetter);
            [attributedString release];
          }//end if (annotationContentBase64CompleteString.length)
        }//end if (!useFullyGraphicMetadata)
        CGContextFlush(cgPDFContext);
        CGContextDrawPDFPage(cgPDFContext, pdfPage);
        CGPDFContextEndPage(cgPDFContext);
        DebugLog(1, @"boxData = %p", boxData);
        if (boxData)
          CFRelease(boxData);
        DebugLog(1, @"pageDictionary = %p", pageDictionary);
        if (pageDictionary)
          CFRelease(pageDictionary);
        DebugLog(1, @"cgPDFContext = %p", cgPDFContext);
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
  color = [color colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
  CGFloat rgba[4] = {0};
  [color getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
  NSString* colorString = [color isRGBEqualTo:[NSColor blackColor]] ? @"" :
    [NSString stringWithFormat:@"\\color[rgb]{%1.3f,%1.3f,%1.3f}", rgba[0], rgba[1], rgba[2]];
  NSMutableString* preamble = [NSMutableString stringWithString:thePreamble];
  
  NSString* token = @"%__TEXTCOLOR__";
  [preamble replaceOccurrencesOfString:token withString:colorString options:0 range:preamble.range];
  
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
      NSString* preamble = [[data objectForKey:@"preamble"] dynamicCastToClass:[NSString class]];
      NSString* sourceText = [[data objectForKey:@"sourceText"] dynamicCastToClass:[NSString class]];
      NSNumber* latexMode = [[data objectForKey:@"mode"] dynamicCastToClass:[NSNumber class]]; 
      NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
      NSDictionary* fullEnvironment = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];
      CGFloat leftMargin   = [[[appController valueForKey:@"marginsCurrentLeftMargin"] dynamicCastToClass:[NSNumber class]] doubleValue];
      CGFloat rightMargin  = [[[appController valueForKey:@"marginsCurrentRightMargin"] dynamicCastToClass:[NSNumber class]] doubleValue];
      CGFloat bottomMargin = [[[appController valueForKey:@"marginsCurrentBottomMargin"] dynamicCastToClass:[NSNumber class]] doubleValue];
      CGFloat topMargin    = [[[appController valueForKey:@"marginsCurrentTopMargin"] dynamicCastToClass:[NSNumber class]] doubleValue];
      NSMutableDictionary* configuration = !preamble || !sourceText ? nil :
        [NSMutableDictionary dictionaryWithObjectsAndKeys:
          @(backgroundly), @"runInBackgroundThread",
          preamble, @"preamble",
          sourceText, @"body",
          [preferencesController latexisationFontColor], @"color",
          !latexMode ? @(LATEX_MODE_AUTO) : latexMode, @"mode",
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
          !fullEnvironment ? [NSDictionary dictionary] : fullEnvironment, @"fullEnvironment",
          [NSString stringWithFormat:@"latexit-import-lib-from-text-%p", teXItem], @"uniqueIdentifier",
          @"", @"outFullLog",
          [NSArray array], @"outErrors",
          [NSData data], @"outPdfData",
          @(NO), @"applyToPasteboard",
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
  #ifdef ARC_ENABLED
  #else
  [configuration retain];
  #endif
  BOOL runInBackgroundThread = [[configuration objectForKey:@"runInBackgroundThread"] boolValue];
  if (runInBackgroundThread)
  {
    [configuration setObject:@(NO) forKey:@"runInBackgroundThread"];
    [NSApplication detachDrawingThread:@selector(latexiseWithConfiguration:) toTarget:self withObject:configuration];
  }//end if (runInBackgroundThread)
  else//if (!runInBackgroundThread)
  {
    NSMutableDictionary* configuration2 = [configuration mutableCopyDeep];//will protect from preferences changes
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
    if (fullLog) [configuration2 setObject:fullLog forKey:@"outFullLog"];
    if (errors)  [configuration2 setObject:errors  forKey:@"outErrors"];
    if (pdfData) [configuration2 setObject:pdfData forKey:@"outPdfData"];
    if (result)  [configuration2 setObject:result  forKey:@"result"];
    [configuration setDictionary:configuration2];
    #ifdef ARC_ENABLED
    #else
    [configuration2 release];
    #endif
    [[NSNotificationCenter defaultCenter] postNotificationName:LatexizationDidEndNotification object:configuration];
  }//end if (!runInBackgroundThread)
  #ifdef ARC_ENABLED
  #else
  [configuration autorelease];
  #endif
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
                    outFullLog:(NSString**)outFullLog outErrors:(NSArray**)outErrors outPdfData:(NSData**)outPdfData
{
  NSData* pdfData = nil;
  
  preamble = [preamble filteredStringForLatex];
  body     = [body filteredStringForLatex];

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
      NSString* extension = [[file pathExtension] lowercaseString];
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
  NSMutableArray* additionalFilesPathsLinksCreated = [NSMutableArray arrayWithCapacity:[additionalFilesPaths count]];
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
                               inRange:colouredPreamble.range capture:2 error:nil];
  if (ptSizeString && [ptSizeString length])
  {
    CGFloat floatValue = [ptSizeString floatValue];
    if (floatValue > 0)
      ptSizeBase = floatValue;
  }

  //STEP 1
  //first, creates simple latex source text to compile and report errors (if there are any)
  
  //the body is trimmed to avoid some latex problems (sometimes, a newline at the end of the equation makes it fail!)
  NSString* trimmedBody = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  trimmedBody = [trimmedBody stringByAppendingString:@"\n"];//in case that a % is on the last line
  //the problem is that now, the error lines must be shifted ! How many new lines have been removed ?
  NSString* firstChar = [trimmedBody length] ? [trimmedBody substringWithRange:NSMakeRange(0, 1)] : @"";
  NSRange firstCharLocation = [body rangeOfString:firstChar];
  NSRange rangeOfTrimmedHeader = NSMakeRange(0, (firstCharLocation.location != NSNotFound) ? firstCharLocation.location : 0);
  NSString* trimmedHeader = [body substringWithRange:rangeOfTrimmedHeader];
  NSUInteger nbNewLinesInTrimmedHeader = MAX(1U, [[trimmedHeader componentsSeparatedByString:@"\n"] count]);
  NSInteger errorLineShift = MAX((NSInteger)0, (NSInteger)nbNewLinesInTrimmedHeader-1);
  
  NSDictionary* additionalProcessingScripts = [compositionConfiguration compositionConfigurationAdditionalProcessingScripts];
  
  //xelatex requires to insert the color in the body, so we compute the color as string...
  color = [(color ? color : [NSColor blackColor]) colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
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
       [colouredPreamble replaceYenSymbol],
       (compositionMode == COMPOSITION_MODE_XELATEX) ? colorString : 
       (compositionMode == COMPOSITION_MODE_LUALATEX) ? colorString : @"",
       addSymbolLeft,
       [trimmedBody replaceYenSymbol],
       addSymbolRight];

  //creates the corresponding latex file
  NSData* latexData = [normalSourceToCompile dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
  BOOL failed = ![latexData writeToFile:latexFilePath atomically:NO];

  //if (!failed)
  //  [fullLog appendFormat:@"Source :\n%@\n", normalSourceToCompile];
      
  //PREPROCESSING
  NSDictionary* extraEnvironment =
    [NSDictionary dictionaryWithObjectsAndKeys:[latexFilePath stringByDeletingLastPathComponent], @"CURRENTDIRECTORY",
                                                [latexFilePath stringByDeletingPathExtension], @"INPUTFILE",
                                                latexFilePath, @"INPUTTEXFILE",
                                                pdfFilePath, @"OUTPUTPDFFILE",
                                                pdfFilePath2, @"OUTPUTPDFFILE2",
                                                (compositionMode == COMPOSITION_MODE_LATEXDVIPDF)
                                                  ? dviFilePath : nil, @"OUTPUTDVIFILE",
                                                nil];
  NSMutableDictionary* environment1 = [NSMutableDictionary dictionaryWithDictionary:fullEnvironment];
  [environment1 addEntriesFromDictionary:extraEnvironment];
  NSDictionary* script = [additionalProcessingScripts objectForKey:[NSString stringWithFormat:@"%d",SCRIPT_PLACE_PREPROCESSING]];
  if (script && [[script objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
  {
    [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Pre-processing", @"")];
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
  failed |= errors && [errors count] && (![fileManager fileExistsAtPath:pdfFilePath isDirectory:&isDirectory] || isDirectory);
  //STEP 1 is over. If it has failed, it is the fault of the user, and syntax errors will be reported

  //Middle-Processing
  if (!failed)
  {
    NSDictionary* script = [additionalProcessingScripts objectForKey:[NSString stringWithFormat:@"%d",SCRIPT_PLACE_MIDDLEPROCESSING]];
    if (script && [[script objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
    {
      [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Middle-processing", @"")];
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
          addSymbolLeft, [body replaceYenSymbol], addSymbolRight, //source text
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
        NSArray*  extraArguments = [NSArray arrayWithObjects:
          @"--gscmd", gsPath, texcmdtype, texcmd, texcmdparameter,
          @"--margins", [NSString stringWithFormat:@"\"%f %f %f %f\"", leftMargin, topMargin, rightMargin, bottomMargin],
          //@"--hires",
/*          @"--bbox", [NSString stringWithFormat:@"\"%f %f %f %f\"",
            boundingBox.origin.x-leftMargin,
            boundingBox.origin.y+boundingBox.size.height+topMargin,
            boundingBox.origin.x+boundingBox.size.width+rightMargin,
            boundingBox.origin.y-bottomMargin],*/
          nil];
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
                       @(isMacOS10_14OrAbove() ? 5 : 3), @"pdfMinorVersion",
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
        NSArray*  extraArguments = [NSArray arrayWithObjects:
          @"--gscmd", gsPath, texcmdtype, texcmd, texcmdparameter,
          @"--margins", [NSString stringWithFormat:@"\"%f %f %f %f\"", leftMargin, topMargin, rightMargin, bottomMargin],
          //@"--hires",
          /*@"--bbox", [NSString stringWithFormat:@"\"%f %f %f %f\"",
            boundingBox.origin.x-leftMargin,
            boundingBox.origin.y+boundingBox.size.height+topMargin,
            boundingBox.origin.x+boundingBox.size.width+rightMargin,
            boundingBox.origin.y-bottomMargin],*/
          nil];
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
                          @(isMacOS10_14OrAbove() ? 5 : 3), @"pdfMinorVersion",
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
    #warning 64bits problem
    BOOL shouldDenyDueTo64Bitsproblem = (sizeof(NSInteger) != 4);
    if (!failed && pdfData && !shouldDenyDueTo64Bitsproblem)
    {
      PDFDocument* pdfDocument = nil;
      @try{
        //in the meta-data of the PDF we store as much info as we can : preamble, body, size, color, mode, baseline...
        pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
        NSDictionary* attributes = @{PDFDocumentCreatorAttribute:[[NSWorkspace sharedWorkspace] applicationName]};
        [pdfDocument setDocumentAttributes:attributes];
        pdfData = [pdfDocument dataRepresentation];
      }
      @catch(NSException* e){
        DebugLog(0, @"exception : %@", e);
      }
      @finally {
        #ifdef ARC_ENABLED
        #else
        [pdfDocument release];
        #endif
      }
    }//end if (!failed && pdfData && !shouldDenyDueTo64Bitsproblem)

    if (!failed && pdfData)
    {
      //POSTPROCESSING
      NSDictionary* script = [additionalProcessingScripts objectForKey:[NSString stringWithFormat:@"%d",SCRIPT_PLACE_POSTPROCESSING]];
      if (script && [[script objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
      {
        [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Post-processing", @"")];
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
    [boundingBoxTask setUsingLoginShell:useLoginShell];
    [boundingBoxTask setCurrentDirectoryPath:workingDirectory];
    [boundingBoxTask setEnvironment:fullEnvironment];
    if ([[[filePath pathExtension] lowercaseString] isEqualToString:@"dvi"])
      [boundingBoxTask setLaunchPath:dviPdfPath];
    else
      [boundingBoxTask setLaunchPath:gsPath];
    NSArray* defaultArguments = ([[[filePath pathExtension] lowercaseString] isEqualToString:@"dvi"]) ? dviPdfArguments : gsArguments;
    [boundingBoxTask setArguments:[defaultArguments arrayByAddingObjectsFromArray:
      [NSArray arrayWithObjects:@"-sstdout=%stderr", @"-dNOPAUSE", @"-dSAFER", @"-dNOPLATFONTS", @"-sDEVICE=bbox",@"-dBATCH",@"-q", filePath, nil]]];
    [outFullLog appendString:[NSString stringWithFormat:@"\n--------------- %@ ---------------\n%@\n",
                                NSLocalizedString(@"bounding box computation", @""),
                                [boundingBoxTask equivalentLaunchCommand]]];
    [boundingBoxTask launch];
    [boundingBoxTask waitUntilExit];
    NSData*   boundingBoxData = [boundingBoxTask dataForStdError];
    #ifdef ARC_ENABLED
    #else
    [boundingBoxTask release];
    #endif
    #ifdef ARC_ENABLED
    NSString* boundingBoxString = [[NSString alloc] initWithData:boundingBoxData encoding:NSUTF8StringEncoding];
    #else
    NSString* boundingBoxString = [[[NSString alloc] initWithData:boundingBoxData encoding:NSUTF8StringEncoding] autorelease];
    #endif
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
  
  NSString* workingDirectory = [filePath stringByDeletingLastPathComponent];
  NSString* texFile   = filePath;
  NSString* dviFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"dvi"];
  NSString* pdfFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
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
    [NSString stringWithFormat:@"\"\\pdfminorversion=%@ \\input \\\"%@\\\"\"", @(pdfMinorVersion), texFile];

  #ifdef ARC_ENABLED
  SystemTask* systemTask = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
  #else
  SystemTask* systemTask = [[[SystemTask alloc] initWithWorkingDirectory:workingDirectory] autorelease];
  #endif
  [systemTask setUsingLoginShell:useLoginShell];
  [systemTask setTimeOut:120];
  [systemTask setCurrentDirectoryPath:workingDirectory];
  [systemTask setLaunchPath:executablePath];
  [systemTask setArguments:[defaultArguments arrayByAddingObjectsFromArray:
    [NSArray arrayWithObjects:@"-file-line-error", @"-interaction", @"nonstopmode", texFileArg, nil]]];
  [systemTask setEnvironment:fullEnvironment];
  [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n%@\n",
                                                        NSLocalizedString(@"processing", @""),
                                                        [executablePath lastPathComponent],
                                                        [systemTask equivalentLaunchCommand]]];
  [systemTask launch];
  BOOL failed = ([systemTask terminationStatus] != 0) && ![fileManager fileExistsAtPath:pdfFile];
  NSData* dataForStdOutput = [systemTask dataForStdOutput];
  #ifdef ARC_ENABLED
  NSString* stdOutputErrors = [[NSString alloc] initWithData:dataForStdOutput encoding:NSUTF8StringEncoding];
  #else
  NSString* stdOutputErrors = [[[NSString alloc] initWithData:dataForStdOutput encoding:NSUTF8StringEncoding] autorelease];
  #endif
  [customString appendString:stdOutputErrors ? stdOutputErrors : @""];
  [stdoutString appendString:stdOutputErrors ? stdOutputErrors : @""];
  
  //NSData* dataForStdError  = [systemTask dataForStdError];
  //NSString* stdErrors = [[[NSString alloc] initWithData:dataForStdError encoding:NSUTF8StringEncoding] autorelease];
  //[customString appendString:stdErrors ? stdErrors : @""];
  //[stdoutString appendString:stdErrors ? stdErrors : @""];
  
  if (failed)
    [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n",
                               NSLocalizedString(@"error while processing", @""),
                               [executablePath lastPathComponent]]];

  //if !failed and must call dvipdf...
  if (!failed && (compositionMode == COMPOSITION_MODE_LATEXDVIPDF))
  {
    NSString* dviPdfPath      = [compositionConfiguration compositionConfigurationProgramPathDviPdf];
    NSArray*  dviPdfArguments = [compositionConfiguration compositionConfigurationProgramArgumentsDviPdf];
  
    SystemTask* dvipdfTask = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
    [dvipdfTask setUsingLoginShell:useLoginShell];
    [dvipdfTask setCurrentDirectoryPath:workingDirectory];
    [dvipdfTask setEnvironment:fullEnvironment];
    [dvipdfTask setLaunchPath:dviPdfPath];
    [dvipdfTask setArguments:[dviPdfArguments arrayByAddingObjectsFromArray:[NSArray arrayWithObject:dviFile]]];
    NSString* executablePath = [[dvipdfTask launchPath] lastPathComponent];
    @try
    {
      [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n%@\n",
                                                            NSLocalizedString(@"processing", @""),
                                                            [[dvipdfTask launchPath] lastPathComponent],
                                                            [dvipdfTask commandLine]]];
      [dvipdfTask launch];
      [dvipdfTask waitUntilExit];
      NSData* stdoutData = [dvipdfTask dataForStdOutput];
      NSData* stderrData = [dvipdfTask dataForStdError];
      NSString* tmp = nil;
      #ifdef ARC_ENABLED
      tmp = stdoutData ? [[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] : nil;
      #else
      tmp = stdoutData ? [[[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] autorelease] : nil;
      #endif
      if (tmp)
      {
        [customString appendString:tmp];
        [stdoutString appendString:tmp];
      }
      #ifdef ARC_ENABLED
      tmp = stderrData ? [[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] : nil;
      #else
      tmp = stderrData ? [[[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] autorelease] : nil;
      #endif
      if (tmp)
      {
        [customString appendString:tmp];
        [stderrString appendString:tmp];
      }
      failed = ([dvipdfTask terminationStatus] != 0);
    }
    @catch(NSException* e)
    {
      failed = YES;
      [customString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", [e name], [e reason]]];
    }
    @finally
    {
      #ifdef ARC_ENABLED
      #else
      [dvipdfTask release];
      #endif
    }
    
    if (failed)
      [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n",
                                 NSLocalizedString(@"error while processing", @""),
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
  NSMutableArray* errorLines = [NSMutableArray arrayWithCapacity:[rawLogLines count]];
  NSEnumerator* enumerator = [rawLogLines objectEnumerator];
  NSString* line = nil;
  while((line = [enumerator nextObject]))
  {
    if ([errorLines count] && [[errorLines lastObject] endsWith:@":" options:0])
      [errorLines replaceObjectAtIndex:[errorLines count]-1 withObject:[[errorLines lastObject] stringByAppendingString:line]];
    else
      [errorLines addObject:line];
  }
  
  //first pass : pdflatex truncates lines at COLUMN=80. This is stupid. I must try to concatenate lines
  NSUInteger errorLineIndex = 0;
  while(errorLineIndex<[errorLines count])
  {
    NSString* line = [errorLines objectAtIndex:errorLineIndex];
    if ([line length] < 79)
      ++errorLineIndex;
    else//if ([line length] >= 79)
    {
      NSMutableString* restoredLine = [NSMutableString stringWithString:line];
      NSString* nextLine = (errorLineIndex+1<[errorLines count]) ? [errorLines objectAtIndex:errorLineIndex+1] : nil;
      if (nextLine)
        [restoredLine appendString:nextLine];
      BOOL nextLineMayBeTruncated = nextLine && ([nextLine length] >= 80);
      if (nextLine)
        [errorLines removeObjectAtIndex:errorLineIndex+1];
      while(nextLineMayBeTruncated)
      {
        nextLine = (errorLineIndex+1<[errorLines count]) ? [errorLines objectAtIndex:errorLineIndex+1] : nil;
        if (nextLine)
          [restoredLine appendString:nextLine];
        nextLineMayBeTruncated = nextLine && ([nextLine length] >= 80);
        if (nextLine)
          [errorLines removeObjectAtIndex:errorLineIndex+1];
      }//end while(nextLineMayBeTruncated)
      [errorLines replaceObjectAtIndex:errorLineIndex withObject:restoredLine];
      ++errorLineIndex;
    }//end if ([line length] >= 79)
  }//end for each line

  NSMutableArray* filteredErrors = [NSMutableArray arrayWithCapacity:[errorLines count]];
  const NSUInteger errorLineIndexCount = [errorLines count];
  errorLineIndex = 0;
  for(errorLineIndex = 0 ; errorLineIndex<errorLineIndexCount ; ++errorLineIndex)
  {
    NSString* line = [errorLines objectAtIndex:errorLineIndex];
    NSArray* components = [line componentsSeparatedByString:@":"];
    if ([components count] >= 3) 
    {
      NSString* fileComponent  = [components objectAtIndex:0];
      NSString* lineComponent  = [components objectAtIndex:1];
      BOOL      lineComponentIsANumber = ![lineComponent isEqualToString:@""] && 
        [[lineComponent stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] isEqualToString:@""];
      NSString* errorComponent = [[components subarrayWithRange:NSMakeRange(2, [components count]-2)] componentsJoinedByString:@":"];
      if (lineComponentIsANumber)
        lineComponent = [@([lineComponent integerValue]+errorLineShift) stringValue];
      if (lineComponentIsANumber || ([line rangeOfString:@"! LaTeX Error:"].location != NSNotFound))
      {
        NSArray* fixedErrorComponents = [NSArray arrayWithObjects:fileComponent, lineComponent, errorComponent, nil];
        NSString* fixedError = [fixedErrorComponents componentsJoinedByString:@":"];
        NSMutableString* fullError = [NSMutableString stringWithString:fixedError];
        NSString* nextLine = (errorLineIndex+1<errorLineIndexCount) ? [errorLines objectAtIndex:errorLineIndex+1] : nil;
        while(nextLine && [line length] && ([line characterAtIndex:[line length]-1] != '.'))
        {
          [fullError appendString:nextLine];
          line = nextLine;
          nextLine = (errorLineIndex+1<errorLineIndexCount) ? [errorLines objectAtIndex:errorLineIndex+1] : nil;
          ++errorLineIndex;
        }
        [filteredErrors addObject:fullError];
      }//end if error seems ok
    }//end if >=3 components
    else if ([components count] > 1) //if 1 < < 3 components
    {
      if ([line rangeOfString:@"! LaTeX Error:"].location != NSNotFound)
      {
        NSString* fileComponent = @"";
        NSString* lineComponent = @"";
        NSString* errorComponent = [[components subarrayWithRange:NSMakeRange(1, [components count]-1)] componentsJoinedByString:@":"];
        NSArray* fixedErrorComponents = [NSArray arrayWithObjects:fileComponent, lineComponent, errorComponent, nil];
        NSString* fixedError = [fixedErrorComponents componentsJoinedByString:@":"];
        NSMutableString* fullError = [NSMutableString stringWithString:fixedError];
        NSString* nextLine = (errorLineIndex+1<errorLineIndexCount) ? [errorLines objectAtIndex:errorLineIndex+1] : nil;
        while(nextLine && [line length] && ([line characterAtIndex:[line length]-1] != '.'))
        {
          [fullError appendString:nextLine];
          line = nextLine;
          nextLine = (errorLineIndex+1<errorLineIndexCount) ? [errorLines objectAtIndex:errorLineIndex+1] : nil;
          ++errorLineIndex;
        }
        [filteredErrors addObject:fullError];
      }//end if error seems ok
      else if (line)
      {
        NSString* fileComponent  = [components objectAtIndex:0];
        NSString* lineComponent  = [components objectAtIndex:1];
        NSString* nextLine       = (errorLineIndex+1<errorLineIndexCount) ? [errorLines objectAtIndex:errorLineIndex+1] : nil;
        NSString* errorComponent = nextLine && ![nextLine isEqualToString:@""] ? nextLine : nil;
        BOOL lineComponentIsANumber = ![lineComponent isEqualToString:@""] && 
          [[lineComponent stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] isEqualToString:@""];

        NSString* fullLine = line;
        if (lineComponentIsANumber && nextLine)
          fullLine = [line stringByAppendingString:nextLine];
          
        lineComponent = [@([lineComponent integerValue]+errorLineShift) stringValue];
        if (lineComponentIsANumber && errorComponent)
        {
          NSArray* fixedErrorComponents = [NSArray arrayWithObjects:fileComponent, lineComponent, errorComponent, nil];
          NSString* fixedError = [fixedErrorComponents componentsJoinedByString:@":"];
          NSMutableString* fullError = [NSMutableString stringWithString:fixedError];
          ++errorLineIndex;
          line = nextLine;
          nextLine = (errorLineIndex+1<errorLineIndexCount) ? [errorLines objectAtIndex:errorLineIndex+1] : nil;
          while(nextLine && [line length] && ([line characterAtIndex:[line length]-1] != '.'))
          {
            [fullError appendString:nextLine];
            line = nextLine;
            nextLine = (errorLineIndex+1<errorLineIndexCount) ? [errorLines objectAtIndex:errorLineIndex+1] : nil;
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
  [arguments addObjectsFromArray:[NSArray arrayWithObjects:inoutPdfFilePath, outputPdfFilePath, nil]];
  SystemTask* pdfCropTask = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
  [pdfCropTask setUsingLoginShell:useLoginShell];
  [pdfCropTask setEnvironment:environment];
  [pdfCropTask setLaunchPath:@"perl"];
  [pdfCropTask setArguments:arguments];
  [pdfCropTask setCurrentDirectoryPath:workingDirectory];
  [fullLog appendString:@"--------------- pdfcrop call ---------------\n"];
  [fullLog appendString:[pdfCropTask equivalentLaunchCommand]];
  [fullLog appendString:@"------------------------------------------------\n"];
  [pdfCropTask launch];
  [pdfCropTask waitUntilExit];
  result = ([pdfCropTask terminationStatus] == 0);
  #ifdef ARC_ENABLED
  #else
  [pdfCropTask release];
  #endif
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
          NSLocalizedString(@"Shell", @""),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Body", @""),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptContentKey]];
        break;
      case SCRIPT_SOURCE_FILE :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"File", @""),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Content", @""),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptPathKey]];
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
  if (script && [[script objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
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
    script_source_t source = scriptType ? (script_source_t)[scriptType integerValue] : SCRIPT_SOURCE_STRING;

    NSStringEncoding encoding = NSUTF8StringEncoding;
    NSError* error = nil;
    switch(source)
    {
      case SCRIPT_SOURCE_STRING: scriptBody = [script objectForKey:CompositionConfigurationAdditionalProcessingScriptContentKey];break;
      case SCRIPT_SOURCE_FILE: scriptBody = [NSString stringWithContentsOfFile:[script objectForKey:CompositionConfigurationAdditionalProcessingScriptPathKey] guessEncoding:&encoding error:&error]; break;
    }
    
    NSData* scriptData = [scriptBody dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    [scriptData writeToFile:latexScriptPath atomically:NO];

    NSMutableDictionary* fileAttributes =
    [NSMutableDictionary dictionaryWithDictionary:[fileManager attributesOfFileSystemForPath:latexScriptPath error:0]];
    NSNumber* posixPermissions = [fileAttributes objectForKey:NSFilePosixPermissions];
    posixPermissions = @([posixPermissions unsignedLongValue] | 0700);//add rwx flag
    [fileAttributes setObject:posixPermissions forKey:NSFilePosixPermissions];
    [fileManager setAttributes:fileAttributes ofItemAtPath:latexScriptPath error:0];

    NSString* scriptShell = nil;
    switch(source)
    {
      case SCRIPT_SOURCE_STRING:
        scriptShell = [script objectForKey:CompositionConfigurationAdditionalProcessingScriptShellKey];
        break;
      case SCRIPT_SOURCE_FILE:
        scriptShell = @"/bin/bash";
        break;
    }//end switch(source)
    
    BOOL useLoginShell = [compositionConfiguration compositionConfigurationUseLoginShell];

    #ifdef ARC_ENABLED
    SystemTask* task = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
    #else
    SystemTask* task = [[[SystemTask alloc] initWithWorkingDirectory:workingDirectory] autorelease];
    #endif
    [task setUsingLoginShell:useLoginShell];
    [task setCurrentDirectoryPath:workingDirectory];
    [task setEnvironment:environment];
    [task setLaunchPath:scriptShell];
    [task setArguments:[NSArray arrayWithObjects:useLoginShell ? @"" : @"-l", @"-c", latexScriptPath, nil]];
    [task setCurrentDirectoryPath:[latexScriptPath stringByDeletingLastPathComponent]];

    [logString appendFormat:@"----------------- %@ script -----------------\n", NSLocalizedString(@"executing", @"")];
    [logString appendFormat:@"%@\n", [task equivalentLaunchCommand]];

    @try {
      [task setTimeOut:30];
      [task launch];
      [task waitUntilExit];
      if ([task hasReachedTimeout])
        [logString appendFormat:@"\n%@\n\n", NSLocalizedString(@"Script too long : timeout reached", @"")];
      else if ([task terminationStatus])
      {
        #ifdef ARC_ENABLED
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"")];
        NSString* outputLog1 = [[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding];
        NSString* outputLog2 = [[NSString alloc] initWithData:[task dataForStdError]  encoding:encoding];
        #else
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"")];
        NSString* outputLog1 = [[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding];
        NSString* outputLog2 = [[NSString alloc] initWithData:[task dataForStdError]  encoding:encoding];
        #endif
        [logString appendFormat:@"%@\n%@\n----------------------------------------------------\n", outputLog1, outputLog2];
      }
      else
      {
        #ifdef ARC_ENABLED
        NSString* outputLog = [[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding];
        #else
        NSString* outputLog = [[[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding] autorelease];
        #endif
        [logString appendFormat:@"\n%@\n----------------------------------------------------\n", outputLog];
      }
    }//end try task
    @catch(NSException* e) {
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"")];
        #ifdef ARC_ENABLED
        NSString* outputLog = [[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding];
        #else
        NSString* outputLog = [[[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding] autorelease];
        #endif
        [logString appendFormat:@"%@\n----------------------------------------------------\n", outputLog];
    }
  }//end if (source != SCRIPT_SOURCE_NONE)
}
//end executeScript:setEnvironment:logString:workingDirectory:uniqueIdentifier:compositionConfiguration:

//returns a file icon to represent the given PDF data; if not specified (nil), the backcground color will be half-transparent
-(NSImage*) makeIconForData:(NSData*)pdfData backgroundColor:(NSColor*)backgroundColor
{
  NSImage* icon = nil;
  #ifdef ARC_ENABLED
  NSImage* image = [[NSImage alloc] initWithData:pdfData];
  #else
  NSImage* image = [[[NSImage alloc] initWithData:pdfData] autorelease];
  #endif
  NSSize imageSize = [image size];
  #ifdef ARC_ENABLED
  icon = [[NSImage alloc] initWithSize:NSMakeSize(128, 128)];
  #else
  icon = [[[NSImage alloc] initWithSize:NSMakeSize(128, 128)] autorelease];
  #endif
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
      [image drawInRect:dstRect fromRect:srcRect operation:NSCompositingOperationSourceOver fraction:1];
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
  #ifdef ARC_ENABLED
  NSAlert* alert = [[NSAlert alloc] init];
  #else
  NSAlert* alert = [[[NSAlert alloc] init] autorelease];
  #endif
  [alert setMessageText:NSLocalizedString(@"Error", @"")];
  [alert setInformativeText:!informativeText1 ? @"" : informativeText1];
  [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
  [alert addButtonWithTitle:NSLocalizedString(@"Display the error message", @"")];
  [alert setAlertStyle:NSAlertStyleCritical];
  NSInteger displayError = [alert runModal];
  if (displayError == NSAlertSecondButtonReturn)
  {
    NSString* informativeText2 = [[objects objectForKey:@"informativeText2"] dynamicCastToClass:[NSString class]];
    DebugLog(1, @"displayAlertError:informativeText2:<%@>", informativeText2);
    #ifdef ARC_ENABLED
    NSAlert* alert2 = [[NSAlert alloc] init];
    #else
    NSAlert* alert2 = [[[NSAlert alloc] init] autorelease];
    #endif
    [alert2 setMessageText:NSLocalizedString(@"Error message", @"")];
    [alert2 setInformativeText:!informativeText2 ? @"" : informativeText2];
    [alert2 addButtonWithTitle:NSLocalizedString(@"OK", @"")];
    [alert2 setAlertStyle:NSAlertStyleInformational];
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
  DebugLog(1, @"pdfData = %p(%@)", pdfData, @([pdfData length]));
  DebugLog(1, @"exportOptions = %@", exportOptions);
  DebugLog(1, @"compositionConfiguration = %@", compositionConfiguration);
  NSString* temporaryDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
  DebugLog(1, @"temporaryDirectory = %@", temporaryDirectory);
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

    NSColor* jpegColor = [[exportOptions objectForKey:@"jpegColor"] dynamicCastToClass:[NSColor class]];
    CGFloat jpegQuality = [[[exportOptions objectForKey:@"jpegQuality"] dynamicCastToClass:[NSNumber class]] floatValue];
    CGFloat scaleAsPercent = [[[exportOptions objectForKey:@"scaleAsPercent"] dynamicCastToClass:[NSNumber class]] floatValue];
    BOOL exportIncludeBackgroundColor = [[[exportOptions objectForKey:@"exportIncludeBackgroundColor"] dynamicCastToClass:[NSNumber class]] boolValue];
    BOOL textExportPreamble = [[[exportOptions objectForKey:@"textExportPreamble"] dynamicCastToClass:[NSNumber class]] boolValue];
    BOOL textExportEnvironment = [[[exportOptions objectForKey:@"textExportEnvironment"] dynamicCastToClass:[NSNumber class]] boolValue];
    BOOL textExportBody = [[[exportOptions objectForKey:@"textExportBody"] dynamicCastToClass:[NSNumber class]] boolValue];
    
    DebugLog(1, @"pdfData = %p(%@)", pdfData, @([pdfData length]));
    if (pdfData)
    {
      NSDictionary* equationMetaData = [LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0];
      NSColor* backgroundColor = [equationMetaData objectForKey:@"backgroundColor"];
      
      DebugLog(1, @"equationMetaData = %@", equationMetaData);
      PreferencesController* preferencesController = [PreferencesController sharedController];
      BOOL annotationsGraphicCommandsInvisibleEnabled =
        (format == EXPORT_FORMAT_PDF) ? [preferencesController exportPDFMetaDataInvisibleGraphicsEnabled] :
        (format == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) ? [preferencesController exportPDFWOFMetaDataInvisibleGraphicsEnabled] :
        NO;
      BOOL shouldRecreatePDF =
        (annotationsGraphicCommandsInvisibleEnabled && ![LatexitEquation hasInvisibleGraphicCommandsInPDFData:pdfData]) ||
        (backgroundColor && exportIncludeBackgroundColor) ||
        (scaleAsPercent != 100);
      DebugLog(1, @"shouldRecreatePDF = %@", @(shouldRecreatePDF));
      if (shouldRecreatePDF)
      {
        CGDataProviderRef pdfOriginalDataProvider = !pdfData ? 0 : CGDataProviderCreateWithCFData((CFDataRef)pdfData);
        DebugLog(1, @"pdfOriginalDataProvider = %p", pdfOriginalDataProvider);
        CGPDFDocumentRef pdfOriginalDocument = !pdfOriginalDataProvider ? 0 : CGPDFDocumentCreateWithProvider(pdfOriginalDataProvider);
        DebugLog(1, @"pdfOriginalDocument = %p", pdfOriginalDocument);
        CGPDFPageRef pdfOriginalPage = !pdfOriginalDocument ? 0 : CGPDFDocumentGetPage(pdfOriginalDocument, 1);
        DebugLog(1, @"pdfOriginalPage = %p", pdfOriginalPage);
        //CGRect pdfOriginalMediaBox = !pdfOriginalPage ? CGRectZero : CGPDFPageGetBoxRect(pdfOriginalPage, kCGPDFMediaBox);
        CGRect pdfOriginalCropBox = !pdfOriginalPage ? CGRectZero : CGPDFPageGetBoxRect(pdfOriginalPage, kCGPDFCropBox);
        CGRect pdfOriginalBox = pdfOriginalCropBox;

        NSMutableData* pdfScaledMutableData = [NSMutableData data];
        CGDataConsumerRef pdfScaledDataConsumer = !pdfScaledMutableData ? 0 :
          CGDataConsumerCreateWithCFData((CFMutableDataRef)pdfScaledMutableData);
        DebugLog(1, @"pdfScaledDataConsumer = %p", pdfScaledDataConsumer);
        CGRect pdfScaledMediaBox = (scaleAsPercent == 100) ? pdfOriginalBox :
          CGRectMake(0, 0,
            ceil((scaleAsPercent/100)*pdfOriginalBox.size.width),
            ceil((scaleAsPercent/100)*pdfOriginalBox.size.height));
        CGContextRef pdfContext = !pdfScaledDataConsumer ? 0 : CGPDFContextCreate(pdfScaledDataConsumer, &pdfScaledMediaBox, 0);
        DebugLog(1, @"pdfContext = %p", pdfContext);
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
       
        #ifdef ARC_ENABLED
        NSData* resizedPdfData = [pdfScaledMutableData copy];
        #else
        NSData* resizedPdfData = [[pdfScaledMutableData copy] autorelease];
        #endif
        DebugLog(1, @"resizedPdfData = %p(%@)", resizedPdfData, @([resizedPdfData length]));
        /*NSPDFImageRep* pdfImageRep = [[NSPDFImageRep alloc] initWithData:pdfData];
        NSSize originalSize = [pdfImageRep size];
        NSImage* pdfImage = [[NSImage alloc] initWithSize:originalSize];
        [pdfImage setCacheMode:NSImageCacheNever];
        [pdfImage setDataRetained:YES];
        [pdfImage setScalesWhenResized:YES];
        [pdfImage addRepresentation:pdfImageRep];
        NSImageView* imageView =
          [[NSImageView alloc] initWithFrame:
            NSMakeRect(0, 0, ceil(originalSize.width*scaleAsPercent/100), ceil(originalSize.height*scaleAsPercent/100))];
        [imageView setImageScaling:NSScaleToFit];
        [imageView setImage:pdfImage];
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
        DebugLog(1, @"pdfData annotated = %p(%@)", pdfData, @([pdfData length]));
        #warning 64bits problem
        BOOL shouldDenyDueTo64Bitsproblem = (sizeof(NSInteger) != 4);
        DebugLog(1, @"shouldDenyDueTo64Bitsproblem = %@", @(shouldDenyDueTo64Bitsproblem));
        if (pdfData && !shouldDenyDueTo64Bitsproblem)
        {
          //in the meta-data of the PDF we store as much info as we can : preamble, body, size, color, mode, baseline...
          PDFDocument* pdfDocument = nil;
          @try{
            pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
            DebugLog(1, @"pdfDocument = %@", pdfDocument);
            NSDictionary* attributes = @{PDFDocumentCreatorAttribute:[[NSWorkspace sharedWorkspace] applicationName]};
            DebugLog(1, @"attributes = %@", attributes);
            [pdfDocument setDocumentAttributes:attributes];
            pdfData = [pdfDocument dataRepresentation];
            DebugLog(1, @"pdfData = %p(%@)", pdfData, @([pdfData length]));
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

      DebugLog(1, @"gsPath = %@", gsPath);
      DebugLog(1, @"gsArguments = %@", gsArguments);
      DebugLog(1, @"psToPdfPath = %@", psToPdfPath);
      DebugLog(1, @"psToPdfArguments = %@", psToPdfArguments);
      DebugLog(1, @"format = %@", @(format));
      if (format == EXPORT_FORMAT_PDF)
      {
        data = pdfData;
        BOOL reannotate = NO;
        NSDictionary* metaData = !reannotate ? nil : [LatexitEquation metaDataFromPDFData:data useDefaults:NO outPdfData:nil];
        DebugLog(1, @"metaData = %@", metaData);
        if (metaData)
        {
          NSAttributedString* preamble = [[metaData objectForKey:@"preamble"] dynamicCastToClass:[NSAttributedString class]];
          NSAttributedString* sourceText = [[metaData objectForKey:@"sourceText"] dynamicCastToClass:[NSAttributedString class]];
          NSColor* color = [[metaData objectForKey:@"color"] dynamicCastToClass:[NSColor class]];
          NSColor* backgroundColor = [[metaData objectForKey:@"backgroundColor"] dynamicCastToClass:[NSColor class]];
          NSNumber* mode = [[metaData objectForKey:@"mode"] dynamicCastToClass:[NSNumber class]];
          NSNumber* magnification = [[metaData objectForKey:@"magnification"] dynamicCastToClass:[NSNumber class]]; 
          NSString* title = [[metaData objectForKey:@"title"] dynamicCastToClass:[NSString class]];
          DebugLog(1, @"title = %@", title);
          DebugLog(1, @">stripPdfData");
          data = [self stripPdfData:data];
          DebugLog(1, @"data = %p(%@)", data, @([data length]));
          DebugLog(1, @"<stripPdfData");
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
          NSString* writeEngine = [preferencesController exportPDFWOFGsWriteEngine];
          NSString* compatibilityLevel = [preferencesController exportPDFWOFGsPDFCompatibilityLevel];
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
          int error = system([systemCall UTF8String]);
          if (error)
          {
            #ifdef ARC_ENABLED
            NSString* output = [[NSString alloc] initWithData:[tmpFileHandle availableData] encoding:NSUTF8StringEncoding];
            #else
            NSString* output = [[[NSString alloc] initWithData:[tmpFileHandle availableData] encoding:NSUTF8StringEncoding] autorelease];
            #endif
            NSString* formatString1 = NSLocalizedString(@"An error occured while trying to create the file with command:\n%@", @"");
            DebugLog(1, @"formatString1 = %@", formatString1);
            NSString* informativeText1 = [NSString stringWithFormat:formatString1, systemCall];
            DebugLog(1, @"informativeText1 = %@", informativeText1);
            NSString* informativeText2 = [NSString stringWithFormat:@"%@ %d:\n%@", NSLocalizedString(@"Error", @""), error, !output ? @"..." : output];
            DebugLog(1, @"informativeText2 = %@", informativeText2);
            NSDictionary* alertInformation = @{@"informativeText1":informativeText1,@"informativeText2":informativeText2};
            NSMutableDictionary* alertInformationWrapper =
              [[exportOptions objectForKey:@"alertInformationWrapper"] dynamicCastToClass:[NSMutableDictionary class]];
            if (alertInformationWrapper)
              [alertInformationWrapper setObject:alertInformation forKey:@"alertInformation"];
            else
              [self performSelectorOnMainThread:@selector(displayAlertError:)
                                     withObject:alertInformation
                                  waitUntilDone:YES];
            unlink([tmpFilePath UTF8String]);
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
            
            [self crop:tmpPdfFilePath to:tmpPdfFilePath canClip:YES extraArguments:[NSArray array]
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
                                           preamble:[[latexitEquation preamble] string]
                                             source:[[latexitEquation sourceText] string]
                                              color:[latexitEquation color] mode:[latexitEquation mode]
                                      magnification:[latexitEquation pointSize]
                                           baseline:0
                                    backgroundColor:[latexitEquation backgroundColor] title:[latexitEquation title]
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
          [gsTask setUsingLoginShell:useLoginShell];
          [gsTask setCurrentDirectoryPath:temporaryDirectory];
          [gsTask setEnvironment:self->globalExtraEnvironment];
          [gsTask setLaunchPath:gsPath];
          [gsTask setArguments:[gsArguments arrayByAddingObjectsFromArray:
            [NSArray arrayWithObjects:@"-sstdout=%stderr -dNOPAUSE", @"-dNOCACHE", @"-dBATCH", @"-dSAFER", @"-dNOPLATFONTS",
               [NSString stringWithFormat:@"-sDEVICE=%@", isGS915OrAbove ? @"eps2write" : @"epswrite"],
               [NSString stringWithFormat:@"-sOutputFile=%@", tmpEpsFilePath], pdfFilePath, nil]]];
          [gsTask launch];
          [gsTask waitUntilExit];
        }
        @catch(NSException* e)
        {
          [errorString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", [e name], [e reason]]];
        }
        @finally
        {
          NSData* errorData = [gsTask dataForStdError];
          #ifdef ARC_ENABLED
          [errorString appendString:[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding]];
          #else
          [errorString appendString:[[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] autorelease]];
          #endif

          if ([gsTask terminationStatus] != 0)
          {
            NSAlert* alert = [[[NSAlert alloc] init] autorelease];
            alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file :\n%@", @""),
                                                       errorString];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
            [alert runModal];
          }
          #ifdef ARC_ENABLED
          #else
          [gsTask release];
          #endif
        }
        data = [NSData dataWithContentsOfFile:tmpEpsFilePath options:NSUncachedRead error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:tmpEpsFilePath error:0];
        [[NSFileManager defaultManager] removeItemAtPath:pdfFilePath error:0];
        DebugLog(1, @"create EPS data %p (%ld)", data, (unsigned long)[data length]);
      }//end if (format == EXPORT_FORMAT_EPS)
      else if (format == EXPORT_FORMAT_TIFF)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentationDpiAwareUsingCompression:NSTIFFCompressionLZW factor:0];
        #ifdef ARC_ENABLED
        #else
        [image release];
        #endif
        NSData* annotationData =
          isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0] requiringSecureCoding:YES error:nil] :
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:(NSString*)kUTTypeTIFF withData:annotationDataCompressed];
        DebugLog(1, @"create TIFF data %p (%ld)", data, (unsigned long)[data length]);
      }//end if (format == EXPORT_FORMAT_TIFF)
      else if (format == EXPORT_FORMAT_PNG)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentationDpiAwareUsingCompression:NSTIFFCompressionLZW factor:15.0];
        NSBitmapImageRep* imageRep = [NSBitmapImageRep imageRepWithData:data];
        data = [imageRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        #ifdef ARC_ENABLED
        #else
        [image release];
        #endif
        NSData* annotationData =
          isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0] requiringSecureCoding:YES error:nil] :
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
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef cgContext = !colorSpace || !bytesPerRow ? 0 :
          CGBitmapContextCreate(0, width, height, 8, 0, colorSpace, kCGImageAlphaPremultipliedLast);
        CGImageRef cgImage = 0;
        if (cgContext)
        {
          NSColor* rgbColor = [jpegColor colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
          CGContextSetRGBFillColor(cgContext,
            [rgbColor redComponent], [rgbColor greenComponent], [rgbColor blueComponent], [rgbColor alphaComponent]);
          CGContextFillRect(cgContext, CGRectMake(0, 0, width, height));
          CGContextDrawPDFPage(cgContext, pdfPage);
          CGContextFlush(cgContext);
          cgImage = CGBitmapContextCreateImage(cgContext);
          CGContextRelease(cgContext);
        }//end if (cgContext)
        CGColorSpaceRelease(colorSpace);
        CGPDFDocumentRelease(pdfDocument);
        CGDataProviderRelease(pdfDataProvider);

        NSMutableData* mutableData = !cgImage ? nil : [NSMutableData data];
        CGImageDestinationRef cgImageDestination = !mutableData ? 0 : CGImageDestinationCreateWithData(
          (CHBRIDGE CFMutableDataRef)mutableData, CFSTR("public.jpeg"), 1, 0);
        if (cgImageDestination && cgImage)
        {
          CGImageDestinationAddImage(cgImageDestination, cgImage,
            (CHBRIDGE CFDictionaryRef)@{(NSString*)kCGImageDestinationLossyCompressionQuality:@(jpegQuality/100)});
          CGImageDestinationFinalize(cgImageDestination);
          CFRelease(cgImageDestination);
        }//end if (cgImageDestination && cgImage)
        CGImageRelease(cgImage);

        data = mutableData;
        NSData* annotationData =
          isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0] requiringSecureCoding:YES error:nil] :
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
          [svgTask setUsingLoginShell:useLoginShell];
          [svgTask setCurrentDirectoryPath:temporaryDirectory];
          [svgTask setEnvironment:self->globalExtraEnvironment];
          [svgTask setLaunchPath:pdf2svgPath];
          [svgTask setArguments:[NSArray arrayWithObjects:pdfFilePath, tmpSvgFilePath, nil]];
          [svgTask launch];
          [svgTask waitUntilExit];
        }
        @catch(NSException* e)
        {
          [errorString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", [e name], [e reason]]];
        }
        @finally
        {
          NSData* errorData = [svgTask dataForStdError];
          #ifdef ARC_ENABLED
          [errorString appendString:[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding]];
          #else
          [errorString appendString:[[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] autorelease]];
          #endif

          if ([svgTask terminationStatus] != 0)
          {
            NSAlert* alert = [[[NSAlert alloc] init] autorelease];
            alert.messageText = [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file :\n%@", @""),
                                                       errorString];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
            [alert runModal];
          }//end if ([svgTask terminationStatus] != 0)
          #ifdef ARC_ENABLED          
          #else
          [svgTask release];
          #endif
        }
        data = [NSData dataWithContentsOfFile:tmpSvgFilePath options:NSUncachedRead error:nil];
        NSData* annotationData =
          isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0] requiringSecureCoding:YES error:nil] :
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:GetMySVGPboardType() withData:annotationDataCompressed];
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
        NSString* sourceString = [sourceText string];
        NSString* escapedSourceString = [sourceString stringByReplacingOccurrencesOfRegex:@"&(?!amp;)" withString:@"&amp;"];
        NSColor* rgbaColor = [[metaData objectForKey:@"color"] colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]];
        CGFloat rgba_f[4] = {0};
        [rgbaColor getRed:&rgba_f[0] green:&rgba_f[1] blue:&rgba_f[2] alpha:&rgba_f[3]];
        int rgba_i[4] = {0};
        NSUInteger i = 0;
        for(i = 0 ; i<4 ; ++i)
          rgba_i[i] = MAX(0, MIN(255, round(255*rgba_f[i])));
        NSString* inputString = [NSString stringWithFormat:@"<body><blockquote style=\"color:rgba(%d,%d,%d,%d);color:rgb(%d,%d,%d);font-size:%.2fpt;\">%@%@%@</blockquote></body>",
          rgba_i[0], rgba_i[1], rgba_i[2], rgba_i[3],
          rgba_i[0], rgba_i[1], rgba_i[2],
          [[[metaData objectForKey:@"magnification"] dynamicCastToClass:[NSNumber class]] doubleValue],
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
          [laTeXMathMLTask setUsingLoginShell:useLoginShell];
          [laTeXMathMLTask setEnvironment:fullEnvironment];
          [laTeXMathMLTask setLaunchPath:@"perl"];
          [laTeXMathMLTask setArguments:arguments];
          [laTeXMathMLTask setCurrentDirectoryPath:workingDirectory];
          [laTeXMathMLTask launch];
          [laTeXMathMLTask waitUntilExit];
          int terminationStatus = [laTeXMathMLTask terminationStatus];
          ok = (terminationStatus == 0);
          #ifdef ARC_ENABLED
          NSString* logStdOut = ok ? nil :
            [[NSString alloc] initWithData:[laTeXMathMLTask dataForStdOutput] encoding:NSUTF8StringEncoding];
          NSString* logStdErr = ok ? nil :
            [[NSString alloc] initWithData:[laTeXMathMLTask dataForStdError] encoding:NSUTF8StringEncoding];
          #else
          NSString* logStdOut = ok ? nil :
            [[[NSString alloc] initWithData:[laTeXMathMLTask dataForStdOutput] encoding:NSUTF8StringEncoding] autorelease];
          NSString* logStdErr = ok ? nil :
            [[[NSString alloc] initWithData:[laTeXMathMLTask dataForStdError] encoding:NSUTF8StringEncoding] autorelease];
          #endif
          if (!ok)
          {
            DebugLog(1, @"command = %@", [laTeXMathMLTask commandLine]);
            DebugLog(1, @"terminationStatus = %d", terminationStatus);
            DebugLog(1, @"logStdOut = %@", logStdOut);
            DebugLog(1, @"logStdErr = %@", logStdErr);
          }//end if (!ok)
          #ifdef ARC_ENABLED
          #else
          [laTeXMathMLTask release];
          #endif
          data = [NSData dataWithContentsOfFile:outputFile];
          #ifdef ARC_ENABLED
          NSString* rawResult = !data ? nil : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
          #else
          NSString* rawResult = !data ? nil : [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
          #endif
          NSString* fixedResult = !rawResult ? nil : mathMLFix(rawResult);
          data = !fixedResult ? data : [fixedResult dataUsingEncoding:NSUTF8StringEncoding];
          NSData* annotationData =
            isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:metaData requiringSecureCoding:YES error:nil] :
            [NSKeyedArchiver archivedDataWithRootObject:metaData];
          NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
          data = [self annotateData:data ofUTI:(NSString*)kUTTypeHTML withData:annotationDataCompressed];
          [[NSFileManager defaultManager] removeItemAtPath:outputFile error:0];
        }//end if (ok)
        [[NSFileManager defaultManager] removeItemAtPath:inputFile error:0];
      }//end if (format == EXPORT_FORMAT_MATHML)
      else if (format == EXPORT_FORMAT_TEXT)
      {
        NSDictionary* equationMetaData = [LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:0];
        NSString* preamble = [[equationMetaData objectForKey:@"preamble"] string];
        NSString* source = [[equationMetaData objectForKey:@"sourceText"] string];
        latex_mode_t latexMode = (latex_mode_t)[[equationMetaData objectForKey:@"mode"] integerValue];
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
        UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.tiff")) ||
        UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.png")) ||
        UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.jpeg")))
    {
      NSString* annotationDataBase64 = [annotationData encodeBase64];
      NSMutableData* annotatedData = !annotationDataBase64 ? nil : [[NSMutableData alloc] initWithCapacity:[inputData length]];
      CGImageSourceRef imageSource = !annotatedData ? 0 :
        CGImageSourceCreateWithData((CHBRIDGE CFDataRef)inputData,
          (CHBRIDGE CFDictionaryRef)@{(NSString*)kCGImageSourceShouldCache:@(NO)});
      CFStringRef detectedUTI = !imageSource ? 0 : CGImageSourceGetType(imageSource);
      if (( sourceUTI && UTTypeConformsTo(detectedUTI, (CHBRIDGE CFStringRef)sourceUTI)) ||
          (!sourceUTI && (UTTypeConformsTo(detectedUTI, CFSTR("public.tiff")) ||
                          UTTypeConformsTo(detectedUTI, CFSTR("public.png")) || 
                          UTTypeConformsTo(detectedUTI, CFSTR("public.jpeg")))))
      {
        CGImageDestinationRef imageDestination = !imageSource ? 0 :
          CGImageDestinationCreateWithData((CHBRIDGE CFMutableDataRef)annotatedData,
                                           sourceUTI ? (CHBRIDGE CFStringRef)sourceUTI : detectedUTI, 1, 0);
        NSDictionary* propertiesImmutable = nil;
        NSMutableDictionary* properties = nil;
        if (imageSource && imageDestination)
        {
          #ifdef ARC_ENABLED
          propertiesImmutable = (CHBRIDGE NSDictionary*)CGImageSourceCopyPropertiesAtIndex(imageSource, 0, 0);
          properties = [propertiesImmutable mutableCopyDeep];
          #else
          propertiesImmutable = NSMakeCollectable((CHBRIDGE NSDictionary*)CGImageSourceCopyPropertiesAtIndex(imageSource, 0, 0));
          properties = [[propertiesImmutable mutableCopyDeep] autorelease];
          #endif
          NSMutableDictionary* exifDictionary = [properties objectForKey:(NSString*)kCGImagePropertyExifDictionary];
          if (!exifDictionary)
          {
            exifDictionary = [NSMutableDictionary dictionaryWithCapacity:1];
            [properties setObject:exifDictionary forKey:(NSString*)kCGImagePropertyExifDictionary];
          }//end if (!exifDictionary)
          [exifDictionary setObject:annotationDataBase64 forKey:(NSString*)kCGImagePropertyExifUserComment];
        }//if (imageSource && imageDestination)
        #ifdef ARC_ENABLED
        #else
        [propertiesImmutable release];
        #endif
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
        #ifdef ARC_ENABLED
        result = [annotatedData copy];
        #else
        result = [[annotatedData copy] autorelease];
        #endif
      #ifdef ARC_ENABLED
      #else
      [annotatedData release];
      #endif
    }//end if (tiff, png, jpeg)
    else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.svg-image")))
    {
      NSString* annotationDataBase64 = [annotationData encodeBase64];
      #ifdef ARC_ENABLED
      NSMutableString* outputString = !annotationDataBase64 ? nil :
        [[NSMutableString alloc] initWithData:inputData encoding:NSUTF8StringEncoding];
      #else
      NSMutableString* outputString = !annotationDataBase64 ? nil :
        [[[NSMutableString alloc] initWithData:inputData encoding:NSUTF8StringEncoding] autorelease];
      #endif
      NSError* error = nil;
      [outputString
         replaceOccurrencesOfRegex:@"<svg(.*?)>(.*)</svg>"
         withString:[NSString stringWithFormat:@"<svg$1><!--latexit:%@-->$2</svg>", annotationDataBase64]
         options:RKLCaseless|RKLDotAll|RKLMultiline range:outputString.range error:&error];
      if (error)
        DebugLog(0, @"error : %@", error);
      result = !outputString ? nil : [outputString dataUsingEncoding:NSUTF8StringEncoding];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.svg-image")))
    else if (UTTypeConformsTo((CHBRIDGE CFStringRef)sourceUTI, CFSTR("public.html")))
    {
      NSString* annotationDataBase64 = [annotationData encodeBase64];
      #ifdef ARC_ENABLED
      NSMutableString* outputString = !annotationDataBase64 ? nil :
        [[NSMutableString alloc] initWithData:inputData encoding:NSUTF8StringEncoding];
      #else
      NSMutableString* outputString = !annotationDataBase64 ? nil :
        [[[NSMutableString alloc] initWithData:inputData encoding:NSUTF8StringEncoding] autorelease];
      #endif
      NSError* error = nil;
      [outputString replaceOccurrencesOfRegex:@"<blockquote(.*?)>(.*?)</blockquote>"
         withString:[NSString stringWithFormat:@"<blockquote$1><!--latexit:%@-->$2</blockquote>", annotationDataBase64]
            options:RKLCaseless|RKLDotAll|RKLMultiline range:outputString.range error:&error];
      if (error)
        DebugLog(0, @"error : %@", error);
      result = !outputString ? nil : [outputString dataUsingEncoding:NSUTF8StringEncoding];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.html")))
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
    [gsTask setUsingLoginShell:useLoginShell];
    [gsTask setCurrentDirectoryPath:temporaryDirectory];
    [gsTask setEnvironment:self->globalExtraEnvironment];
    [gsTask setLaunchPath:gsPath];
    [gsTask setArguments:@[@"--version"]];
    [gsTask launch];
    [gsTask waitUntilExit];
    NSData* stdOutputData = [gsTask dataForStdOutput];
    #ifdef ARC_ENABLED
    result = !stdOutputData ? nil :
      [[[NSString alloc] initWithData:stdOutputData encoding:NSUTF8StringEncoding]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    #else
    result = !stdOutputData ? nil :
      [[[[NSString alloc] initWithData:stdOutputData encoding:NSUTF8StringEncoding] autorelease]
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    #endif
  }
  @catch(NSException* e)
  {
  }
  @finally
  {
    #ifdef ARC_ENABLED
    #else
    [gsTask release];
    #endif
  }
  return result;
}
//end getGSVersion:
  
@end
