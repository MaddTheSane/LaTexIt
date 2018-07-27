//
//  LaTeXProcessor.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/09/08.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "LaTeXProcessor.h"

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
#import "Utils.h"

#import "RegexKitLite.h"

#import <Quartz/Quartz.h>

NSString* LatexizationDidEndNotification = @"LatexizationDidEndNotification";

//In MacOS 10.4.0, 10.4.1 and 10.4.2, these constants are declared but not defined in the PDFKit.framework!
//So I define them myself, but it is ugly. I expect next versions of MacOS to fix that
NSString* PDFDocumentCreatorAttribute = @"Creator"; 
NSString* PDFDocumentKeywordsAttribute = @"Keywords";

@interface LaTeXProcessor (PrivateAPI)
-(void) initializeEnvironment;
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
  [self->managedObjectModel     release];
  [self->unixBins               release];
  [self->globalExtraEnvironment release];
  [self->globalFullEnvironment  release];
  [self->globalExtraEnvironment release];
  [super dealloc];
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
        NSString* systemCall = [NSString stringWithFormat:@". /etc/profile && /bin/echo \"$PATH\" >| %@",
                                temporaryPathFilePath, temporaryPathFilePath];
        int error = system([systemCall UTF8String]);
        NSError* nserror = nil;
        NSStringEncoding encoding = NSUTF8StringEncoding;
        NSArray* profileBins =
          error ? [NSArray array] :
          [[[NSString stringWithContentsOfFile:temporaryPathFilePath guessEncoding:&encoding error:&nserror] trim] componentsSeparatedByString:@":"];
    
        self->unixBins = [[NSMutableArray alloc] initWithArray:profileBins];
  
        //usual unix PATH (to find latex)
        NSArray* usualBins = 
          [NSArray arrayWithObjects:@"/bin", @"/sbin",
            @"/usr/bin", @"/usr/sbin",
            @"/usr/local/bin", @"/usr/local/sbin",
            @"/usr/texbin", @"/usr/local/texbin",
            @"/sw/bin", @"/sw/sbin",
            @"/sw/usr/bin", @"/sw/usr/sbin",
            @"/sw/local/bin", @"/sw/local/sbin",
            @"/sw/usr/local/bin", @"/sw/usr/local/sbin",
            @"/opt/local/bin", @"/opt/local/sbin",
            nil];
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
  [self->globalEnvironmentPath setString:[[componentsSet allObjects] componentsJoinedByString:@":"]];
}
//end addInEnvironmentPath

