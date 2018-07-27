//
//  LatexitEquation.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/10/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import "LatexitEquation.h"

#import "AppController.h"
#import "LaTeXiTPreferencesKeys.h"
#import "LatexProcessor.h"
#import "NSApplicationExtended.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>

NSString* LatexitEquationDidChangeNotification = @"LatexitEquationDidChangeNotification";

@interface LatexitEquation (PrivateAPI)
-(void) _reannotatePDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords;
-(void) beginUpdate;
-(void) endUpdate;
-(BOOL) isUpdating;
@end

@implementation LatexitEquation

+(id) latexitEquationWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                           color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
                 backgroundColor:(NSColor*)backgroundColor
            managedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
  id instance = [[[self class] alloc] initWithPDFData:someData preamble:aPreamble sourceText:aSourceText
                                              color:aColor pointSize:aPointSize date:aDate mode:aMode
                                              backgroundColor:backgroundColor managedObjectContext:managedObjectContext];
  return [instance autorelease];
}
//end historyItemWithPDFData:preamble:sourceText:color:pointSize:date:mode:backgroundColor:

+(id) latexitEquationWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
            managedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
  return [[[[self class] alloc] initWithPDFData:someData useDefaults:useDefaults managedObjectContext:managedObjectContext] autorelease];
}
//end historyItemWithPDFData:useDefaults:

-(id) initWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
              color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
              backgroundColor:(NSColor*)aBackgroundColor
         managedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
  NSEntityDescription* entity = [NSEntityDescription entityForName:[self className] inManagedObjectContext:managedObjectContext];
  if (!((self = [super initWithEntity:entity insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  [self beginUpdate];
  [self setPdfData:someData];
  [self setPreamble:aPreamble];
  [self setSourceText:aSourceText];
  [self setColor:aColor];
  [self setPointSize:aPointSize];
  [self setDate:aDate ? [aDate copy] : [NSDate date]];
  [self setMode:aMode];
  [self setTitle:nil];
    
  if (!aBackgroundColor && [[NSUserDefaults standardUserDefaults] boolForKey:DefaultAutomaticHighContrastedPreviewBackgroundKey])
    aBackgroundColor = ([aColor grayLevel] > .5) ? [NSColor blackColor] : nil;
  [self setBackgroundColor:aBackgroundColor];
  [self endUpdate];
  return self;
}
//end initWithPDFData:preamble:sourceText:color:pointSize:date:mode:backgroundColor:

-(id) initWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults managedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
  NSEntityDescription* entity = [NSEntityDescription entityForName:[self className] inManagedObjectContext:managedObjectContext];
  if (!((self = [super initWithEntity:entity insertIntoManagedObjectContext:managedObjectContext])))
    return nil;

  [self setPdfData:someData];
  NSString* dataAsString = [[[NSString alloc] initWithData:someData encoding:NSMacOSRomanStringEncoding] autorelease];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSArray*  testArray    = nil;
  
  BOOL isLaTeXiTPDF = NO;

  NSFont* defaultFont = [NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]];
  NSDictionary* defaultAttributes = [NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName];
  NSAttributedString* defaultPreambleAttributedString = [[PreferencesController sharedController] preambleForLatexisation];
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
    [preamble autorelease];
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
    [sourceText autorelease];
    [sourceString setString:@""];
    [sourceString appendString:[testArray objectAtIndex:1]];
    NSRange range = [sourceString rangeOfString:@"ESannoesend"];
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
  [self setPointSize:pointSizeAsString ? [pointSizeAsString doubleValue]
                                       : (useDefaults ? [[userDefaults objectForKey:DefaultPointSizeKey] doubleValue] : 0)];

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
                      : (latex_mode_t) (useDefaults ? [userDefaults integerForKey:DefaultModeKey] : 0);
  mode = validateLatexMode(mode); //Added starting from version 1.7.0
  [self setMode:mode];

  NSColor* defaultColor = [NSColor colorWithData:[userDefaults objectForKey:DefaultColorKey]];
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
  
  if (!isLaTeXiTPDF)
    [self autorelease];
  return isLaTeXiTPDF ? self : nil;
}
//end initWithPDFData:useDefaults:

-(void) beginUpdate
{
  ++updateLevel;
}
//end beginUpdate

-(void) endUpdate
{
  --updateLevel;
  if (![self isUpdating] && annotateDataDirtyState)
    [self _reannotatePDFDataUsingPDFKeywords:YES];
}
//end endUpdate

-(BOOL) isUpdating
{
  return (updateLevel > 0);
}
//end isUpdating

-(NSData*) pdfData
{
  NSData* result = nil;
  [self willAccessValueForKey:@"pdfData"]; 
  result = [self primitiveValueForKey:@"pdfData"];
  [self didAccessValueForKey:@"pdfData"];
  return result;
} 
//end pdfData

-(void) setPdfData:(NSData*)value
{
  [self willChangeValueForKey:@"pdfData"];
  [self setPrimitiveValue:value forKey:@"pdfData"];
  [self didChangeValueForKey:@"pdfData"];
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
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self didAccessValueForKey:@"preambleAsData"];
    [self willChangeValueForKey:@"preamble"];
    [self setPrimitiveValue:result forKey:@"preamble"];
    [self didChangeValueForKey:@"preamble"];
  }
  return result;
} 
//end preamble

