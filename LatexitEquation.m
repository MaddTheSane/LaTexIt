//
//  LatexitEquation.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/10/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "LatexitEquation.h"

#import "LaTeXProcessor.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSImageExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>
#import <Quartz/Quartz.h>

NSString* LatexitEquationsPboardType = @"LatexitEquationsPboardType";

static NSEntityDescription* cachedEntity = nil;
static NSMutableArray*      managedObjectContextStackInstance = nil;

@interface LatexitEquation (PrivateAPI)
+(NSMutableArray*) managedObjectContextStack;
-(void) beginUpdate;
-(void) endUpdate;
-(BOOL) isUpdating;
@end

@implementation LatexitEquation

+(NSEntityDescription*) entity
{
  if (!cachedEntity)
  {
    @synchronized(self)
    {
      if (!cachedEntity)
        cachedEntity = [[[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])] retain];
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
    [managedObjectContextStackInstance addObject:context];
  }

}
//end pushManagedObjectContext:

+(NSManagedObjectContext*) currentManagedObjectContext
{
  NSManagedObjectContext* result = nil;
  @synchronized([self managedObjectContextStack])
  {
    result = [managedObjectContextStackInstance lastObject];
  }
  return result;
}
//end currentManagedObjectContext

+(NSManagedObjectContext*) popManagedObjectContext
{
  NSManagedObjectContext* result = nil;
  @synchronized([self managedObjectContextStack])
  {
    result = [managedObjectContextStackInstance lastObject];
    [managedObjectContextStackInstance removeLastObject];
  }
  return result;
}
//end popManagedObjectContext

+(id) latexitEquationWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
                           color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
                 backgroundColor:(NSColor*)backgroundColor
{
  id instance = [[[self class] alloc] initWithPDFData:someData preamble:aPreamble sourceText:aSourceText
                                              color:aColor pointSize:aPointSize date:aDate mode:aMode
                                              backgroundColor:backgroundColor];
  return [instance autorelease];
}
//end historyItemWithPDFData:preamble:sourceText:color:pointSize:date:mode:backgroundColor:

+(id) latexitEquationWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
{
  return [[[[self class] alloc] initWithPDFData:someData useDefaults:useDefaults] autorelease];
}
//end historyItemWithPDFData:useDefaults:

-(id) initWithPDFData:(NSData*)someData preamble:(NSAttributedString*)aPreamble sourceText:(NSAttributedString*)aSourceText
              color:(NSColor*)aColor pointSize:(double)aPointSize date:(NSDate*)aDate mode:(latex_mode_t)aMode
              backgroundColor:(NSColor*)aBackgroundColor
{
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
  [self beginUpdate];
  [self setPdfData:someData];
  [self setPreamble:aPreamble];
  [self setSourceText:aSourceText];
  [self setColor:aColor];
  [self setPointSize:aPointSize];
  [self setDate:aDate ? [[aDate copy] autorelease] : [NSDate date]];
  [self setMode:aMode];
  [self setTitle:nil];
    
  if (!aBackgroundColor && [[PreferencesController sharedController] documentUseAutomaticHighContrastedPreviewBackground])
    aBackgroundColor = ([aColor grayLevel] > .5) ? [NSColor blackColor] : nil;
  [self setBackgroundColor:aBackgroundColor];
  [self endUpdate];
  return self;
}
//end initWithPDFData:preamble:sourceText:color:pointSize:date:mode:backgroundColor:

-(id) initWithPDFData:(NSData*)someData useDefaults:(BOOL)useDefaults
{
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
  [self setPdfData:someData];
  NSString* dataAsString = [[[NSString alloc] initWithData:someData encoding:NSMacOSRomanStringEncoding] autorelease];
  NSArray*  testArray    = nil;
  
  BOOL isLaTeXiTPDF = NO;

  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSFont* defaultFont = [preferencesController editionFont];
  NSDictionary* defaultAttributes = [NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName];
  NSAttributedString* defaultPreambleAttributedString = [[PreferencesController sharedController] preambleDocumentAttributedString];
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
                      : (latex_mode_t) (useDefaults ? [preferencesController latexisationLaTeXMode] : 0);
  mode = validateLatexMode(mode); //Added starting from version 1.7.0
  [self setMode:mode];

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
  
  if (!isLaTeXiTPDF)
  {
    [self release];
    self = nil;
  }//end if (!isLaTeXiTPDF)
  
  return self;
}
//end initWithPDFData:useDefaults:

-(id) copyWithZone:(NSZone*)zone
{
  id clone = [[[self class] alloc] initWithPDFData:[self pdfData] preamble:[self preamble] sourceText:[self sourceText]
                                             color:[self color] pointSize:[self pointSize] date:[self date]
                                            mode:[self mode] backgroundColor:[self backgroundColor]];
  [[self managedObjectContext] safeInsertObject:clone];
  return clone;
}
//end copyWithZone:

-(id) initWithCoder:(NSCoder*)coder
{
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:nil])))
    return nil;
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
  return self;
}
//end initWithCoder:

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:@"2.0.0"              forKey:@"version"];//we encode the current LaTeXiT version number
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

-(void) didTurnIntoFault
{
  @synchronized(self)
  {
    [self->pdfCachedImage release];
    self->pdfCachedImage = nil;
  }//@synchronized(self)
}
//end didTurnIntoFault

-(void) beginUpdate
{
  ++updateLevel;
}
//end beginUpdate

-(void) endUpdate
{
  --updateLevel;
  if (![self isUpdating] && annotateDataDirtyState)
    [self reannotatePDFDataUsingPDFKeywords:YES];
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
  @synchronized(self)
  {
    [self->pdfCachedImage release];
    self->pdfCachedImage = nil;
  }
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
    [self didAccessValueForKey:@"preambleAsData"];
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self setPrimitiveValue:result forKey:@"preamble"];
  }
  return result;
} 
//end preamble

-(void) setPreamble:(NSAttributedString*)value
{
  [self willChangeValueForKey:@"preamble"];
  [self setPrimitiveValue:value forKey:@"preamble"];
  [self didChangeValueForKey:@"preamble"];
  NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"preambleAsData"];
  [self setPrimitiveValue:archivedData forKey:@"preambleAsData"];
  [self didChangeValueForKey:@"preambleAsData"];
  [self reannotatePDFDataUsingPDFKeywords:YES];
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
  [self willChangeValueForKey:@"sourceText"];
  [self setPrimitiveValue:value forKey:@"sourceText"];
  [self didChangeValueForKey:@"sourceText"];
  NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"sourceTextAsData"];
  [self setPrimitiveValue:archivedData forKey:@"sourceTextAsData"];
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
    [self didAccessValueForKey:@"colorAsData"];
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self setPrimitiveValue:result forKey:@"color"];
  }//end if (!result)
  return result;
}
//end color

-(void) setColor:(NSColor*)value
{
  [self willChangeValueForKey:@"color"];
  [self setPrimitiveValue:value forKey:@"color"];
  [self didChangeValueForKey:@"color"];
  NSData* archivedData = [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"colorAsData"];
  [self setPrimitiveValue:archivedData forKey:@"colorAsData"];
  [self didChangeValueForKey:@"colorAsData"];
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
  [self willChangeValueForKey:@"baseline"];
  [self setPrimitiveValue:[NSNumber numberWithDouble:value] forKey:@"baseline"];
  [self didChangeValueForKey:@"baseline"];
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
  latex_mode_t result = 0;
  [self willAccessValueForKey:@"modeAsInteger"];
  result = (latex_mode_t)[[self primitiveValueForKey:@"modeAsInteger"] intValue];
  [self didAccessValueForKey:@"modeAsInteger"];
  return result;
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
    [self didAccessValueForKey:@"backgroundColorAsData"];
    result = !archivedData ? nil : [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];
    [self setPrimitiveValue:result forKey:@"backgroundColor"];
  }//end if (!result)
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
  NSData* archivedData = !value ? nil : [NSKeyedArchiver archivedDataWithRootObject:value];
  [self willChangeValueForKey:@"backgroundColorAsData"];
  [self setPrimitiveValue:archivedData forKey:@"backgroundColorAsData"];
  [self didChangeValueForKey:@"backgroundColorAsData"];
  [self reannotatePDFDataUsingPDFKeywords:YES];
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
  if ((value != oldTitle) && ![value isEqualToString:oldTitle])
  {
    [self willChangeValueForKey:@"title"];
    [self setPrimitiveValue:value forKey:@"title"];
    [self didChangeValueForKey:@"title"];
    [self reannotatePDFDataUsingPDFKeywords:YES];
  }//end if ((value != oldTitle) && ![value isEqualToString:oldTitle])
}
//end setTitle:

-(NSImage*) pdfCachedImage
{
  NSImage* result = nil;
  @synchronized(self)
  {
    result = self->pdfCachedImage;
    if (!result)
    {
      NSData* pdfData = [self pdfData];
      NSPDFImageRep* pdfImageRep = !pdfData ? nil : [[NSPDFImageRep alloc] initWithData:pdfData];
      if (pdfImageRep)
      {
        self->pdfCachedImage = [[NSImage alloc] initWithSize:[pdfImageRep size]];
        [self->pdfCachedImage setCacheMode:NSImageCacheNever];
        [self->pdfCachedImage setDataRetained:YES];
        [self->pdfCachedImage setScalesWhenResized:YES];
        [self->pdfCachedImage addRepresentation:pdfImageRep];
        if (![self->pdfCachedImage bitmapImageRepresentationWithMaxSize:NSMakeSize(0, 128)])//to help drawing in library
          [self->pdfCachedImage bitmapImageRepresentation];
        [pdfImageRep release];
        result = self->pdfCachedImage;
      }//end if (pdfImageRep)
    }//end if (!result)
  }//end @synchronized(self)
  return result;
} 
//end pdfCachedImage

-(NSString*) modeAsString
{
  NSString* result = [[self class] latexModeToString:[self mode]];
  return result;
}
//end modeAsString

+(NSString*) latexModeToString:(latex_mode_t)mode
{
  NSString* result = nil;
  switch(mode)
  {
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
  }
  return result;
}
//end latexModeToString:

+(latex_mode_t) latexModeFromString:(NSString*)modeAsString
{
  latex_mode_t result = LATEX_MODE_DISPLAY;
  if ([modeAsString isEqualToString:@"eqnarray"])
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

-(NSString*) titleAuto
{
  NSString* result = [[[self sourceText] string] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  unsigned int endIndex = MIN(17U, [result length]);
  result = [result substringToIndex:endIndex];
  return result;
}
//end titleAuto

//useful to resynchronize the pdfData with the actual parameters (background color...)
//its use if VERY rare, so that it is not automatic for the sake of efficiency
-(void) reannotatePDFDataUsingPDFKeywords:(BOOL)usingPDFKeywords
{
  annotateDataDirtyState |= YES;
  if (![self isUpdating])
  {
    NSData* newData = [self annotatedPDFDataUsingPDFKeywords:usingPDFKeywords];
    [self setPdfData:newData];
  }
}
//end reannotatePDFDataUsingPDFKeywords:

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
  
  [self setBaseline:baseline];

  //then, we rewrite the pdfData
  if (usingPDFKeywords)
  {
    PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
    NSDictionary* attributes =
      [NSDictionary dictionaryWithObjectsAndKeys:
          [[NSWorkspace sharedWorkspace] applicationName], PDFDocumentCreatorAttribute,
         nil];
    [pdfDocument setDocumentAttributes:attributes];
    newData = [pdfDocument dataRepresentation];
    [pdfDocument release];
  }

  //annotate in LEE format
  NSAttributedString* preamble   = [self preamble];
  NSAttributedString* sourceText = [self sourceText];
  newData = [[LaTeXProcessor sharedLaTeXProcessor] annotatePdfDataInLEEFormat:newData
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

  NSData* pdfData = [self pdfData];
  [pboard addTypes:[NSArray arrayWithObject:NSFileContentsPboardType] owner:self];
  [pboard setData:pdfData forType:NSFileContentsPboardType];
  
  PreferencesController* preferencesController = [PreferencesController sharedController];

  //Stores the data in the pasteboard corresponding to what the user asked for (pdf, jpeg, tiff...)
  export_format_t exportFormat = [preferencesController exportFormat];
  NSData* data = lazyDataProvider ? nil :
    [[LaTeXProcessor sharedLaTeXProcessor]
      dataForType:exportFormat pdfData:pdfData
      jpegColor:[preferencesController exportJpegBackgroundColor] jpegQuality:[preferencesController exportJpegQualityPercent]
      scaleAsPercent:[preferencesController exportScalePercent]
      compositionConfiguration:[preferencesController compositionConfigurationDocument]];
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
       @"2.0.0", @"version",
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

-(id) initWithDescription:(id)description
{
  NSManagedObjectContext* managedObjectContext = [LatexitEquation currentManagedObjectContext];
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  [self beginUpdate];
  [self setPdfData:[description objectForKey:@"pdfData"]];
  NSString* string = [description objectForKey:@"preamble"];
  [self setPreamble:(!string ? nil : [[[NSAttributedString alloc] initWithString:string] autorelease])];
  string = [description objectForKey:@"sourceText"];
  [self setSourceText:(!string ? nil : [[[NSAttributedString alloc] initWithString:string] autorelease])];
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

@end