-(NSData*) annotatePdfDataInLEEFormat:(NSData*)data preamble:(NSString*)preamble source:(NSString*)source color:(NSColor*)color
                                 mode:(mode_t)mode magnification:(double)magnification baseline:(double)baseline
                                 backgroundColor:(NSColor*)backgroundColor title:(NSString*)title
{
  NSMutableData* newData = nil;
  
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
      pdfDocument = [[PDFDocument alloc] initWithData:data];
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
            [NSNumber numberWithInt:mode], @"mode",
            [NSNumber numberWithDouble:magnification], @"magnification",
            [NSNumber numberWithDouble:baseline], @"baseline",
            [(!backgroundColor ? [NSColor whiteColor] : backgroundColor) colorAsData], @"backgroundColor",            
            title, @"title",
            nil]];
      NSString* embeddedDataBase64 = [embeddedData encodeBase64];
      if (isMacOS10_5OrAbove())
        [pdfAnnotation performSelector:@selector(setUserName:) withObject:@"fr.chachatelier.pierre.LaTeXiT"];
      [pdfAnnotation setContents:embeddedDataBase64];
      [pdfPage addAnnotation:pdfAnnotation];
      NSData* dataWithAnnotation = [pdfDocument dataRepresentation];
      data = !dataWithAnnotation ? data : dataWithAnnotation;
    }
    @catch(NSException* e){
      DebugLog(0, @"exception : %@", e);
    }
    @finally{
      [pdfAnnotation release];
      [pdfDocument release];
    }
  }//end if (embeddAsAnnotation)

  NSString* colorAsString   = [(color ? color : [NSColor blackColor]) rgbaString];
  NSString* bkColorAsString = [(backgroundColor ? backgroundColor : [NSColor whiteColor]) rgbaString];
  if (data)
  {
    NSMutableString* replacedPreamble = [NSMutableString stringWithString:preamble];
    [replacedPreamble replaceOccurrencesOfString:@"\\" withString:@"ESslash"      options:0 range:NSMakeRange(0, [replacedPreamble length])];
    [replacedPreamble replaceOccurrencesOfString:@"{"  withString:@"ESleftbrack"  options:0 range:NSMakeRange(0, [replacedPreamble length])];
    [replacedPreamble replaceOccurrencesOfString:@"}"  withString:@"ESrightbrack" options:0 range:NSMakeRange(0, [replacedPreamble length])];
    [replacedPreamble replaceOccurrencesOfString:@"$"  withString:@"ESdollar"     options:0 range:NSMakeRange(0, [replacedPreamble length])];

    CFStringRef cfEscapedPreamble =
      CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)preamble, NULL, NULL, kCFStringEncodingUTF8);
    NSMutableString* escapedPreamble = [NSMutableString stringWithString:(NSString*)cfEscapedPreamble];
    CFRelease(cfEscapedPreamble);

    NSMutableString* replacedSource = [NSMutableString stringWithString:source];
    [replacedSource replaceOccurrencesOfString:@"\\" withString:@"ESslash"      options:0 range:NSMakeRange(0, [replacedSource length])];
    [replacedSource replaceOccurrencesOfString:@"{"  withString:@"ESleftbrack"  options:0 range:NSMakeRange(0, [replacedSource length])];
    [replacedSource replaceOccurrencesOfString:@"}"  withString:@"ESrightbrack" options:0 range:NSMakeRange(0, [replacedSource length])];
    [replacedSource replaceOccurrencesOfString:@"$"  withString:@"ESdollar"     options:0 range:NSMakeRange(0, [replacedSource length])];

    CFStringRef cfEscapedSource =
      CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)source, NULL, NULL, kCFStringEncodingUTF8);
    NSMutableString* escapedSource = [NSMutableString stringWithString:(NSString*)cfEscapedSource];
    CFRelease(cfEscapedSource);

    NSString* type = [[NSNumber numberWithInt:mode] stringValue];
    
    BOOL annotateWithTransparentData = NO;
    if (annotateWithTransparentData)
    {
      NSDictionary* dictionaryContent = [NSDictionary dictionaryWithObjectsAndKeys:
        @"2.6.0", @"version",
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
        isMacOS10_6OrAbove() ?
          [NSPropertyListSerialization dataWithPropertyList:dictionaryContent format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil] :
          [NSPropertyListSerialization dataFromPropertyList:dictionaryContent format:NSPropertyListBinaryFormat_v1_0 errorDescription:nil];
      NSData* annotationContentRawData = dictionaryContentPlistData;
      NSData* annotationContentCompressedData = [Compressor zipcompress:annotationContentRawData];
      NSString* annotationContentBase64 = [annotationContentCompressedData encodeBase64WithNewlines:NO];
      NSData* annotationContentBase64Data =
        [[NSString stringWithFormat:@"<latexit sha1_base64=\"%@\">%@</latexit>",
          [[annotationContentBase64 dataUsingEncoding:NSUTF8StringEncoding] sha1Base64],
          annotationContentBase64]
          dataUsingEncoding:NSUTF8StringEncoding];
      NSMutableData* dataConsumerData = [NSMutableData data];
      CGDataConsumerRef dataConsumer = !dataConsumerData ? 0 :
        CGDataConsumerCreateWithCFData((CFMutableDataRef)dataConsumerData);
      CGDataProviderRef dataProvider = !data ? 0 :
        CGDataProviderCreateWithCFData((CFDataRef)data);
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
        CGPDFContextBeginPage(cgPDFContext, 0);
        CGContextDrawPDFPage(cgPDFContext, pdfPage);
        CGContextFlush(cgPDFContext);
        CGContextSelectFont(cgPDFContext, "Courier", 1, kCGEncodingMacRoman);
        CGContextSetRGBStrokeColor(cgPDFContext, 0, 0, 0, 0);
        CGContextSetTextDrawingMode(cgPDFContext, kCGTextInvisible);
        CGContextShowText(cgPDFContext, [annotationContentBase64Data bytes], [annotationContentBase64Data length]);
        CGPDFContextEndPage(cgPDFContext);
        CGContextFlush(cgPDFContext);
        CGContextRelease(cgPDFContext);
        dataRewritten = YES;
      }//end if (cgPDFContext && pdfPage)
      CGPDFDocumentRelease(pdfDocument);
      CGDataProviderRelease(dataProvider);
      CGDataConsumerRelease(dataConsumer);
      if (dataRewritten)
        data = dataConsumerData;
     }//end if (annotateWithTransparentData)
    
    BOOL annotateWithXML = NO;
    if (annotateWithXML)
    {
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
             [NSNumber numberWithUnsignedInteger:[annotationContentBase64 length]],
             annotationContentBase64];
      NSMutableString* pdfString = [[[NSMutableString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
      
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

      newData = [NSMutableData dataWithData:[data subdataWithRange:
        (r1.location != NSNotFound) ? NSMakeRange(0, r1.location) :
        (r2.location != NSNotFound) ? NSMakeRange(0, r2.location) :
        NSMakeRange(0, 0)]];
      [newData appendData:dataToAppend];
      data = newData;
    }//end if (annotateWithXML)

    NSMutableString *annotation =
        [NSMutableString stringWithFormat:
          @"\nobj\n<<\n/Encoding /MacRomanEncoding\n"\
           "/Preamble (ESannop%sESannopend)\n"\
           "/EscapedPreamble (ESannoep%sESannoepend)\n"\
           "/Subject (ESannot%sESannotend)\n"\
           "/EscapedSubject (ESannoes%sESannoesend)\n"\
           "/Type (EEtype%@EEtypeend)\n"\
           "/Color (EEcol%@EEcolend)\n"\
           "/BKColor (EEbkc%@EEbkcend)\n"\
           "/Title (EEtitle%@EEtitleend)\n"\
           "/Magnification (EEmag%fEEmagend)\n"\
           "/Baseline (EEbas%fEEbasend)\n"\
           ">>\nendobj\n",
          [replacedPreamble cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
          [escapedPreamble  cStringUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES],
          [replacedSource  cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
          [escapedSource   cStringUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES],
          type, colorAsString, bkColorAsString, (title ? title : @""), magnification, baseline];
          
    NSMutableString* pdfString = [[[NSMutableString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
    
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

    newData = [NSMutableData dataWithData:[data subdataWithRange:
      (r1.location != NSNotFound) ? NSMakeRange(0, r1.location) :
      (r2.location != NSNotFound) ? NSMakeRange(0, r2.location) :
      NSMakeRange(0, 0)]];
    [newData appendData:dataToAppend];
  }//end if data
  
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

-(void) latexiseWithConfiguration:(NSMutableDictionary*)configuration
{
  [configuration retain];
  BOOL runInBackgroundThread = [[configuration objectForKey:@"runInBackgroundThread"] boolValue];
  if (runInBackgroundThread)
  {
    [configuration setObject:[NSNumber numberWithBool:NO] forKey:@"runInBackgroundThread"];
    [NSApplication detachDrawingThread:@selector(latexiseWithConfiguration:) toTarget:self withObject:configuration];
  }//end if (runInBackgroundThread)
  else//if (!runInBackgroundThread)
  {
    NSMutableDictionary* configuration2 = [configuration deepMutableCopy];//will protect from preferences changes
    NSString* fullLog = [configuration2 objectForKey:@"outFullLog"];
    NSArray*  errors  = [configuration2 objectForKey:@"outErrors"];
    NSData*   pdfData = [configuration2 objectForKey:@"outPdfData"];
    id backgroundColor = [configuration2 objectForKey:@"backgroundColor"];
    NSString* result = [self latexiseWithPreamble:[configuration2 objectForKey:@"preamble"]
                          body:[configuration objectForKey:@"body"] color:[configuration2 objectForKey:@"color"]
                          mode:(latex_mode_t)[[configuration2 objectForKey:@"mode"] intValue]
                          magnification:[[configuration2 objectForKey:@"magnification"] doubleValue]
                          compositionConfiguration:[configuration2 objectForKey:@"compositionConfiguration"]
                          backgroundColor:(backgroundColor == [NSNull null]) ? nil : backgroundColor
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
    [configuration2 release];
    [[NSNotificationCenter defaultCenter] postNotificationName:LatexizationDidEndNotification object:configuration];
  }//end if (!runInBackgroundThread)
  [configuration autorelease];
}
//end latexiseWithConfiguration:

//latexise and returns the pdf result, cropped, magnified, coloured, with pdf meta-data
-(NSString*) latexiseWithPreamble:(NSString*)preamble body:(NSString*)body color:(NSColor*)color mode:(latex_mode_t)latexMode 
                    magnification:(double)magnification compositionConfiguration:(NSDictionary*)compositionConfiguration
                    backgroundColor:(NSColor*)backgroundColor
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
  [fileManager bridge_removeItemAtPath:latexFilePath            error:0];
  [fileManager bridge_removeItemAtPath:latexAuxFilePath         error:0];
  [fileManager bridge_removeItemAtPath:latexFilePath2           error:0];
  [fileManager bridge_removeItemAtPath:latexAuxFilePath2        error:0];
  [fileManager bridge_removeItemAtPath:pdfFilePath              error:0];
  [fileManager bridge_removeItemAtPath:dviFilePath              error:0];
  [fileManager bridge_removeItemAtPath:pdfFilePath2             error:0];
  [fileManager bridge_removeItemAtPath:pdfCroppedFilePath       error:0];
  [fileManager bridge_removeItemAtPath:latexBaselineFilePath    error:0];
  [fileManager bridge_removeItemAtPath:latexAuxBaselineFilePath error:0];
  [fileManager bridge_removeItemAtPath:pdfBaselineFilePath      error:0];
  [fileManager bridge_removeItemAtPath:sizesFilePath            error:0];
  
  //trash *.*pk, *.mf, *.tfm, *.mp, *.script, *.[[:digit:]], *.t[[:digit:]]+
  NSArray* files = [fileManager bridge_contentsOfDirectoryAtPath:workingDirectory error:0];
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
        [fileManager bridge_removeItemAtPath:file error:0];
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
                               inRange:NSMakeRange(0, [colouredPreamble length]) capture:2 error:nil];
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
  unsigned int nbNewLinesInTrimmedHeader = MAX(1U, [[trimmedHeader componentsSeparatedByString:@"\n"] count]);
  int errorLineShift = MAX((int)0, (int)nbNewLinesInTrimmedHeader-1);
  
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
       [colouredPreamble replaceYenSymbol],
       (compositionMode == COMPOSITION_MODE_XELATEX) ? colorString : @"",
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
    [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Pre-processing", @"Pre-processing")];
    [fullLog appendFormat:@"%@\n", [self descriptionForScript:script]];
    [self executeScript:script setEnvironment:environment1 logString:fullLog workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
      compositionConfiguration:compositionConfiguration];
    if (outFullLog) *outFullLog = fullLog;
  }

  NSString* customLog = nil;
  NSString* stdoutLog = nil;
  NSString* stderrLog = nil;
  failed |= ![self composeLaTeX:latexFilePath customLog:&customLog stdoutLog:&stdoutLog stderrLog:&stderrLog
                compositionConfiguration:compositionConfiguration fullEnvironment:fullEnvironment];
  if (customLog)
    [fullLog appendString:customLog];
  if (outFullLog) *outFullLog = fullLog;

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
                             workingDirectory:workingDirectory fullEnvironment:fullEnvironment compositionConfiguration:compositionConfiguration];
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
          (compositionMode == COMPOSITION_MODE_XELATEX) ? @"false" : @"true",
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
        NSString* gsPath       = [compositionConfiguration compositionConfigurationProgramPathGs];
        
        NSString* texcmdtype = (compositionMode == COMPOSITION_MODE_XELATEX) ? @"--xetex" : @"--pdftex";
        NSString* texcmd = (compositionMode == COMPOSITION_MODE_XELATEX) ? @"--xetexcmd" : @"--pdftexcmd";
        NSString* texcmdparameter = (compositionMode == COMPOSITION_MODE_XELATEX) ? xeLaTeXPath : pdfLaTeXPath;
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
        [self crop:pdfBaselineFilePath to:pdfCroppedFilePath canClip:(compositionMode != COMPOSITION_MODE_XELATEX) extraArguments:extraArguments compositionConfiguration:compositionConfiguration
          workingDirectory:workingDirectory environment:fullEnvironment outPdfData:&pdfData];
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
                                   workingDirectory:workingDirectory fullEnvironment:fullEnvironment compositionConfiguration:compositionConfiguration];
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
          (compositionMode == COMPOSITION_MODE_XELATEX) ? @"false" : @"true",
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
                       [NSNumber numberWithInt:COMPOSITION_MODE_PDFLATEX], CompositionConfigurationCompositionModeKey, nil]
                     fullEnvironment:fullEnvironment];
      failed |= !pdfData;
      //call pdfcrop
      if (!failed)
      {
        NSString* pdfLaTeXPath = [compositionConfiguration compositionConfigurationProgramPathPdfLaTeX];
        NSString* xeLaTeXPath  = [compositionConfiguration compositionConfigurationProgramPathXeLaTeX];
        NSString* gsPath       = [compositionConfiguration compositionConfigurationProgramPathGs];
        
        NSString* texcmdtype = (compositionMode == COMPOSITION_MODE_XELATEX) ? @"--xetex" : @"--pdftex";
        NSString* texcmd = (compositionMode == COMPOSITION_MODE_XELATEX) ? @"--xetexcmd" : @"--pdftexcmd";
        NSString* texcmdparameter = (compositionMode == COMPOSITION_MODE_XELATEX) ? xeLaTeXPath : pdfLaTeXPath;
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
        failed = fontColorIsWhite || boundingBoxCouldNotBeComputed ||
                 ![self crop:pdfFilePath2 to:pdfCroppedFilePath canClip:(compositionMode != COMPOSITION_MODE_XELATEX) extraArguments:extraArguments
                     compositionConfiguration:compositionConfiguration workingDirectory:workingDirectory environment:fullEnvironment outPdfData:&pdfData];
        if (failed)//use old method
        {
          failed = NO; //since step 3 is a resort, step 2 is not a real failure, so we reset <failed> to NO
          pdfData = nil;
          NSRect boundingBox = [self computeBoundingBox:pdfFilePath workingDirectory:workingDirectory fullEnvironment:fullEnvironment
                                compositionConfiguration:compositionConfiguration];

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
              "\\pagestyle{empty}\n"\
              "\\usepackage{geometry}\n"\
              "\\usepackage{graphicx}\n"\
              "\\newsavebox{\\latexitbox}\n"\
              "\\newcommand{\\latexitscalefactor}{%f}\n"\
              "\\newlength{\\latexitwidth}\n\\newlength{\\latexitheight}\n\\newlength{\\latexitdepth}\n"\
              "\\setlength{\\topskip}{0pt}\n\\setlength{\\parindent}{0pt}\n\\setlength{\\abovedisplayskip}{0pt}\n"\
              "\\setlength{\\belowdisplayskip}{0pt}\n"\
              "\\normalfont\n"\
              "\\begin{lrbox}{\\latexitbox}\n"\
              "\\includegraphics[viewport = %f %f %f %f]{%@}\n"\
              "\\end{lrbox}\n"\
              "\\settowidth{\\latexitwidth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"\
              "\\settoheight{\\latexitheight}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"\
              "\\settodepth{\\latexitdepth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"\
              "\\newwrite\\foo \\immediate\\openout\\foo=\\jobname.sizes \\immediate\\write\\foo{\\the\\latexitdepth (Depth)}\n"\
              "\\immediate\\write\\foo{\\the\\latexitheight (Height)}\n"\
              "\\addtolength{\\latexitheight}{\\latexitdepth}\n"\
              //"\\addtolength{\\latexitheight}{%f pt}\n" //little correction
              "\\immediate\\write\\foo{\\the\\latexitheight (TotalHeight)} \\immediate\\write\\foo{\\the\\latexitwidth (Width)}\n"\
              "\\closeout\\foo \\geometry{paperwidth=\\latexitwidth,paperheight=\\latexitheight,margin=0pt}\n"\
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
                          [NSNumber numberWithInt:COMPOSITION_MODE_PDFLATEX], CompositionConfigurationCompositionModeKey, nil]
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
        NSDictionary* attributes =
          [NSDictionary dictionaryWithObjectsAndKeys:
              [[NSWorkspace sharedWorkspace] applicationName], PDFDocumentCreatorAttribute, nil];
        [pdfDocument setDocumentAttributes:attributes];
        pdfData = [pdfDocument dataRepresentation];
      }
      @catch(NSException* e){
        DebugLog(0, @"exception : %@", e);
      }
      @finally {
        [pdfDocument release];
      }
    }//end if (!failed && pdfData && !shouldDenyDueTo64Bitsproblem)

    if (!failed && pdfData)
    {
      //POSTPROCESSING
      NSDictionary* script = [additionalProcessingScripts objectForKey:[NSString stringWithFormat:@"%d",SCRIPT_PLACE_POSTPROCESSING]];
      if (script && [[script objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
      {
        [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Post-processing", @"Post-processing")];
        [fullLog appendFormat:@"%@\n", [self descriptionForScript:script]];
        [self executeScript:script setEnvironment:environment1 logString:fullLog workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
          compositionConfiguration:compositionConfiguration];
        if (outFullLog) *outFullLog = fullLog;
      }
    }

    //adds some meta-data to be compatible with Latex Equation Editor
    if (!failed && pdfData)
      pdfData = [self annotatePdfDataInLEEFormat:pdfData preamble:preamble source:body color:color
                                            mode:latexMode magnification:magnification baseline:baseline
                                 backgroundColor:backgroundColor title:nil];
    [pdfData writeToFile:pdfFilePath atomically:NO];//Recreates the document with the new meta-data
  }//end if latex source could be compiled

  //remove additional files
  enumerator = [additionalFilesPathsLinksCreated objectEnumerator];
  NSString* additionalFilePathLinkPath = nil;
  while((additionalFilePathLinkPath = [enumerator nextObject]))
    [fileManager bridge_removeItemAtPath:additionalFilePathLinkPath error:0];

  if (outPdfData) *outPdfData = pdfData;
  
  //returns the cropped/magnified/coloured image if possible; nil if it has failed. 
  return !pdfData ? nil : pdfFilePath;
}
//end latexiseWithPreamble:body:color:mode:magnification:

//computes the tight bounding box of a pdfFile
-(NSRect) computeBoundingBox:(NSString*)filePath workingDirectory:(NSString*)workingDirectory
             fullEnvironment:(NSDictionary*)fullEnvironment compositionConfiguration:(NSDictionary*)compositionConfiguration
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
      [NSArray arrayWithObjects:@"-dNOPAUSE", @"-dSAFER", @"-dNOPLATFONTS", @"-sDEVICE=bbox",@"-dBATCH",@"-q", filePath, nil]]];
    [boundingBoxTask launch];
    [boundingBoxTask waitUntilExit];
    NSData*   boundingBoxData = [boundingBoxTask dataForStdError];
    [boundingBoxTask release];
    NSString* boundingBoxString = [[[NSString alloc] initWithData:boundingBoxData encoding:NSUTF8StringEncoding] autorelease];
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
  [fileManager bridge_removeItemAtPath:dviFile error:0];
  [fileManager bridge_removeItemAtPath:pdfFile error:0];
  
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
     (compositionMode == COMPOSITION_MODE_XELATEX) ? [compositionConfiguration compositionConfigurationProgramPathXeLaTeX]
       : (compositionMode == COMPOSITION_MODE_PDFLATEX) ? [compositionConfiguration compositionConfigurationProgramPathPdfLaTeX]
        : [compositionConfiguration compositionConfigurationProgramPathLaTeX];

  NSArray* defaultArguments =
     (compositionMode == COMPOSITION_MODE_XELATEX) ? [compositionConfiguration compositionConfigurationProgramArgumentsXeLaTeX]
       : (compositionMode == COMPOSITION_MODE_PDFLATEX) ? [compositionConfiguration compositionConfigurationProgramArgumentsPdfLaTeX]
         : [compositionConfiguration compositionConfigurationProgramArgumentsLaTeX];

  SystemTask* systemTask = [[[SystemTask alloc] initWithWorkingDirectory:workingDirectory] autorelease];
  [systemTask setUsingLoginShell:useLoginShell];
  [systemTask setTimeOut:120];
  [systemTask setCurrentDirectoryPath:workingDirectory];
  [systemTask setLaunchPath:executablePath];
  [systemTask setArguments:[defaultArguments arrayByAddingObjectsFromArray:
    [NSArray arrayWithObjects:@"-file-line-error", @"-interaction", @"nonstopmode", texFile, nil]]];
  [systemTask setEnvironment:fullEnvironment];
  [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n%@\n",
                                                        NSLocalizedString(@"processing", @"processing"),
                                                        [executablePath lastPathComponent],
                                                        [systemTask equivalentLaunchCommand]]];
  [systemTask launch];
  BOOL failed = ([systemTask terminationStatus] != 0) && ![fileManager fileExistsAtPath:pdfFile];
  NSData* dataForStdOutput = [systemTask dataForStdOutput];
  NSString* stdOutputErrors = [[[NSString alloc] initWithData:dataForStdOutput encoding:NSUTF8StringEncoding] autorelease];
  [customString appendString:stdOutputErrors ? stdOutputErrors : @""];
  [stdoutString appendString:stdOutputErrors ? stdOutputErrors : @""];
  
  //NSData* dataForStdError  = [systemTask dataForStdError];
  //NSString* stdErrors = [[[NSString alloc] initWithData:dataForStdError encoding:NSUTF8StringEncoding] autorelease];
  //[customString appendString:stdErrors ? stdErrors : @""];
  //[stdoutString appendString:stdErrors ? stdErrors : @""];
  
  if (failed)
    [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n",
                               NSLocalizedString(@"error while processing", @"error while processing"),
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
                                                            NSLocalizedString(@"processing", @"processing"),
                                                            [[dvipdfTask launchPath] lastPathComponent],
                                                            [dvipdfTask commandLine]]];
      [dvipdfTask launch];
      [dvipdfTask waitUntilExit];
      NSData* stdoutData = [dvipdfTask dataForStdOutput];
      NSData* stderrData = [dvipdfTask dataForStdError];
      NSString* tmp = nil;
      tmp = stdoutData ? [[[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] autorelease] : nil;
      if (tmp)
      {
        [customString appendString:tmp];
        [stdoutString appendString:tmp];
      }
      tmp = stderrData ? [[[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] autorelease] : nil;
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
      [dvipdfTask release];
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
//end composeLaTeX:customLog:stdoutLog:stderrLog:compositionMode:pdfLatexPath:xeLatexPath:latexPath:

//returns an array of the errors. Each case will contain an error string
-(NSArray*) filterLatexErrors:(NSString*)fullErrorLog shiftLinesBy:(int)errorLineShift
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
  unsigned int errorLineIndex = 0;
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
  const unsigned int errorLineIndexCount = [errorLines count];
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
        lineComponent = [[NSNumber numberWithInt:[lineComponent intValue]+errorLineShift] stringValue];
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
          
          lineComponent = [[NSNumber numberWithInt:[lineComponent intValue]+errorLineShift] stringValue];
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
        outPdfData:(NSData**)outPdfData
{
  BOOL result = YES;
  //Call pdfCrop
  BOOL useLoginShell = [compositionConfiguration compositionConfigurationUseLoginShell];
  NSString* pdfCropPath  = [[NSBundle bundleForClass:[self class]] pathForResource:@"pdfcrop" ofType:@"pl"];
  NSMutableArray* arguments = [NSMutableArray arrayWithObjects:
    [NSString stringWithFormat:@"\"%@\"", pdfCropPath], (canClip ? @"--clip" : nil), nil];
  if (extraArguments)
    [arguments addObjectsFromArray:extraArguments];
  [arguments addObjectsFromArray:[NSArray arrayWithObjects:inoutPdfFilePath, outputPdfFilePath, nil]];
  SystemTask* pdfCropTask = [[SystemTask alloc] initWithWorkingDirectory:workingDirectory];
  [pdfCropTask setUsingLoginShell:useLoginShell];
  [pdfCropTask setEnvironment:environment];
  [pdfCropTask setLaunchPath:@"perl"];
  [pdfCropTask setArguments:arguments];
  [pdfCropTask setCurrentDirectoryPath:workingDirectory];
  [pdfCropTask launch];
  [pdfCropTask waitUntilExit];
  result = ([pdfCropTask terminationStatus] == 0);
  [pdfCropTask release];
  if (result)
  {
    NSData* croppedData = [NSData dataWithContentsOfFile:outputPdfFilePath options:NSUncachedRead error:nil];
    if (!croppedData)
      result = NO;
    else//if (croppedData)
    {
      if (outPdfData) *outPdfData = croppedData;
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
    switch([[script objectForKey:CompositionConfigurationAdditionalProcessingScriptTypeKey] intValue])
    {
      case SCRIPT_SOURCE_STRING :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"Shell", @"Shell"),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Body", @"Body"),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptContentKey]];
        break;
      case SCRIPT_SOURCE_FILE :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"File", @"File"),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Content", @"Content"),
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
    [fileManager bridge_removeItemAtPath:latexScriptPath error:0];
    [fileManager bridge_removeItemAtPath:logScriptPath   error:0];
    
    NSString* scriptBody = nil;

    NSNumber* scriptType = [script objectForKey:CompositionConfigurationAdditionalProcessingScriptTypeKey];
    script_source_t source = scriptType ? [scriptType intValue] : SCRIPT_SOURCE_STRING;

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
    [NSMutableDictionary dictionaryWithDictionary:[fileManager bridge_attributesOfFileSystemForPath:latexScriptPath error:0]];
    NSNumber* posixPermissions = [fileAttributes objectForKey:NSFilePosixPermissions];
    posixPermissions = [NSNumber numberWithUnsignedLong:[posixPermissions unsignedLongValue] | 0700];//add rwx flag
    [fileAttributes setObject:posixPermissions forKey:NSFilePosixPermissions];
    [fileManager bridge_setAttributes:fileAttributes ofItemAtPath:latexScriptPath error:0];

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

    SystemTask* task = [[[SystemTask alloc] initWithWorkingDirectory:workingDirectory] autorelease];
    [task setUsingLoginShell:useLoginShell];
    [task setCurrentDirectoryPath:workingDirectory];
    [task setEnvironment:environment];
    [task setLaunchPath:scriptShell];
    [task setArguments:[NSArray arrayWithObjects:useLoginShell ? @"" : @"-l", @"-c", latexScriptPath, nil]];
    [task setCurrentDirectoryPath:[latexScriptPath stringByDeletingLastPathComponent]];

    [logString appendFormat:@"----------------- %@ script -----------------\n", NSLocalizedString(@"executing", @"executing")];
    [logString appendFormat:@"%@\n", [task equivalentLaunchCommand]];

    @try {
      [task setTimeOut:30];
      [task launch];
      [task waitUntilExit];
      if ([task hasReachedTimeout])
        [logString appendFormat:@"\n%@\n\n", NSLocalizedString(@"Script too long : timeout reached",
                                                               @"Script too long : timeout reached")];
      else if ([task terminationStatus])
      {
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"Script failed")];
        NSString* outputLog1 = [[[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding] autorelease];
        NSString* outputLog2 = [[[NSString alloc] initWithData:[task dataForStdError]  encoding:encoding] autorelease];
        [logString appendFormat:@"%@\n%@\n----------------------------------------------------\n", outputLog1, outputLog2];
      }
      else
      {
        NSString* outputLog = [[[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding] autorelease];
        [logString appendFormat:@"\n%@\n----------------------------------------------------\n", outputLog];
      }
    }//end try task
    @catch(NSException* e) {
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"Script failed")];
        NSString* outputLog = [[[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding] autorelease];
        [logString appendFormat:@"%@\n----------------------------------------------------\n", outputLog];
    }
  }//end if (source != SCRIPT_SOURCE_NONE)
}
//end executeScript:setEnvironment:logString:workingDirectory:uniqueIdentifier:compositionConfiguration:

//returns a file icon to represent the given PDF data; if not specified (nil), the backcground color will be half-transparent
-(NSImage*) makeIconForData:(NSData*)pdfData backgroundColor:(NSColor*)backgroundColor
{
  NSImage* icon = nil;
  NSImage* image = [[[NSImage alloc] initWithData:pdfData] autorelease];
  NSSize imageSize = [image size];
  icon = [[[NSImage alloc] initWithSize:NSMakeSize(128, 128)] autorelease];
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

//returns data representing data derived from pdfData, but in the format specified (pdf, eps, tiff, png...)
-(NSData*) dataForType:(export_format_t)format pdfData:(NSData*)pdfData
             jpegColor:(NSColor*)color jpegQuality:(CGFloat)quality scaleAsPercent:(CGFloat)scaleAsPercent
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
    
    if (pdfData)
    {
      if (scaleAsPercent != 100)//if scale is not 100%, change image scale
      {
        NSPDFImageRep* pdfImageRep = [[NSPDFImageRep alloc] initWithData:pdfData];
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
        NSData* resizedPdfData = [imageView dataWithPDFInsideRect:[imageView bounds]];
        NSDictionary* equationMetaData = [LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES];
        pdfData =
          [self annotatePdfDataInLEEFormat:resizedPdfData
            preamble:[[equationMetaData objectForKey:@"preamble"] string]
            source:[[equationMetaData objectForKey:@"sourceText"] string]
            color:[equationMetaData objectForKey:@"color"]
            mode:[[equationMetaData objectForKey:@"mode"] intValue]
            magnification:[[equationMetaData objectForKey:@"magnification"] doubleValue]
            baseline:[[equationMetaData objectForKey:@"baseline"] doubleValue]
            backgroundColor:[equationMetaData objectForKey:@"backgroundColor"]
            title:[equationMetaData objectForKey:@"title"]];
            
        #warning 64bits problem
        BOOL shouldDenyDueTo64Bitsproblem = (sizeof(NSInteger) != 4);
        if (pdfData && !shouldDenyDueTo64Bitsproblem)
        {
          //in the meta-data of the PDF we store as much info as we can : preamble, body, size, color, mode, baseline...
          PDFDocument* pdfDocument = nil;
          @try{
            pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
            NSDictionary* attributes =
              [NSDictionary dictionaryWithObjectsAndKeys:
                  [[NSWorkspace sharedWorkspace] applicationName], PDFDocumentCreatorAttribute, nil];
            [pdfDocument setDocumentAttributes:attributes];
            pdfData = [pdfDocument dataRepresentation];
          }
          @catch(NSException* e) {
            DebugLog(0, @"exception : %@", e);
          }
          @finally{
            [pdfDocument release];
          }
        }//end if (pdfData && !shouldDenyDueTo64Bitsproblem)

        [imageView release];
        [pdfImage release];
        [pdfImageRep release];
      }//end if (scaleAsPercent != 100)
      
      BOOL      useLoginShell    = [compositionConfiguration compositionConfigurationUseLoginShell];
      NSString* gsPath           = [compositionConfiguration compositionConfigurationProgramPathGs];
      NSArray*  gsArguments      = [compositionConfiguration compositionConfigurationProgramArgumentsGs];
      NSString* psToPdfPath      = [compositionConfiguration compositionConfigurationProgramPathPsToPdf];
      NSArray*  psToPdfArguments = [compositionConfiguration compositionConfigurationProgramArgumentsPsToPdf];
      NSString* pdf2svgPath      = [[PreferencesController sharedController] exportSvgPdfToSvgPath];
    
      if (format == EXPORT_FORMAT_PDF)
      {
        data = pdfData;
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
          NSString* systemCall =
            [NSString stringWithFormat:
              @"%@ -sDEVICE=epswrite -dNOCACHE -sOutputFile=- -q -dbatch -dNOPAUSE -dSAFER -dNOPLATFONTS %@ -c quit 2>|%@ | %@  -dSubsetFonts=false -dEmbedAllFonts=true -dDEVICEWIDTHPOINTS=100000 -dDEVICEHEIGHTPOINTS=100000 -dPDFSETTINGS=/prepress %@ - %@ 1>>%@ 2>&1",
              gsPath, pdfFilePath, tmpFilePath, psToPdfPath, [psToPdfArguments componentsJoinedByString:@" "], tmpPdfFilePath, tmpFilePath];
          int error = system([systemCall UTF8String]);
          if (error)
          {
            int displayError =
              NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                              [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file with command:\n%@",
                                                                           @"An error occured while trying to create the file with command:\n%@"),
                                                         systemCall],
                              NSLocalizedString(@"OK", @"OK"),
                              NSLocalizedString(@"Display the error message", @"Display the error message"),
                              nil);
            if (displayError == NSAlertAlternateReturn)
            {
              NSString* output = [[[NSString alloc] initWithData:[tmpFileHandle availableData] encoding:NSUTF8StringEncoding] autorelease];
              [[NSAlert alertWithMessageText:NSLocalizedString(@"Error message", @"Error message")
                                               defaultButton:NSLocalizedString(@"OK", @"OK") alternateButton:nil otherButton:nil
                                   informativeTextWithFormat:@"%@ %d:\n%@", NSLocalizedString(@"Error", @"Error"), error, output] runModal];
            }//end if displayError
            unlink([tmpFilePath UTF8String]);
          }//end if (error)
          else//if (!error)
          {
            LatexitEquation* latexitEquation = [LatexitEquation latexitEquationWithPDFData:pdfData useDefaults:YES];
            [self crop:tmpPdfFilePath to:tmpPdfFilePath canClip:YES extraArguments:[NSArray array]
              compositionConfiguration:compositionConfiguration workingDirectory:temporaryDirectory environment:self->globalExtraEnvironment outPdfData:&pdfData];
            data = [NSData dataWithContentsOfFile:tmpPdfFilePath options:NSUncachedRead error:nil];
            data = [[LaTeXProcessor sharedLaTeXProcessor] annotatePdfDataInLEEFormat:data
                                           preamble:[[latexitEquation preamble] string]
                                             source:[[latexitEquation sourceText] string]
                                              color:[latexitEquation color] mode:[latexitEquation mode]
                                      magnification:[latexitEquation pointSize]
                                           baseline:0
                                    backgroundColor:[latexitEquation backgroundColor] title:[latexitEquation title]];
          }//end if (!error)
          [[NSFileManager defaultManager] bridge_removeItemAtPath:tmpFilePath error:0];
        }//if (gsPath && ![gsPath isEqualToString:@""] && psToPdfPath && ![psToPdfPath isEqualToString:@""])
        [[NSFileManager defaultManager] bridge_removeItemAtPath:pdfFilePath error:0];
        [[NSFileManager defaultManager] bridge_removeItemAtPath:tmpPdfFilePath error:0];
      }//end if (format == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      else if (format == EXPORT_FORMAT_EPS)
      {
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
            [NSArray arrayWithObjects:@"-dNOPAUSE", @"-dNOCACHE", @"-dBATCH", @"-dSAFER", @"-dNOPLATFONTS", @"-sDEVICE=epswrite",
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
          [errorString appendString:[[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] autorelease]];

          if ([gsTask terminationStatus] != 0)
          {
            NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                            [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file :\n%@",
                                                                         @"An error occured while trying to create the file :\n%@"),
                                                       errorString],
                            @"OK", nil, nil);
          }
          [gsTask release];
        }
        data = [NSData dataWithContentsOfFile:tmpEpsFilePath options:NSUncachedRead error:nil];
        [[NSFileManager defaultManager] bridge_removeItemAtPath:tmpEpsFilePath error:0];
        [[NSFileManager defaultManager] bridge_removeItemAtPath:pdfFilePath error:0];
        DebugLog(1, @"create EPS data %p (%ld)", data, (unsigned long)[data length]);
      }//end if (format == EXPORT_FORMAT_EPS)
      else if (format == EXPORT_FORMAT_TIFF)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentation];
        [image release];
        NSData* annotationData =
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:@"public.tiff" withData:annotationDataCompressed];
        DebugLog(1, @"create TIFF data %p (%ld)", data, (unsigned long)[data length]);
      }//end if (format == EXPORT_FORMAT_TIFF)
      else if (format == EXPORT_FORMAT_PNG)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:15.0];
        NSBitmapImageRep* imageRep = [NSBitmapImageRep imageRepWithData:data];
        data = [imageRep representationUsingType:NSPNGFileType properties:nil];
        [image release];
        NSData* annotationData =
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:@"public.png" withData:annotationDataCompressed];
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
          NSColor* rgbColor = [color colorUsingColorSpaceName:NSDeviceRGBColorSpace];
          CGContextSetRGBFillColor(cgContext,
            [rgbColor redComponent], [rgbColor greenComponent], [rgbColor blueComponent], [rgbColor alphaComponent]);
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
          (CFMutableDataRef)mutableData, CFSTR("public.jpeg"), 1, 0);
        if (cgImageDestination && cgImage)
        {
          CGImageDestinationAddImage(cgImageDestination, cgImage,
            (CFDictionaryRef)[NSDictionary dictionaryWithObjectsAndKeys:
              [NSNumber numberWithFloat:quality/100], (NSString*)kCGImageDestinationLossyCompressionQuality,
              nil]);
          CGImageDestinationFinalize(cgImageDestination);
          CFRelease(cgImageDestination);
        }//end if (cgImageDestination && cgImage)
        CGImageRelease(cgImage);

        data = mutableData;
        NSData* annotationData =
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:@"public.jpeg" withData:annotationDataCompressed];
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
          [errorString appendString:[[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] autorelease]];

          if ([svgTask terminationStatus] != 0)
          {
            NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                            [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file :\n%@",
                                                                         @"An error occured while trying to create the file :\n%@"),
                                                       errorString],
                            @"OK", nil, nil);
          }//end if ([svgTask terminationStatus] != 0)
          [svgTask release];
        }
        data = [NSData dataWithContentsOfFile:tmpSvgFilePath options:NSUncachedRead error:nil];
        NSData* annotationData =
          [NSKeyedArchiver archivedDataWithRootObject:[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES]];
        NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
        data = [self annotateData:data ofUTI:@"public.svg-image" withData:annotationDataCompressed];
        [[NSFileManager defaultManager] bridge_removeItemAtPath:tmpSvgFilePath error:0];
      }//end if (format == EXPORT_FORMAT_SVG)
      else if (format == EXPORT_FORMAT_MATHML)
      {
        NSDictionary* metaData = [LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES];
        NSAttributedString* sourceText = [metaData objectForKey:@"sourceText"];
        latex_mode_t latexMode = (latex_mode_t)[[metaData objectForKey:@"mode"] intValue];
        NSString* addSymbolLeft  = (latexMode == LATEX_MODE_ALIGN) ? @"$\\begin{eqnarray}\n" ://unfortunately, align is not supported
                                   (latexMode == LATEX_MODE_EQNARRAY) ? @"$\\begin{eqnarray}\n" :
                                   (latexMode == LATEX_MODE_DISPLAY) ? @"$\\displaystyle " :
                                   (latexMode == LATEX_MODE_INLINE) ? @"$" : @"";
        NSString* addSymbolRight = (latexMode == LATEX_MODE_ALIGN) ? @"\n\\end{eqnarray}$" ://unfortunately, align is not supported
                                   (latexMode == LATEX_MODE_EQNARRAY) ? @"\n\\end{eqnarray}$" :
                                   (latexMode == LATEX_MODE_DISPLAY) ? @"$" :
                                   (latexMode == LATEX_MODE_INLINE) ? @"$" : @"";
        NSString* sourceString = [sourceText string];
        NSString* escapedSourceString = [sourceString stringByReplacingOccurrencesOfRegex:@"&(?!amp;)" withString:@"&amp;"];
        NSString* inputString = [NSString stringWithFormat:@"<body><blockquote>%@%@%@</blockquote></body>",
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
          NSString* logStdOut = ok ? nil :
            [[[NSString alloc] initWithData:[laTeXMathMLTask dataForStdOutput] encoding:NSUTF8StringEncoding] autorelease];
          NSString* logStdErr = ok ? nil :
            [[[NSString alloc] initWithData:[laTeXMathMLTask dataForStdError] encoding:NSUTF8StringEncoding] autorelease];
          if (!ok)
          {
            DebugLog(1, @"command = %@", [laTeXMathMLTask commandLine]);
            DebugLog(1, @"terminationStatus = %d", terminationStatus);
            DebugLog(1, @"logStdOut = %@", logStdOut);
            DebugLog(1, @"logStdErr = %@", logStdErr);
          }//end if (!ok)
          [laTeXMathMLTask release];
          data = [NSData dataWithContentsOfFile:outputFile];
          NSData* annotationData = [NSKeyedArchiver archivedDataWithRootObject:metaData];
          NSData* annotationDataCompressed = [Compressor zipcompress:annotationData level:Z_BEST_COMPRESSION];
          data = [self annotateData:data ofUTI:@"public.html" withData:annotationDataCompressed];
          [[NSFileManager defaultManager] bridge_removeItemAtPath:outputFile error:0];
        }//end if (ok)
        [[NSFileManager defaultManager] bridge_removeItemAtPath:inputFile error:0];
      }//end if (format == EXPORT_FORMAT_MATHML)
    }//end if pdfData available
  }//end @synchronized
  return data;
}
//end dataForType:pdfData:jpegColor:jpegQuality:scaleAsPercent:

