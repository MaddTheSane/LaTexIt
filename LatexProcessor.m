//
//  LaTeXProcessor.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/09/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "LaTeXProcessor.h"

#import "LatexitEquation.h"
#import "NSColorExtended.h"
#import "NSDictionaryCompositionConfiguration.h"
#import "NSDictionaryExtended.h"
#import "NSFileManagerExtended.h"
#import "NSStringExtended.h"
#import "NSTaskExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "SystemTask.h"
#import "Utils.h"

#import <Quartz/Quartz.h>
#import "RegexKitLite.h"

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
        [unixBins addObjectsFromArray:usualBins];

        self->globalEnvironmentPath = [[NSMutableString alloc] initWithString:[unixBins componentsJoinedByString:@":"]];

        //add ~/.MacOSX/environment.plist
        NSString* filePath = [NSString pathWithComponents:[NSArray arrayWithObjects:NSHomeDirectory(), @".MacOSX", @"environment.plist", nil]];
        NSDictionary* propertyList = [NSDictionary dictionaryWithContentsOfFile:filePath];
        if (propertyList)
        {
          NSMutableArray* components = [NSMutableArray arrayWithArray:[self->globalEnvironmentPath componentsSeparatedByString:@":"]];
          [components addObjectsFromArray:[[[propertyList objectForKey:@"PATH"] trim] componentsSeparatedByString:@":"]];
          [self->globalEnvironmentPath setString:[components componentsJoinedByString:@":"]];
        }//end if (propertyList)

        self->globalFullEnvironment  = [[[NSProcessInfo processInfo] environment] mutableCopy];
        self->globalExtraEnvironment = [[NSMutableDictionary alloc] init];
        NSString* pathEnv = [[self->globalFullEnvironment objectForKey:@"PATH"] trim];
        if (pathEnv)
        {
          NSMutableSet* pathsSet = [NSMutableSet setWithCapacity:30];
          [pathsSet addObjectsFromArray:[self->globalEnvironmentPath componentsSeparatedByString:@":"]];
          [pathsSet addObjectsFromArray:[pathEnv componentsSeparatedByString:@":"]];
          [self->globalEnvironmentPath setString:[[pathsSet allObjects] componentsJoinedByString:@":"]];
          [self->globalFullEnvironment setObject:self->globalEnvironmentPath forKey:@"PATH"];
          [self->globalExtraEnvironment setObject:self->globalEnvironmentPath forKey:@"PATH"];
        }//end if (pathEnv)
        
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
        self->managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
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
           ">>\nendobj",
          [replacedPreamble cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
          [escapedPreamble  cStringUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES],
          [replacedSource  cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
          [escapedSource   cStringUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES],
          type, colorAsString, bkColorAsString, (title ? title : @""), magnification, baseline];
          
    NSMutableString* pdfString = [[[NSMutableString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
    
    NSRange r1 = [pdfString rangeOfString:@"\nxref" options:NSBackwardsSearch];
    NSRange r2 = [pdfString lineRangeForRange:[pdfString rangeOfString:@"startxref" options:NSBackwardsSearch]];

    NSString* tail_of_tail = [pdfString substringFromIndex:r2.location];
    NSArray*  tailarray    = [tail_of_tail componentsSeparatedByString:@"\n"];

    int byte_count = 0;
    NSScanner* scanner = [NSScanner scannerWithString:[tailarray objectAtIndex:1]];
    [scanner scanInt:&byte_count];
    byte_count += [annotation length];

    NSRange r3 = NSMakeRange(r1.location, r2.location - r1.location);
    NSString* stuff = [pdfString substringWithRange: r3];

    [annotation appendString:stuff];
    [annotation appendString:[NSString stringWithFormat: @"startxref\n%d\n%%%%EOF", byte_count]];
    
    NSData* dataToAppend = [annotation dataUsingEncoding:NSMacOSRomanStringEncoding/*NSASCIIStringEncoding*/ allowLossyConversion:YES];

    newData = [NSMutableData dataWithData:[data subdataWithRange:NSMakeRange(0, r1.location)]];
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
  NSString* colorString =
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
  [fileManager removeFileAtPath:latexFilePath            handler:nil];
  [fileManager removeFileAtPath:latexAuxFilePath         handler:nil];
  [fileManager removeFileAtPath:latexFilePath2           handler:nil];
  [fileManager removeFileAtPath:latexAuxFilePath2        handler:nil];
  [fileManager removeFileAtPath:pdfFilePath              handler:nil];
  [fileManager removeFileAtPath:dviFilePath              handler:nil];
  [fileManager removeFileAtPath:pdfFilePath2             handler:nil];
  [fileManager removeFileAtPath:pdfCroppedFilePath       handler:nil];
  [fileManager removeFileAtPath:latexBaselineFilePath    handler:nil];
  [fileManager removeFileAtPath:latexAuxBaselineFilePath handler:nil];
  [fileManager removeFileAtPath:pdfBaselineFilePath      handler:nil];
  [fileManager removeFileAtPath:sizesFilePath            handler:nil];
  //trash *.*pk, *.mf, *.tfm, *.mp, *.script
  NSArray* files = [fileManager directoryContentsAtPath:workingDirectory];
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
                        [extension isEqualToString:@"script"];
      if (mustDelete)
        [fileManager removeFileAtPath:file handler:NULL];
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
  NSString* addSymbolLeft  = (latexMode == LATEX_MODE_EQNARRAY) ? @"\\begin{eqnarray*}" :
                             (latexMode == LATEX_MODE_DISPLAY) ? @"$\\displaystyle " :
                             (latexMode == LATEX_MODE_INLINE) ? @"$" : @"";
  NSString* addSymbolRight = (latexMode == LATEX_MODE_EQNARRAY) ? @"\\end{eqnarray*}" :
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
  NSString* colorString = [NSString stringWithFormat:@"\\color[rgb]{%1.3f,%1.3f,%1.3f}", rgba[0], rgba[1], rgba[2]];
  NSString* normalSourceToCompile =
    [NSString stringWithFormat:
      @"%@\n\\pagestyle{empty} "\
       "\\begin{document}"\
       "%@%@%@%@\n"\
       "\\end{document}",
       [colouredPreamble replaceYenSymbol], addSymbolLeft,
       (compositionMode == COMPOSITION_MODE_XELATEX) ? colorString : @"",
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
                                                pdfFilePath2, @"OUTPUTPDFFILE",
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
                         (latexMode != LATEX_MODE_TEXT) && (latexMode != LATEX_MODE_EQNARRAY) &&
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
          [colouredPreamble replaceYenSymbol], //preamble
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
    if (!failed && pdfData)
    {
      //in the meta-data of the PDF we store as much info as we can : preamble, body, size, color, mode, baseline...
      PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
      NSDictionary* attributes =
        [NSDictionary dictionaryWithObjectsAndKeys:
            [[NSWorkspace sharedWorkspace] applicationName], PDFDocumentCreatorAttribute, nil];
      [pdfDocument setDocumentAttributes:attributes];
      pdfData = [pdfDocument dataRepresentation];
      [pdfDocument release];
    }

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
    [fileManager removeFileAtPath:additionalFilePathLinkPath handler:nil];

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
  [fileManager removeFileAtPath:dviFile handler:nil];
  [fileManager removeFileAtPath:pdfFile handler:nil];
  
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
  NSString* errors = [[[NSString alloc] initWithData:dataForStdOutput encoding:NSUTF8StringEncoding] autorelease];
  [customString appendString:errors ? errors : @""];
  [stdoutString appendString:errors ? errors : @""];
  
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
    [fileManager removeFileAtPath:latexScriptPath handler:NULL];
    [fileManager removeFileAtPath:logScriptPath   handler:NULL];
    
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
      [NSMutableDictionary dictionaryWithDictionary:[fileManager fileSystemAttributesAtPath:latexScriptPath]];
    NSNumber* posixPermissions = [fileAttributes objectForKey:NSFilePosixPermissions];
    posixPermissions = [NSNumber numberWithUnsignedLong:[posixPermissions unsignedLongValue] | 0700];//add rwx flag
    [fileAttributes setObject:posixPermissions forKey:NSFilePosixPermissions];
    [fileManager changeFileAttributes:fileAttributes atPath:latexScriptPath];

    NSString* scriptShell = nil;
    switch(source)
    {
      case SCRIPT_SOURCE_STRING: scriptShell = [script objectForKey:CompositionConfigurationAdditionalProcessingScriptShellKey]; break;
      case SCRIPT_SOURCE_FILE: scriptShell = @"/bin/sh"; break;
    }
    
    BOOL useLoginShell = [compositionConfiguration compositionConfigurationUseLoginShell];

    SystemTask* task = [[[SystemTask alloc] initWithWorkingDirectory:workingDirectory] autorelease];
    [task setUsingLoginShell:useLoginShell];
    [task setCurrentDirectoryPath:workingDirectory];
    [task setEnvironment:environment];
    [task setLaunchPath:scriptShell];
    [task setArguments:[NSArray arrayWithObjects:@"-c", latexScriptPath, nil]];
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
{
  NSData* data = nil;
  NSString* temporaryDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
  @synchronized(self) //only one person may ask that service at a time
  {
    //prepare file names
    NSString* filePrefix     = [NSString stringWithFormat:@"latexit-controller"];
    NSString* pdfFile        = [NSString stringWithFormat:@"%@.pdf", filePrefix];
    NSString* pdfFilePath    = [temporaryDirectory stringByAppendingPathComponent:pdfFile];
    NSString* tmpEpsFile     = [NSString stringWithFormat:@"%@-2.eps", filePrefix];
    NSString* tmpEpsFilePath = [temporaryDirectory stringByAppendingPathComponent:tmpEpsFile];
    NSString* tmpPdfFile     = [NSString stringWithFormat:@"%@-2.pdf", filePrefix];
    NSString* tmpPdfFilePath = [temporaryDirectory stringByAppendingPathComponent:tmpPdfFile];
    
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
            NSMakeRect(0, 0, originalSize.width*scaleAsPercent/100,originalSize.height*scaleAsPercent/100)];
        [imageView setImageScaling:NSScaleToFit];
        [imageView setImage:pdfImage];
        pdfData = [imageView dataWithPDFInsideRect:[imageView bounds]];
        [imageView release];
        [pdfImage release];
        [pdfImageRep release];
      }
      
      BOOL      useLoginShell    = [compositionConfiguration compositionConfigurationUseLoginShell];
      NSString* gsPath           = [compositionConfiguration compositionConfigurationProgramPathGs];
      NSArray*  gsArguments      = [compositionConfiguration compositionConfigurationProgramArgumentsGs];
      NSString* psToPdfPath      = [compositionConfiguration compositionConfigurationProgramPathPsToPdf];
      NSArray*  psToPdfArguments = [compositionConfiguration compositionConfigurationProgramArgumentsPsToPdf];
    
      if (format == EXPORT_FORMAT_PDF)
      {
        data = pdfData;
      }
      else if (format == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      {
        [pdfData writeToFile:pdfFilePath atomically:NO];
        if (gsPath && ![gsPath isEqualToString:@""] && psToPdfPath && ![psToPdfPath isEqualToString:@""])
        {
          NSString* tmpFilePath = nil;
          NSFileHandle* tmpFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"export.XXXXXXXXX" extension:@"log" outFilePath:&tmpFilePath
                                                                                workingDirectory:temporaryDirectory];
          if (!tmpFilePath)
            tmpFilePath = @"/dev/null";
          NSString* systemCall =
            [NSString stringWithFormat:
              @"%@ -sDEVICE=pswrite -dNOCACHE -sOutputFile=- -q -dbatch -dNOPAUSE -dSAFER -dNOPLATFONTS %@ -c quit 2>|%@ | %@ %@ - %@ 1>>%@ 2>&1",
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
          }//end if error
          else
          {
            LatexitEquation* latexitEquation = [LatexitEquation latexitEquationWithPDFData:pdfData useDefaults:YES];
            data = [NSData dataWithContentsOfFile:tmpPdfFilePath options:NSUncachedRead error:nil];
            data = [[LaTeXProcessor sharedLaTeXProcessor] annotatePdfDataInLEEFormat:data preamble:[[latexitEquation preamble] string]
                                             source:[[latexitEquation sourceText] string]
                                              color:[latexitEquation color] mode:[latexitEquation mode]
                                      magnification:[latexitEquation pointSize]
                                           baseline:0
                                    backgroundColor:[latexitEquation backgroundColor] title:[latexitEquation title]];
          }
        }
      }
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
      }
      else if (format == EXPORT_FORMAT_TIFF)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentation];
        [image release];
      }
      else if (format == EXPORT_FORMAT_PNG)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:15.0];
        NSBitmapImageRep* imageRep = [NSBitmapImageRep imageRepWithData:data];
        data = [imageRep representationUsingType:NSPNGFileType properties:nil];
        [image release];
      }
      else if (format == EXPORT_FORMAT_JPEG)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        NSSize size = [image size];
        NSImage* opaqueImage = [[NSImage alloc] initWithSize:size];
        NSRect rect = NSMakeRect(0, 0, size.width, size.height);
        @try{
        [opaqueImage lockFocus];
          [color set];
          NSRectFill(rect);
          [image drawInRect:rect fromRect:rect operation:NSCompositeSourceOver fraction:1.0];
        [opaqueImage unlockFocus];
        }
        @catch(NSException* e)//may occur if lockFocus fails
        {
        }
        data = [opaqueImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:15.0];
        [opaqueImage release];
        NSBitmapImageRep *opaqueImageRep = [NSBitmapImageRep imageRepWithData:data];
        NSDictionary* properties =
          [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:quality/100], NSImageCompressionFactor, nil];
        data = [opaqueImageRep representationUsingType:NSJPEGFileType properties:properties];
        [image release];
      }
    }//end if pdfData available
  }//end @synchronized
  return data;
}
//end dataForType:pdfData:jpegColor:jpegQuality:scaleAsPercent:

@end