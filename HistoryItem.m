//  HistoryItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//An HistoryItem is a useful structure to hold the info about the generated image
//It will typically contain the latex source code (preamble+body), the color, the mode (\[...\], $...$ or text)
//the date, the point size.

#import "HistoryItem.h"

#import "AppController.h"
#import "NSApplicationExtended.h"
#import "NSColorExtended.h"
#import "PreferencesController.h"

#ifdef PANTHER
#import <LinkBack-panther/LinkBack.h>
#else
#import <LinkBack/LinkBack.h>
#import <Quartz/Quartz.h>
#endif

NSString* HistoryItemDidChangeNotification = @"HistoryItemDidChangeNotification";

@interface HistoryItem (PrivateAPI)
-(void) _reannotatePdfData;
@end

@implementation HistoryItem

+(id) historyItemWithPdfData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                     color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
                     backgroundColor:(NSColor*)backgroundColor
{
  id instance = [[[self class] alloc] initWithPdfData:someData preamble:aPreamble sourceText:aSourceText
                                              color:aColor pointSize:aPointSize date:aDate mode:aMode
                                              backgroundColor:backgroundColor];
  return [instance autorelease];
}

-(id) initWithPdfData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
              color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
              backgroundColor:(NSColor*)aBackgroundColor
{
  self = [super init];
  if (self)
  {
    pdfData    = [someData    copy];
    preamble   = [aPreamble   copy];
    sourceText = [aSourceText copy];
    color      = [aColor      copy];
    pointSize  = aPointSize;
    date       = [aDate       copy];
    mode       = aMode;
    //pdfCachedImage and bitmapCachedImage are lazily initialized in the "image" methods that returns these cached images
    backgroundColor = [aBackgroundColor copy];
  }
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
    [self _reannotatePdfData];
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
    [self _reannotatePdfData];
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:HistoryItemDidChangeNotification object:self];
}

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:@"1.3.2"   forKey:@"version"];//we encode the current LaTeXiT version number
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
  self = [super init];
  if (self)
  {
    NSString* version = [coder decodeObjectForKey:@"version"];
    if (!version || [version compare:@"1.2" options:NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending)
    {
      pdfData     = [[coder decodeObjectForKey:@"pdfData"]    retain];
      NSMutableString* tempPreamble = [NSMutableString stringWithString:[coder decodeObjectForKey:@"preamble"]];
      [tempPreamble replaceOccurrencesOfString:@"\\usepackage[dvips]{color}" withString:@"\\usepackage[pdftex]{color}"
                                       options:0 range:NSMakeRange(0, [tempPreamble length])];
      preamble    = [[NSAttributedString alloc] initWithString:tempPreamble];
      sourceText  = [[NSAttributedString alloc] initWithString:[coder decodeObjectForKey:@"sourceText"]];
      color       = [[coder decodeObjectForKey:@"color"]      retain];
      pointSize   = [[coder decodeObjectForKey:@"pointSize"] doubleValue];
      date        = [[coder decodeObjectForKey:@"date"]       retain];
      mode        = (latex_mode_t) [coder decodeIntForKey:@"mode"];
    }
    else
    {
      pdfData     = [[coder decodeObjectForKey:@"pdfData"]    retain];
      preamble    = [[coder decodeObjectForKey:@"preamble"]   retain];
      sourceText  = [[coder decodeObjectForKey:@"sourceText"] retain];
      color       = [[coder decodeObjectForKey:@"color"]      retain];
      pointSize   = [coder decodeDoubleForKey:@"pointSize"];
      date        = [[coder decodeObjectForKey:@"date"]       retain];
      mode        = (latex_mode_t) [coder decodeIntForKey:@"mode"];
      //we need to reduce the history size and load time, so we can safely not save the cached images, since they are lazily
      //initialized in the "image" methods, using the pdfData
      //pdfCachedImage    = [[coder decodeObjectForKey:@"pdfCachedImage"]    retain];
      //bitmapCachedImage = [[coder decodeObjectForKey:@"bitmapCachedImage"] retain];
      backgroundColor = [[coder decodeObjectForKey:@"backgroundColor"] retain];
    }
  }
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
      pdfCachedImage = [[NSImage alloc] initWithData:pdfData];
      //we need to redefine the cache policy so that zoom of imageView will scale PDF and not cached bitmap
      [pdfCachedImage setCacheMode:NSImageCacheNever];
      [pdfCachedImage setDataRetained:YES];
      [pdfCachedImage recache];
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
      NSImage* pdfImage = [self pdfImage];
      [pdfImage lockFocus];//this lockfocus seems necessary to avoid erratic AppKit deadlock when loading history in the background
      NSData* bitmapData = [pdfImage TIFFRepresentation];//may trigger pdfCachedImage computation, in its own @synchronized{} block
      [pdfImage unlockFocus];
      bitmapCachedImage = [[NSImage alloc] initWithData:bitmapData];
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
-(void) _reannotatePdfData
{
  NSData* newData = [self annotatedPdfData];
  [newData retain];
  [pdfData release];
  pdfData = newData;
}

-(NSData*) annotatedPdfData
{
  NSData* newData = pdfData;

  //first, we retreive the baseline if possible
  double baseline = 0;

  BOOL needsToCheckLEEAnnotations = YES;
  #ifndef PANTHER
  PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
  NSString* creator  = pdfDocument ? [[pdfDocument documentAttributes] objectForKey:PDFDocumentCreatorAttribute]  : nil;
  NSArray*  keywords = pdfDocument ? [[pdfDocument documentAttributes] objectForKey:PDFDocumentKeywordsAttribute] : nil;
  //if the meta-data tells that the creator is LaTeXiT, then use it !
  needsToCheckLEEAnnotations = !(creator && [creator isEqual:[NSApp applicationName]] && keywords && ([keywords count] >= 7));
  if (!needsToCheckLEEAnnotations)
    baseline = [[keywords objectAtIndex:5] doubleValue];
  [pdfDocument release];
  #endif

  if (needsToCheckLEEAnnotations) //either we are on panther, or we failed to find meta-data keywords
  {
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
  }
  
  //then, we rewrite the pdfData
  #ifndef PANTHER
  pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
  NSDictionary* attributes =
    [NSDictionary dictionaryWithObjectsAndKeys:
       [NSArray arrayWithObjects:
          preamble ? [preamble string]: [NSString string],
          sourceText ? [sourceText string]: [NSString string],
          [color rgbaString],
          [NSString stringWithFormat:@"%f", pointSize],
          [NSString stringWithFormat:@"%d", mode],
          [NSString stringWithFormat:@"%f", baseline],
          backgroundColor ? [backgroundColor rgbaString] : [[NSColor whiteColor] rgbaString],
          nil], PDFDocumentKeywordsAttribute,
       [NSApp applicationName], PDFDocumentCreatorAttribute,
       nil];
  [pdfDocument setDocumentAttributes:attributes];
  newData = [pdfDocument dataRepresentation];
  [pdfDocument release];
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
  NSString* dragExportType = [[userDefaults stringForKey:DragExportTypeKey] lowercaseString];
  NSArray*  components     = [dragExportType componentsSeparatedByString:@" "];
  NSString* extension      = [components count] ? [components objectAtIndex:0] : nil;
  NSColor*  jpegColor      = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
  float     quality        = [userDefaults floatForKey:DragExportJpegQualityKey];
  NSData*   data           = lazyDataProvider ? nil :
                             [[AppController appController] dataForType:dragExportType pdfData:pdfData jpegColor:jpegColor jpegQuality:quality];
  //feeds the right pasteboard according to the type (pdf, eps, tiff, jpeg, png...)
  if ([extension isEqualToString:@"pdf"])
  {
    [pboard addTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:lazyDataProvider];
    if (!lazyDataProvider) [pboard setData:data forType:NSPDFPboardType];
  }
  else if ([extension isEqualToString:@"eps"])
  {
    [pboard addTypes:[NSArray arrayWithObject:NSPostScriptPboardType] owner:lazyDataProvider];
    if (!lazyDataProvider) [pboard setData:data forType:NSPostScriptPboardType];
  }
  else if ([extension isEqualToString:@"tiff"] || [extension isEqualToString:@"jpeg"] || [extension isEqualToString:@"png"])
  {
    [pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:lazyDataProvider];
    if (!lazyDataProvider) [pboard setData:data forType:NSTIFFPboardType];
  }
}

@end