-(void) setPreamble:(NSAttributedString*)value
{
  [self willChangeValueForKey:@"preamble"];
  [self setPrimitiveValue:value forKey:@"preamble"];
  [self didChangeValueForKey:@"preamble"];
  [self willChangeValueForKey:@"preambleAsData"];
  [self setPrimitiveValue:[NSKeyedArchiver archivedDataWithRootObject:value] forKey:@"preambleAsData"];
  [self didChangeValueForKey:@"preambleAsData"];
  [self _reannotatePDFDataUsingPDFKeywords:YES];
  [[NSNotificationCenter defaultCenter] postNotificationName:LatexitEquationDidChangeNotification object:self];
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
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self didAccessValueForKey:@"sourceTextAsData"]; 
    [self willChangeValueForKey:@"sourceText"];
    [self setPrimitiveValue:result forKey:@"sourceText"];
    [self didChangeValueForKey:@"sourceText"];
  }
  return result;
} 
//end sourceText

-(void) setSourceText:(NSAttributedString*)value
{
  [self willChangeValueForKey:@"sourceText"];
  [self setPrimitiveValue:value forKey:@"sourceText"];
  [self didChangeValueForKey:@"sourceText"];
  [self willChangeValueForKey:@"sourceTextAsData"];
  [self setPrimitiveValue:[NSKeyedArchiver archivedDataWithRootObject:value] forKey:@"sourceTextAsData"];
  [self didChangeValueForKey:@"sourceTextAsData"];
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
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self didAccessValueForKey:@"colorAsData"]; 
    [self willChangeValueForKey:@"color"];
    [self setPrimitiveValue:result forKey:@"color"];
    [self didChangeValueForKey:@"color"];

  }
  return result;
}
//end color

-(void) setColor:(NSColor*)value
{
  [self willChangeValueForKey:@"color"];
  [self setPrimitiveValue:value forKey:@"color"];
  [self didChangeValueForKey:@"color"];
  [self willChangeValueForKey:@"colorAsData"];
  [self setPrimitiveValue:[NSKeyedArchiver archivedDataWithRootObject:value] forKey:@"colorAsData"];
  [self didChangeValueForKey:@"colorAsData"];
}
//end setColor:

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
  double result = 0;
  [self willAccessValueForKey:@"modeAsInteger"]; 
  result = [[self primitiveValueForKey:@"modeAsInteger"] intValue];
  [self didAccessValueForKey:@"modeAsInteger"]; 
  return (latex_mode_t)result;
}
//end mode