-(NSData*) annotateData:(NSData*)inputData ofUTI:(NSString*)sourceUTI withData:(NSData*)annotationData
{
  NSData* result = nil;
  if (inputData && annotationData)
  {
    if (!sourceUTI ||//may be guessed
        UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.tiff")) ||
        UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.png")) ||
        UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.jpeg")))
    {
      NSString* annotationDataBase64 = [annotationData encodeBase64];
      NSMutableData* annotatedData = !annotationDataBase64 ? nil : [[NSMutableData alloc] initWithCapacity:[inputData length]];
      CGImageSourceRef imageSource = !annotatedData ? 0 :
        CGImageSourceCreateWithData((CFDataRef)inputData, (CFDictionaryRef)
          [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO], (NSString*)kCGImageSourceShouldCache, nil]);
      CFStringRef detectedUTI = !imageSource ? 0 : CGImageSourceGetType(imageSource);
      if (( sourceUTI && UTTypeConformsTo(detectedUTI, (CFStringRef)sourceUTI)) ||
          (!sourceUTI && (UTTypeConformsTo(detectedUTI, CFSTR("public.tiff")) ||
                          UTTypeConformsTo(detectedUTI, CFSTR("public.png")) || 
                          UTTypeConformsTo(detectedUTI, CFSTR("public.jpeg")))))
      {
        CGImageDestinationRef imageDestination = !imageSource ? 0 :
          CGImageDestinationCreateWithData((CFMutableDataRef)annotatedData,
                                           sourceUTI ? (CFStringRef)sourceUTI : detectedUTI, 1, 0);
        NSDictionary* propertiesImmutable = nil;
        NSMutableDictionary* properties = nil;
        if (imageSource && imageDestination)
        {
          propertiesImmutable = NSMakeCollectable((NSDictionary*)CGImageSourceCopyPropertiesAtIndex(imageSource, 0, 0));
          properties = [[propertiesImmutable deepMutableCopy] autorelease];
          NSMutableDictionary* exifDictionary = [properties objectForKey:(NSString*)kCGImagePropertyExifDictionary];
          if (!exifDictionary)
          {
            exifDictionary = [NSMutableDictionary dictionaryWithCapacity:1];
            [properties setObject:exifDictionary forKey:(NSString*)kCGImagePropertyExifDictionary];
          }//end if (!exifDictionary)
          [exifDictionary setObject:annotationDataBase64 forKey:(NSString*)kCGImagePropertyExifUserComment];
        }//if (imageSource && imageDestination)
        [propertiesImmutable release];
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, (CFDictionaryRef)properties);
        if (imageDestination) CGImageDestinationFinalize(imageDestination);
        if (imageDestination) CFRelease(imageDestination);
      }//end if (UTTypeConformsTo(detectedUTI, sourceUTI))
      if (imageSource)
        CFRelease(imageSource);
      if (annotatedData)
        result = [[annotatedData copy] autorelease];
      [annotatedData release];
    }//end if (tiff, png, jpeg)
    else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.svg-image")))
    {
      NSString* annotationDataBase64 = [annotationData encodeBase64];
      NSMutableString* outputString = !annotationDataBase64 ? nil :
        [[[NSMutableString alloc] initWithData:inputData encoding:NSUTF8StringEncoding] autorelease];
      NSError* error = nil;
      [outputString
         replaceOccurrencesOfRegex:@"<svg(.*?)>(.*)</svg>"
         withString:[NSString stringWithFormat:@"<svg$1><!--latexit:%@-->$2</svg>", annotationDataBase64]
         options:RKLCaseless|RKLDotAll|RKLMultiline range:NSMakeRange(0, [outputString length]) error:&error];
      if (error)
        DebugLog(0, @"error : %@", error);
      result = !outputString ? nil : [outputString dataUsingEncoding:NSUTF8StringEncoding];
    }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.svg-image")))
    else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.html")))
    {
      NSString* annotationDataBase64 = [annotationData encodeBase64];
      NSMutableString* outputString = !annotationDataBase64 ? nil :
        [[[NSMutableString alloc] initWithData:inputData encoding:NSUTF8StringEncoding] autorelease];
      NSError* error = nil;
      [outputString replaceOccurrencesOfRegex:@"<blockquote(.*?)>(.*?)</blockquote>"
         withString:[NSString stringWithFormat:@"<blockquote$1><!--latexit:%@-->$2</blockquote>", annotationDataBase64]
            options:RKLCaseless|RKLDotAll|RKLMultiline range:NSMakeRange(0, [outputString length]) error:&error];
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

@end
