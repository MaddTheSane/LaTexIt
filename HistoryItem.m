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
#endif

@implementation HistoryItem

+(id) historyItemWithPdfData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                     color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode;
{
  id instance = [[[self class] alloc] initWithPdfData:someData preamble:aPreamble sourceText:aSourceText
                                              color:aColor pointSize:aPointSize date:aDate mode:aMode];
  return [instance autorelease];
}

-(id) initWithPdfData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
              color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode;
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
  [super dealloc];
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

-(void) setPreamble:(NSAttributedString*)text
{
  [text retain];
  [preamble release];
  preamble = text;
}

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:@"1.3.1"   forKey:@"version"];//we encode the current LaTeXiT version number
  [coder encodeObject:pdfData    forKey:@"pdfData"];
  [coder encodeObject:preamble   forKey:@"preamble"];
  [coder encodeObject:sourceText forKey:@"sourceText"];
  [coder encodeObject:color      forKey:@"color"];
  [coder encodeDouble:pointSize  forKey:@"pointSize"];
  [coder encodeObject:date       forKey:@"date"];
  [coder encodeInt:mode          forKey:@"mode"];
  //we need to reduce the history size and load time, so we can safely not save the cached images, since they are lazily
  //initialized in the "image" methods, using the pdfData
  //[coder encodeObject:pdfCachedImage    forKey:@"pdfCachedImage"];
  //[coder encodeObject:bitmapCachedImage forKey:@"bitmapCachedImage"];
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
  if (!pdfCachedImage)
  {
    @synchronized(self)
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
  if (!bitmapCachedImage)
  {
    NSData* bitmapData = [[self pdfImage] TIFFRepresentation];//may trigger pdfCachedImage computation, in its own @synchronized{} block
    @synchronized(self)
    {
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