-(void) setMode:(latex_mode_t)value
{
  [self willChangeValueForKey:@"modeAsInteger"];
  [self setPrimitiveValue:[NSNumber numberWithInt:(int)value] forKey:@"modeAsInteger"];
  [self didChangeValueForKey:@"modeAsInteger"];
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
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self didAccessValueForKey:@"backgroundColorAsData"]; 
    [self willChangeValueForKey:@"backgroundColor"];
    [self setPrimitiveValue:result forKey:@"backgroundColor"];
    [self didChangeValueForKey:@"backgroundColor"];
  }
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
  [self willChangeValueForKey:@"backgroundColorAsData"];
  [self setPrimitiveValue:!value ? nil : [NSKeyedArchiver archivedDataWithRootObject:value] forKey:@"backgroundColorAsData"];
  [self didChangeValueForKey:@"backgroundColorAsData"];
  [self _reannotatePDFDataUsingPDFKeywords:YES];
  [[NSNotificationCenter defaultCenter] postNotificationName:LatexitEquationDidChangeNotification object:self];
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
  [self willChangeValueForKey:@"title"];
  [self setPrimitiveValue:value forKey:@"title"];
  [self didChangeValueForKey:@"title"];
  [self _reannotatePDFDataUsingPDFKeywords:YES];
  [[NSNotificationCenter defaultCenter] postNotificationName:LatexitEquationDidChangeNotification object:self];
}
//end setTitle:

-(NSImage*) pdfCachedImage
{
  NSImage* result = nil;
  [self willAccessValueForKey:@"pdfCachedImage"];
  result = [self primitiveValueForKey:@"pdfCachedImage"];
  [self didAccessValueForKey:@"pdfCachedImage"]; 
  if (!result)
  {
    NSPDFImageRep* pdfImageRep = [[NSPDFImageRep alloc] initWithData:[self pdfData]];
    result = [[NSImage alloc] initWithSize:[pdfImageRep size]];
    [result setCacheMode:NSImageCacheNever];
    [result setDataRetained:YES];
    [result setScalesWhenResized:YES];
    [result addRepresentation:pdfImageRep];
    [pdfImageRep release];
    [self setValue:result forKey:@"pdfCachedImage"];
  }
  return result;
} 
//end pdfCachedImage

-(NSString*) modeAsString
{
  NSString* string = nil;
  switch([self mode])
  {
    case LATEX_MODE_EQNARRAY:
      string = @"eqnarray";
      break;
    case LATEX_MODE_DISPLAY:
      string = @"display";
      break;
    case LATEX_MODE_INLINE:
      string = @"inline";
      break;
    case LATEX_MODE_TEXT:
      string = @"text";
      break;
  }
  return string;
}
//end modeAsString

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
    case LATEX_MODE_TEXT:
      break;
  }
  return result;
}
//end encapsulatedSource

//useful to resynchronize the pdfData with the actual parameters (background color...)
//its use if VERY rare, so that it is not automatic for the sake of efficiency
-(void) _reannotatePDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords
{
  annotateDataDirtyState |= YES;
  if (![self isUpdating])
  {
    NSData* newData = [self annotatedPDFDataUsingPDFKeywords:usingPDFKeywords];
    [self setPdfData:newData];
  }
}
//end _reannotatePDFDataUsingPDFKeywords:

-(NSData*) annotatedPDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords
{
  NSData* newData = [self pdfData];

  //first, we retreive the baseline if possible
  double baseline = 0;

  NSData* pdfData = [self pdfData];
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
  NSAttributedString* preamble   = [self preamble];
  NSAttributedString* sourceText = [self sourceText];
  newData = [LatexProcessor annotatePdfDataInLEEFormat:newData
              preamble:(preamble ? [preamble string] : @"") source:(sourceText ? [sourceText string] : @"")
                 color:[self color] mode:[self mode] magnification:[self pointSize] baseline:baseline
       backgroundColor:[self backgroundColor] title:[self title]];
  return newData;
}
//end annotatedPDFDataUsingPDFKeywords:usingPDFKeywords

//to feed a pasteboard. It needs a document, because there may be some temporary files needed for certain kind of data
//the lazyDataProvider, if not nil, is the one who will call [pasteboard:provideDataForType] *as needed* (to save time)
-(void) writeToPasteboard:(NSPasteboard *)pboard isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider
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

  NSData* pdfData = [self pdfData];
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
      [pboard addTypes:[NSArray arrayWithObjects:NSPDFPboardType, @"com.adobe.pdf", nil] owner:lazyDataProvider];
      if (!lazyDataProvider) [pboard setData:data forType:NSPDFPboardType];
      if (!lazyDataProvider) [pboard setData:data forType:@"com.adobe.pdf"];
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
  }//end switch
}
//end writeToPasteboard:isLinkBackRefresh:lazyDataProvider:

-(id) plistDescription
{
  NSMutableDictionary* plist = 
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
       @"1.16.0", @"version",
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

@end
