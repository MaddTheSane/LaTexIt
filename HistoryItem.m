//  HistoryItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//An HistoryItem is a useful structure to hold the info about the generated image
//It will typically contain the latex source code (preamble+body), the color, the mode (EQNARRAY, \[...\], $...$ or text)
//the date, the point size.

#import "HistoryItem.h"

#import "AppController.h"
#import "NSApplicationExtended.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#ifdef PANTHER
#import <LinkBack-panther/LinkBack.h>
#else
#import <LinkBack/LinkBack.h>
#import <Quartz/Quartz.h>
#endif

NSString* HistoryItemDidChangeNotification = @"HistoryItemDidChangeNotification";

@interface HistoryItem (PrivateAPI)
-(void) _reannotatePDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords;
@end

@implementation HistoryItem

static NSLock* strangeLock = nil;

+(void) initialize
{
  if (!strangeLock)
    strangeLock = [[NSLock alloc] init];
}

+(id) historyItemWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                     color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
                     backgroundColor:(NSColor*)backgroundColor
{
  id instance = [[[self class] alloc] initWithPDFData:someData preamble:aPreamble sourceText:aSourceText
                                              color:aColor pointSize:aPointSize date:aDate mode:aMode
                                              backgroundColor:backgroundColor];
  return [instance autorelease];
}

+(id) historyItemWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
{
  return [[[[self class] alloc] initWithPDFData:someData useDefaults:useDefaults] autorelease];
}

-(id) initWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
              color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
              backgroundColor:(NSColor*)aBackgroundColor
{
  if (![super init])
    return nil;
  pdfData    = [someData    copy];
  preamble   = [aPreamble   copy];
  sourceText = [aSourceText copy];
  color      = [aColor      copy];
  pointSize  = aPointSize;
  date       = [aDate       copy];
  mode       = aMode;
  //pdfCachedImage and bitmapCachedImage are lazily initialized in the "image" methods that returns these cached images
  backgroundColor = [aBackgroundColor copy];
  return self;
}

-(id) initWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
{
  if (![super init])
    return nil;

  pdfData = [someData retain];
  NSString* dataAsString = [[[NSString alloc] initWithData:someData encoding:NSMacOSRomanStringEncoding/*NSASCIIStringEncoding*/] autorelease];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSArray*  testArray    = nil;

  NSFont* defaultFont = [NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]];
  NSData* defaultPreambleData = [userDefaults objectForKey:DefaultPreambleAttributedKey];
  NSDictionary* defaultAttributes = [NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName];
  NSAttributedString* defaultPreambleAttributedString =
    [[[NSAttributedString alloc] initWithRTF:defaultPreambleData documentAttributes:NULL] autorelease];
  NSMutableString* preambleString = nil;
  testArray = [dataAsString componentsSeparatedByString:@"/Preamble (ESannop"];
  if (testArray && ([testArray count] >= 2))
  {
    preambleString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
    NSRange range = [preambleString rangeOfString:@"ESannopend"];
    range.length = (range.location != NSNotFound) ? [preambleString length]-range.location : 0;
    [preambleString deleteCharactersInRange:range];
    [preambleString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, [preambleString length])];
    [preambleString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, [preambleString length])];
    [preambleString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, [preambleString length])];
    [preambleString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, [preambleString length])];
  }
  preamble = preambleString ? [[NSAttributedString alloc] initWithString:preambleString attributes:defaultAttributes]
                            : (useDefaults ? [defaultPreambleAttributedString retain]
                                           : [[NSAttributedString alloc] initWithString:@"" attributes:defaultAttributes]);

  NSMutableString* sourceString = [NSMutableString string];
  testArray = [dataAsString componentsSeparatedByString:@"/Subject (ESannot"];
  if (testArray && ([testArray count] >= 2))
  {
    [sourceString appendString:[testArray objectAtIndex:1]];
    NSRange range = [sourceString rangeOfString:@"ESannotend"];
    range.length = (range.location != NSNotFound) ? [sourceString length]-range.location : 0;
    [sourceString deleteCharactersInRange:range];
    [sourceString replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, [sourceString length])];
    [sourceString replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, [sourceString length])];
    [sourceString replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, [sourceString length])];
    [sourceString replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, [sourceString length])];
  }
  sourceText = [[NSAttributedString alloc] initWithString:sourceString attributes:defaultAttributes];

  NSMutableString* pointSizeAsString = nil;
  testArray = [dataAsString componentsSeparatedByString:@"/Magnification (EEmag"];
  if (testArray && ([testArray count] >= 2))
  {
    pointSizeAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
    NSRange range = [pointSizeAsString rangeOfString:@"EEmagend"];
    range.length  = (range.location != NSNotFound) ? [pointSizeAsString length]-range.location : 0;
    [pointSizeAsString deleteCharactersInRange:range];
  }
  pointSize = pointSizeAsString ? [pointSizeAsString doubleValue]
                                : (useDefaults ? [[userDefaults objectForKey:DefaultPointSizeKey] doubleValue] : 0);

  NSMutableString* modeAsString = nil;
  testArray = [dataAsString componentsSeparatedByString:@"/Type (EEtype"];
  if (testArray && ([testArray count] >= 2))
  {
    modeAsString  = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
    NSRange range = [modeAsString rangeOfString:@"EEtypeend"];
    range.length = (range.location != NSNotFound) ? [modeAsString length]-range.location : 0;
    [modeAsString deleteCharactersInRange:range];
  }
  mode = modeAsString ? (latex_mode_t) [modeAsString intValue]
                      : (latex_mode_t) (useDefaults ? [userDefaults integerForKey:DefaultModeKey] : 0);
  mode = validateLatexMode(mode); //Added starting from version 1.7.0

  NSColor* defaultColor = [NSColor colorWithData:[userDefaults objectForKey:DefaultColorKey]];
  NSMutableString* colorAsString = nil;[NSMutableString stringWithString:[defaultColor rgbaString]];
  testArray = [dataAsString componentsSeparatedByString:@"/Color (EEcol"];
  if (testArray && ([testArray count] >= 2))
  {
    colorAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
    NSRange range = [colorAsString rangeOfString:@"EEcolend"];
    range.length = (range.location != NSNotFound) ? [colorAsString length]-range.location : 0;
    [colorAsString deleteCharactersInRange:range];
  }
  color = colorAsString ? [[NSColor colorWithRgbaString:colorAsString] retain] : nil;
  if (!color)
    color = (useDefaults ? [defaultColor retain] : [[NSColor blackColor] retain]);

  NSColor* defaultBkColor = [NSColor whiteColor];
  NSMutableString* bkColorAsString = nil;
  testArray = [dataAsString componentsSeparatedByString:@"/BKColor (EEbkc"];
  if (testArray && ([testArray count] >= 2))
  {
    bkColorAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
    NSRange range = [bkColorAsString rangeOfString:@"EEbkcend"];
    range.length = (range.location != NSNotFound) ? [bkColorAsString length]-range.location : 0;
    [bkColorAsString deleteCharactersInRange:range];
  }
  backgroundColor = bkColorAsString ? [[NSColor colorWithRgbaString:bkColorAsString] retain] : nil;
  if (!backgroundColor)
    backgroundColor = (useDefaults ? [defaultBkColor retain] : [[NSColor whiteColor] retain]);
  return self;
}

-(void) dealloc
{
  [pdfData           release];
  [preamble          release];
  [sourceText        release];
  [color             release];
  [date              release];
  [pdfCachedImage    release];
  [bitmapCachedImage release];
  [backgroundColor   release];  
  [super dealloc];
}

-(id) copyWithZone:(NSZone*) zone
{
  HistoryItem* newInstance = (HistoryItem*) [super copy];
  if (newInstance)
  {
    newInstance->pdfData = [pdfData copy];
    newInstance->preamble = [preamble mutableCopy];
    newInstance->sourceText = [preamble mutableCopy];
    newInstance->color = [color copy];
    newInstance->pointSize = pointSize;
    newInstance->date = [date copy];
    newInstance->mode = mode;
    newInstance->pdfCachedImage = [pdfCachedImage copy];
    newInstance->bitmapCachedImage = [bitmapCachedImage copy];
    newInstance->backgroundColor = [backgroundColor copy];
  }
  return newInstance;
}

-(NSData*) pdfData
{
  return pdfData;
}

-(NSAttributedString*) preamble
{
  return preamble;
}

-(NSAttributedString*) sourceText
{
  return sourceText;
}

-(double) pointSize
{
  return pointSize;
}

-(NSColor*) color
{
  return color;
}

-(NSDate*) date
{
  return date;
}

-(latex_mode_t) mode
{
  return mode;
}

-(NSColor*) backgroundColor
{
  return backgroundColor;
}

-(void) setPreamble:(NSAttributedString*)text
{
  @synchronized(self)
  {
    [text retain];
    [preamble release];
    preamble = text;
    [self _reannotatePDFDataUsingPDFKeywords:YES];
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:HistoryItemDidChangeNotification object:self];
}

-(void) setBackgroundColor:(NSColor*)aColor
{
  @synchronized(self)
  {
    [backgroundColor autorelease];
    //we remove the background color if it is set to white. Useful to display in a table view alternating white/blue rows
    NSColor* greyLevelColor = [aColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace];
    //we retain aColor twice...
    backgroundColor = ([greyLevelColor whiteComponent] == 1.0f) ? nil : [aColor retain];
    [self _reannotatePDFDataUsingPDFKeywords:YES];
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:HistoryItemDidChangeNotification object:self];
}

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:@"1.9.3"   forKey:@"version"];//we encode the current LaTeXiT version number
  [coder encodeObject:pdfData    forKey:@"pdfData"];
  [coder encodeObject:preamble   forKey:@"preamble"];
  [coder encodeObject:sourceText forKey:@"sourceText"];
  [coder encodeObject:color      forKey:@"color"];
  [coder encodeDouble:pointSize  forKey:@"pointSize"];
  [coder encodeObject:date       forKey:@"date"];
  [coder encodeInt:mode          forKey:@"mode"];
  [coder encodeDouble:mode       forKey:@"baseline"];
  //we need to reduce the history size and load time, so we can safely not save the cached images, since they are lazily
  //initialized in the "image" methods, using the pdfData
  //[coder encodeObject:pdfCachedImage    forKey:@"pdfCachedImage"];
  //[coder encodeObject:bitmapCachedImage forKey:@"bitmapCachedImage"];
  [coder encodeObject:backgroundColor forKey:@"backgroundColor"];
}

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super init])
    return nil;
  NSString* version = [coder decodeObjectForKey:@"version"];
  if (!version || [version compare:@"1.2" options:NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending)
  {
    pdfData     = [[coder decodeObjectForKey:@"pdfData"]    retain];
    NSMutableString* tempPreamble = [NSMutableString stringWithString:[coder decodeObjectForKey:@"preamble"]];
    [tempPreamble replaceOccurrencesOfString:@"\\usepackage[dvips]{color}" withString:@"\\usepackage{color}"
                                     options:0 range:NSMakeRange(0, [tempPreamble length])];
    preamble    = [[NSAttributedString alloc] initWithString:tempPreamble];
    sourceText  = [[NSAttributedString alloc] initWithString:[coder decodeObjectForKey:@"sourceText"]];
    color       = [[coder decodeObjectForKey:@"color"]      retain];
    pointSize   = [[coder decodeObjectForKey:@"pointSize"] doubleValue];
    date        = [[coder decodeObjectForKey:@"date"]       retain];
    mode        = validateLatexMode((latex_mode_t) [coder decodeIntForKey:@"mode"]);
  }
  else
  {
    pdfData     = [[coder decodeObjectForKey:@"pdfData"]    retain];
    preamble    = [[coder decodeObjectForKey:@"preamble"]   retain];
    sourceText  = [[coder decodeObjectForKey:@"sourceText"] retain];
    color       = [[coder decodeObjectForKey:@"color"]      retain];
    pointSize   = [coder decodeDoubleForKey:@"pointSize"];
    date        = [[coder decodeObjectForKey:@"date"]       retain];
    mode        = validateLatexMode((latex_mode_t) [coder decodeIntForKey:@"mode"]);
    //we need to reduce the history size and load time, so we can safely not save the cached images, since they are lazily
    //initialized in the "image" methods, using the pdfData
    //pdfCachedImage    = [[coder decodeObjectForKey:@"pdfCachedImage"]    retain];
    //bitmapCachedImage = [[coder decodeObjectForKey:@"bitmapCachedImage"] retain];
    backgroundColor = [[coder decodeObjectForKey:@"backgroundColor"] retain];
  }
  //old versions of LaTeXiT would use \usepackage[pdftex]{color} in the preamble. [pdftex] is useless, in fact
  NSRange rangeOfColorPackage = [[preamble string] rangeOfString:@"\\usepackage[pdftex]{color}"];
  if (rangeOfColorPackage.location != NSNotFound)
  {
    NSMutableAttributedString* newPreamble = [[NSMutableAttributedString alloc] initWithAttributedString:preamble];
    [newPreamble replaceCharactersInRange:rangeOfColorPackage withString:@"\\usepackage{color}"];
    [preamble release];
    preamble = newPreamble;
  }
  
  //for versions < 1.5.4, we must reannotate the pdfData to retreive the accentuated characters
  if (!version || [version compare:@"1.5.4" options:NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending)
    [self _reannotatePDFDataUsingPDFKeywords:NO];
  return self;
}

//triggered for tableView display : will return [self bitmapImage] get faster display than with [self pdfImage]
-(NSImage*) image
{
  return [self bitmapImage];
}

-(NSImage*) pdfImage
{
  @synchronized(self)
  {
    if (!pdfCachedImage)
    {
      NSPDFImageRep* pdfImageRep = [[NSPDFImageRep alloc] initWithData:pdfData];
      pdfCachedImage = [[NSImage alloc] initWithSize:[pdfImageRep size]];
      [pdfCachedImage setCacheMode:NSImageCacheNever];
      [pdfCachedImage setDataRetained:YES];
      [pdfCachedImage setScalesWhenResized:YES];
      [pdfCachedImage addRepresentation:pdfImageRep];
      [pdfImageRep release];
      //[pdfCachedImage recache];
      

      //we need to redefine the cache policy so that zoom of imageView will scale PDF and not cached bitmap
      /*pdfCachedImage = [[NSImage alloc] initWithData:pdfData];
      [pdfCachedImage setCacheMode:NSImageCacheNever];
      [pdfCachedImage setDataRetained:YES];
      [pdfCachedImage recache];*/
    }
  }
  return pdfCachedImage;
}

-(NSImage*) bitmapImage
{
  @synchronized(self)
  {
    if (!bitmapCachedImage)
    {
      NSImage* pdfImage = [self pdfImage];//may trigger pdfCachedImage computation, in its own @synchronized{} block
      //we will compute a bitmap representation. To avoid that it is heavier than the pdf one, we will limit its size
      NSSize realSize = pdfImage ? [pdfImage size] : NSZeroSize;
      //we limit the max size to 256, and do nothing if it is already smaller
      float factor = MIN(1.0f, 256.0f/MAX(1.0f, MAX(realSize.width, realSize.height)));
      NSSize newSize = NSMakeSize(factor*realSize.width, factor*realSize.height);
      //temporarily change size
      [strangeLock lock];//this lock seems necessary to avoid erratic AppKit deadlock when loading history in the background
      [pdfImage setSize:newSize];
      @try{
        [pdfImage lockFocus];
        NSData* bitmapData = nil;
        @try{
          bitmapData = [pdfImage TIFFRepresentation];
        }
        @catch(NSException* e){
        }
        bitmapCachedImage = bitmapData ? [[NSImage alloc] initWithData:bitmapData] : [[NSImage alloc] initWithSize:NSZeroSize];
        [pdfImage unlockFocus];
      }
      @catch(NSException* e) //may occur if lockFocus fails
      {
        [bitmapCachedImage release];
        bitmapCachedImage = [[NSImage alloc] initWithSize:NSZeroSize];
      }
      //restore size
      [pdfImage setSize:realSize];
      [strangeLock unlock];
    }
  }
  return bitmapCachedImage;
}

//latex source code (preamble+body) typed by the user. This WON'T add magnification, auto-bounding, coloring.
//It is a summary of what the user did effectively type. We just add \begin{document} and \end{document}
-(NSString*) string
{
  return [NSString stringWithFormat:@"%@\n\\begin{document}\n%@\n\\end{document}", [preamble string], [sourceText string]];
}

//useful to resynchronize the pdfData with the actual parameters (background color...)
//its use if VERY rare, so that it is not automatic for the sake of efficiency
-(void) _reannotatePDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords
{
  NSData* newData = [self annotatedPDFDataUsingPDFKeywords:usingPDFKeywords];
  [newData retain];
  [pdfData release];
  pdfData = newData;
}

-(NSData*) annotatedPDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords
{
  NSData* newData = pdfData;

  //first, we retreive the baseline if possible
  double baseline = 0;

  NSString* dataAsString = [[[NSString alloc] initWithData:pdfData encoding:NSASCIIStringEncoding] autorelease];
  NSArray* testArray = nil;
  NSMutableString* baselineAsString = @"0";
  testArray = [dataAsString componentsSeparatedByString:@"/Type (EEbas"];
  if (testArray && ([testArray count] >= 2))
  {
    [baselineAsString setString:[testArray objectAtIndex:1]];
    NSRange range = [baselineAsString rangeOfString:@"EEbasend"];
    range.length = (range.location != NSNotFound) ? [baselineAsString length]-range.location : 0;
    [baselineAsString deleteCharactersInRange:range];
  }
  baseline = [baselineAsString doubleValue];

  //then, we rewrite the pdfData
  #ifndef PANTHER
  if (usingPDFKeywords)
  {
    PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
    NSDictionary* attributes =
      [NSDictionary dictionaryWithObjectsAndKeys:
         [NSApp applicationName], PDFDocumentCreatorAttribute,
         nil];
    [pdfDocument setDocumentAttributes:attributes];
    newData = [pdfDocument dataRepresentation];
    [pdfDocument release];
  }
  #endif

  //annotate in LEE format
  newData = [[AppController appController]
                annotatePdfDataInLEEFormat:newData
                                  preamble:(preamble ? [preamble string] : @"") source:(sourceText ? [sourceText string] : @"")
                                     color:color mode:mode magnification:pointSize baseline:baseline backgroundColor:backgroundColor];
  return newData;
}

//to feed a pasteboard. It needs a document, because there may be some temporary files needed for certain kind of data
//the lazyDataProvider, if not nil, is the one who will call [pasteboard:provideDataForType] *as needed* (to save time)
-(void) writeToPasteboard:(NSPasteboard *)pboard forDocument:(MyDocument*)document isLinkBackRefresh:(BOOL)isLinkBackRefresh
         lazyDataProvider:(id)lazyDataProvider
{
  //LinkBack pasteboard
  NSArray* historyItemArray = [NSArray arrayWithObject:self];
  NSData*  historyItemData  = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
  NSDictionary* linkBackPlist =
    isLinkBackRefresh ? [NSDictionary linkBackDataWithServerName:[NSApp applicationName] appData:historyItemData
                                      actionName:LinkBackRefreshActionName suggestedRefreshRate:0]
                      : [NSDictionary linkBackDataWithServerName:[NSApp applicationName] appData:historyItemData]; 
  
  if (isLinkBackRefresh)
    [pboard declareTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:self];
  else
    [pboard addTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:self];
  [pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];

  [pboard addTypes:[NSArray arrayWithObject:NSFileContentsPboardType] owner:self];
  [pboard setData:pdfData forType:NSFileContentsPboardType];

  //Stores the data in the pasteboard corresponding to what the user asked for (pdf, jpeg, tiff...)
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  export_format_t exportFormat = [userDefaults integerForKey:DragExportTypeKey];
  NSColor*  jpegColor      = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
  float     quality        = [userDefaults floatForKey:DragExportJpegQualityKey];
  NSData*   data           = lazyDataProvider ? nil :
                             [[AppController appController] dataForType:exportFormat pdfData:pdfData jpegColor:jpegColor jpegQuality:quality
                                                         scaleAsPercent:[userDefaults floatForKey:DragExportScaleAsPercentKey]];
  //feeds the right pasteboard according to the type (pdf, eps, tiff, jpeg, png...)
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
      [pboard addTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSPDFPboardType];
      break;
    case EXPORT_FORMAT_EPS:
      [pboard addTypes:[NSArray arrayWithObject:NSPostScriptPboardType] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSPostScriptPboardType];
      break;
    case EXPORT_FORMAT_TIFF:
    case EXPORT_FORMAT_PNG:
    case EXPORT_FORMAT_JPEG:
      [pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSTIFFPboardType];
      break;
  }//end switch
}

@end
