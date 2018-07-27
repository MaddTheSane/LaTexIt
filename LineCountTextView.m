//  LineCountTextView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.

//The LineCountTextView is an NSTextView that I have associated with a LineCountRulerView
//This ruler will display the line numbers
//Another feature is the ability to disable the edition of some lines
//Another feature is the ability to add error markers at some lines

#import "LineCountTextView.h"

#import "AppController.h"
#import "CGPDFExtras.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LatexitEquation.h"
#import "LibraryEquation.h"
#import "LibraryManager.h"
#import "LineCountRulerView.h"
#import "MyDocument.h"
#import "NSAttributedStringExtended.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSMutableArrayExtended.h"
#import "NSStringExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "PreferencesController.h"
#import "SMLSyntaxColouring.h"
#import "Utils.h"

#import "RegexKitLite.h"

#import <Carbon/Carbon.h>

NSString* LineCountDidChangeNotification = @"LineCountDidChangeNotification";
NSString* FontDidChangeNotification      = @"FontDidChangeNotification";

@interface LineCountTextView (PrivateAPI)
-(void) _computeLineRanges;
-(void) _initializeSpellChecker;
-(void) replaceCharactersInRange:(NSRange)range withString:(NSString*)string withUndo:(BOOL)withUndo;
-(void) insertTextAtMousePosition:(id)object;
@end

@implementation LineCountTextView

static NSArray* WellKnownLatexKeywords = nil;
static int SpellCheckerDocumentTag = 0;

+(void) initialize
{
  //load well-known LaTeX keywords
  @synchronized(self)
  {
    if (!WellKnownLatexKeywords)
    {
      NSString*  keywordsPlistPath = [[NSBundle mainBundle] pathForResource:@"latex-keywords" ofType:@"plist"];
      NSData*    dataKeywordsPlist = [NSData dataWithContentsOfFile:keywordsPlistPath options:NSUncachedRead error:nil];
      NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
      NSString* errorString = nil;
      NSDictionary* plist = [NSPropertyListSerialization propertyListFromData:dataKeywordsPlist
                                                             mutabilityOption:NSPropertyListImmutable
                                                                       format:&format errorDescription:&errorString];
      NSString* version = [plist objectForKey:@"version"];
      //we can check the version...
      if (!version || [version compare:@"1.9.0" options:NSCaseInsensitiveSearch|NSNumericSearch] == NSOrderedAscending)
      {
      }
      WellKnownLatexKeywords = [[plist objectForKey:@"packages"] retain];
    }//end if WellKnownLatexKeywords
  }//end @synchronized
}
//end initialize

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  self->lineRanges = [[NSMutableArray alloc] init];
  self->forbiddenLines = [[NSMutableSet alloc] init];
  [self setDelegate:(id)self];

  NSArray* registeredDraggedTypes = [self registeredDraggedTypes];

  //strange fix for splitview
  NSRect frame = [self frame];
  frame.origin.y = MAX(0,   frame.origin.y);
  [self setFrame:frame];
  
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults addObserver:self forKeyPath:SyntaxColoringEnableKey options:NSKeyValueObservingOptionNew context:nil];
  [userDefaults addObserver:self forKeyPath:SyntaxColoringTextForegroundColorKey options:NSKeyValueObservingOptionNew context:nil];
  [userDefaults addObserver:self forKeyPath:SyntaxColoringTextBackgroundColorKey options:NSKeyValueObservingOptionNew context:nil];
  [userDefaults addObserver:self forKeyPath:SyntaxColoringCommandColorKey options:NSKeyValueObservingOptionNew context:nil];
  [userDefaults addObserver:self forKeyPath:SyntaxColoringMathsColorKey options:NSKeyValueObservingOptionNew context:nil];
  [userDefaults addObserver:self forKeyPath:SyntaxColoringKeywordColorKey options:NSKeyValueObservingOptionNew context:nil];
  [userDefaults addObserver:self forKeyPath:SyntaxColoringCommentColorKey options:NSKeyValueObservingOptionNew context:nil];
  [userDefaults addObserver:self forKeyPath:EditionTabKeyInsertsSpacesEnabledKey options:NSKeyValueObservingOptionNew context:nil];
  [userDefaults addObserver:self forKeyPath:EditionTabKeyInsertsSpacesCountKey options:NSKeyValueObservingOptionNew context:nil];
  
  [self _computeLineRanges];

  NSArray* typesToAdd =
    [NSArray arrayWithObjects:NSStringPboardType, NSColorPboardType, NSPDFPboardType,
                              NSFilenamesPboardType, NSFileContentsPboardType, NSFilesPromisePboardType,
                              NSRTFDPboardType, LatexitEquationsPboardType, LibraryItemsArchivedPboardType,
                              LibraryItemsWrappedPboardType,
                              //@"com.apple.iWork.TSPNativeMetadata",
                              nil];
  [self registerForDraggedTypes:[registeredDraggedTypes arrayByAddingObjectsFromArray:typesToAdd]];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [userDefaults removeObserver:self forKeyPath:SyntaxColoringEnableKey];
  [userDefaults removeObserver:self forKeyPath:SyntaxColoringTextForegroundColorKey];
  [userDefaults removeObserver:self forKeyPath:SyntaxColoringTextBackgroundColorKey];
  [userDefaults removeObserver:self forKeyPath:SyntaxColoringCommandColorKey];
  [userDefaults removeObserver:self forKeyPath:SyntaxColoringMathsColorKey];
  [userDefaults removeObserver:self forKeyPath:SyntaxColoringKeywordColorKey];
  [userDefaults removeObserver:self forKeyPath:SyntaxColoringCommentColorKey];
  [userDefaults removeObserver:self forKeyPath:EditionTabKeyInsertsSpacesEnabledKey];
  [userDefaults removeObserver:self forKeyPath:EditionTabKeyInsertsSpacesCountKey];
  [self removeObserver:self forKeyPath:NSAttributedStringBinding];
  [self->syntaxColouring release];
  [self->lineRanges release];
  [self->forbiddenLines release];
  [self->lineCountRulerView release];
  [self->spacesString release];
  [super dealloc];
}
//end dealloc

-(void) _initializeSpellChecker:(id)object
{
  if ([self respondsToSelector:@selector(setAutomaticTextReplacementEnabled:)])
    [self setAutomaticTextReplacementEnabled:NO];
  if (!spellCheckerHasBeenInitialized)
  {
    NSMutableArray* keywordsToCheck = [NSMutableArray array];
    unsigned int nbPackages = WellKnownLatexKeywords ? [WellKnownLatexKeywords count] : 0;
    while(nbPackages--)
    {
      NSDictionary* package = [WellKnownLatexKeywords objectAtIndex:nbPackages];
      [keywordsToCheck addObject:[package objectForKey:@"name"]];
      NSArray* kw = [package objectForKey:@"keywords"];
      unsigned int count = [kw count];
      while(count--)
        [keywordsToCheck addObject:[[kw objectAtIndex:count] objectForKey:@"word"]];
    }
    [keywordsToCheck setArray:[[NSSet setWithArray:keywordsToCheck] allObjects]];
    unsigned int count = [keywordsToCheck count];
    while(count--)
    {
      NSString* w = [keywordsToCheck objectAtIndex:count];
      if ([w startsWith:@"\\" options:0])
        [keywordsToCheck addObject:[w substringFromIndex:1]];
    }
    [keywordsToCheck setArray:[[NSSet setWithArray:keywordsToCheck] allObjects]];
    if (SpellCheckerDocumentTag == 0)
      [[NSSpellChecker sharedSpellChecker] setIgnoredWords:keywordsToCheck inSpellDocumentWithTag:[self spellCheckerDocumentTag]];
    spellCheckerHasBeenInitialized = YES;
  }
}
//end _initializeSpellChecker:

-(void) awakeFromNib
{
  NSScrollView* scrollView = (NSScrollView*) [[self superview] superview];
  [self setRulerVisible:YES];
  [scrollView setHasHorizontalRuler:NO];
  [scrollView setHasVerticalRuler:YES];
  self->lineCountRulerView = [[LineCountRulerView alloc] initWithScrollView:scrollView orientation:NSVerticalRuler];
  [scrollView setVerticalRulerView:self->lineCountRulerView];
  [self->lineCountRulerView setClientView:self];
  self->syntaxColouring = [[SMLSyntaxColouring alloc] initWithTextView:self];

  [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(_initializeSpellChecker:) userInfo:nil repeats:NO];
  
  [self bind:@"continuousSpellCheckingEnabled" toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:SpellCheckingEnableKey] options:nil];
  [self addObserver:self forKeyPath:NSAttributedStringBinding options:NSKeyValueObservingOptionNew context:nil];

  [self bind:@"tabKeyInsertsSpacesEnabled" toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:EditionTabKeyInsertsSpacesEnabledKey] options:nil];
  [self bind:@"tabKeyInsertsSpacesCount" toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:EditionTabKeyInsertsSpacesCountKey] options:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(colorDidChange:) name:NSColorPanelColorDidChangeNotification object:nil];
}
//end awakeFromNib

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:NSAttributedStringBinding])
    [[self syntaxColouring] recolourCompleteDocument];
  else if ([keyPath isEqualToString:SyntaxColoringEnableKey] ||
           [keyPath isEqualToString:SyntaxColoringTextForegroundColorKey] || [keyPath isEqualToString:SyntaxColoringTextBackgroundColorKey] ||
           [keyPath isEqualToString:SyntaxColoringCommandColorKey] || [keyPath isEqualToString:SyntaxColoringMathsColorKey] ||
           [keyPath isEqualToString:SyntaxColoringKeywordColorKey] || [keyPath isEqualToString:SyntaxColoringCommentColorKey])
  {
    [self->syntaxColouring setColours];
    [self->syntaxColouring recolourCompleteDocument];
    [self setNeedsDisplay:YES];
  }//end if syntax colouring options change
}
//end observeValueForKeyPath:

-(void) setAttributedString:(NSAttributedString*)value//triggers recolouring
{
  NSDictionary* attributes =
    [NSDictionary dictionaryWithObjectsAndKeys:
     [[PreferencesController sharedController] editionFont], NSFontAttributeName,
     nil];
  NSMutableAttributedString* attributedString = [[value mutableCopy] autorelease];
  [attributedString addAttributes:attributes range:NSMakeRange(0, [attributedString length])];
  
  if (attributedString)
    [[self textStorage] setAttributedString:attributedString];
  [self->syntaxColouring recolourCompleteDocument];
}
//end setAttributedString:

-(void) insertText:(id)aString
{
  if (self->tabKeyInsertsSpacesEnabled)
  {
    if ([self->spacesString length] != self->tabKeyInsertsSpacesCount)
    {
      [self->spacesString release];
      self->spacesString = nil;
    }//end if ([self->spacesString length] != self->tabKeyInsertsSpacesCount)
    if (!self->spacesString)
    {
      char* spaces = malloc(self->tabKeyInsertsSpacesCount*sizeof(char));
      if (spaces)
      {
        memset(spaces, ' ', self->tabKeyInsertsSpacesCount*sizeof(char));
        self->spacesString =
          [[NSString alloc] initWithBytes:spaces length:self->tabKeyInsertsSpacesCount encoding:NSUTF8StringEncoding];
        free(spaces);
      }//end if (spaces)
    }//end if (!self->spacesString)
  }//end if (self->tabKeyInsertsSpacesEnabled)

  if (!self->spacesString){//do nothing
  }
  else if ([aString isKindOfClass:[NSString class]])
  {
    if (self->spacesString)
      aString = [aString stringByReplacingOccurrencesOfRegex:@"\t" withString:self->spacesString];
  }//end if ([aString isKindOfClass:[NSString class]])
  else if ([aString isKindOfClass:[NSAttributedString class]])
  {
    NSMutableAttributedString* attributedString = [[aString mutableCopy] autorelease];
    [attributedString setAttributes:nil range:NSMakeRange(0, [attributedString length])];
    NSRange range = [[attributedString string] rangeOfString:@"\t"];
    while(range.location != NSNotFound)
    {
      [attributedString replaceCharactersInRange:range withString:self->spacesString];
      range.location += [self->spacesString length];
      range.length = [attributedString length]-range.location;
      range = [[attributedString string] rangeOfString:@"\t" options:0 range:range];
    }//while(range.location != NSNotFound)
    aString = attributedString;
  }//end if ([aString isKindOfClass:[NSAttributedString class]])
  [super insertText:aString];
}
//end insertText:

-(LineCountRulerView*) lineCountRulerView
{
  return lineCountRulerView;
}
//end lineCountRulerView

-(NSInteger) spellCheckerDocumentTag
{
  if (SpellCheckerDocumentTag == 0)
    SpellCheckerDocumentTag = [super spellCheckerDocumentTag];
  return SpellCheckerDocumentTag;
}
//end spellCheckerDocumentTag

//since the nextResponder is the imageView (see MyDocument.m), we must override the behaviour for scrollWheel
-(void) scrollWheel:(NSEvent*)event
{
  [[[self superview] superview] scrollWheel:event];
}
//end scrollWheel:

//as its own delegate, only notifications from self are seen
-(void) textDidChange:(NSNotification*)notification
{
  [self _computeLineRanges]; //line ranges are computed at each change. It is not very efficient and will be very slow
                             //for large texts, but in LaTeXiT, texts are small, and I did not know how to do that simply otherwise

  //normal lines are displayed with the default foregound color
  NSDictionary* normalAttributes =
    [NSDictionary dictionaryWithObjectsAndKeys:
      [[PreferencesController sharedController] editionSyntaxColoringTextForegroundColor],
      NSForegroundColorAttributeName, nil];
  [[self textStorage] addAttributes:normalAttributes range:NSMakeRange(0, [[self textStorage] length])];

  //line count
  [[NSNotificationCenter defaultCenter] postNotificationName:LineCountDidChangeNotification object:self];
  
  //syntax colouring
  @try{
    [syntaxColouring textDidChange:notification];
  }
  @catch (NSException*) {
  }

  //forbidden lines are displayed in gray
  NSDictionary* forbiddenAttributes =
    [NSDictionary dictionaryWithObjectsAndKeys:[NSColor colorWithCalibratedRed:0.5 green:0.5 blue:0.5 alpha:1],
                                               NSForegroundColorAttributeName, nil];

  //updates text attributes to set the color
  NSEnumerator* enumerator = [forbiddenLines objectEnumerator];
  NSNumber*    numberIndex = [enumerator nextObject];
  while(numberIndex)
  {
    unsigned int index = [numberIndex intValue];
    if (index < [lineRanges count])
    {
      NSRange range = NSRangeFromString([lineRanges objectAtIndex:index]);
      [syntaxColouring removeColoursFromRange:range];
      [[self textStorage] addAttributes:forbiddenAttributes range:range];
    }
    numberIndex = [enumerator nextObject];
  }
}
//end textDidChange:

-(NSArray*) lineRanges
{
  return lineRanges;
}
//end lineRanges

-(unsigned int) nbLines
{
  return lineRanges ? [lineRanges count] : 0;
}
//end nbLines

-(void) _computeLineRanges
{
  [lineRanges removeAllObjects];
  
  NSString* string = [self string];
  NSArray* lines = [(string ? string : [NSString string]) componentsSeparatedByString:@"\n"];
  const int count = [lines count];
  int index = 0;
  int location = 0;
  for(index = 0 ; index < count ; ++index)
  {
    NSString* line = [lines objectAtIndex:index];
    NSRange lineRange = NSMakeRange(location, [line length]);
    [lineRanges addObject:NSStringFromRange(lineRange)];
    location += [line length]+1;
  }
}
//end _computeLineRanges

//remove error markers
-(void) clearErrors
{
  [lineCountRulerView clearErrors];
}
//end clearErrors

//add error markers
-(void) setErrorAtLine:(unsigned int)lineIndex message:(NSString*)message
{
  [lineCountRulerView setErrorAtLine:lineIndex message:message];
}
//end setErrorAtLine:message:

//change the shift in displayed numerotation
-(void) setLineShift:(int)aShift
{
  lineShift = aShift;
  [lineCountRulerView setLineShift:aShift];
}
//end setLineShift:

//the shift in displayed numerotation
-(int) lineShift
{
  return lineShift;
}
//end lineShift

//change the status (forbidden or not) of a line (forbidden means : cannot be edited)
-(void) setForbiddenLine:(unsigned int)index forbidden:(BOOL)forbidden
{
  if (forbidden)
    [forbiddenLines addObject:[NSNumber numberWithUnsignedInt:index]];
  else
    [forbiddenLines removeObject:[NSNumber numberWithUnsignedInt:index]];
}
//end setForbiddenLine:forbidden

//checks if the user is typing in a forbiddenLine; if it is the case, it is discarded
-(BOOL) textView:(NSTextView*)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange
                                               replacementString:(NSString*)replacementString
{
  BOOL accepts = YES;
  
  affectedCharRange.length = MAX(1U, affectedCharRange.length);
  NSEnumerator* enumerator = [forbiddenLines objectEnumerator];
  NSNumber* forbiddenLineNumber = nil;
  while(accepts && (forbiddenLineNumber = [enumerator nextObject]))
  {
    unsigned int index = [forbiddenLineNumber unsignedIntValue];
    if (index < [lineRanges count])
    {
      NSRange lineRange = NSRangeFromString([lineRanges objectAtIndex:index]);
      ++lineRange.length;
      NSRange intersection = NSIntersectionRange(lineRange, affectedCharRange);
      if (intersection.length)
        accepts &= NO;
    }
  }

  return accepts;
}
//end textView:shouldChangeTextInRange:replacementString:

-(void)rulerView:(NSRulerView *)aRulerView handleMouseDown:(NSEvent *)theEvent
{
  //does nothing but prevents console message error
}
//end rulerView:handleMouseDown:

-(BOOL) rulerView:(NSRulerView *)aRulerView shouldAddMarker:(NSRulerMarker*)aMarker
{
  return NO;
}
//end rulerView:shouldAddMarker:

-(BOOL) gotoLine:(int)row
{
  BOOL ok = NO;
  --row; //the first line is at 0, but the user thinks it is 1
  row -= lineShift;
  ok = (row >=0) && ((unsigned int) row < [lineRanges count]);
  if (ok)
  {
    NSRange range = NSRangeFromString([lineRanges objectAtIndex:row]);
    [self setSelectedRange:range];
    [self scrollRangeToVisible:range];
  }
  return ok;
}
//end gotoLine:

//responds to the font manager
-(void) changeFont:(id)sender
{
  NSRange range   = [self selectedRange];
  NSFont* oldFont = [self font];
  NSFont* newFont = [sender convertFont:oldFont];
  NSMutableDictionary* typingAttributes = [NSMutableDictionary dictionaryWithDictionary:[self typingAttributes]];
  if (!range.length)
  {
    [typingAttributes setObject:newFont forKey:NSFontAttributeName];
    [self setTypingAttributes:typingAttributes];
  }
  else
    [self setFont:newFont range:range];
  [lineCountRulerView setNeedsDisplay:YES];
  [[NSNotificationCenter defaultCenter] postNotificationName:FontDidChangeNotification object:self];
}
//end changeFont:

//We can drop on the imageView only if the PDF has been made by LaTeXiT (as "creator" document attribute)
//So, the keywords of the PDF contain the whole document state
-(NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
  BOOL ok = NO;
  BOOL shouldBePDFData = NO;
  NSData* data = nil;
  
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsWrappedPboardType]])
    ok = YES;
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsArchivedPboardType]])
    ok = YES;
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:LatexitEquationsPboardType]])
    ok = YES;
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])
    ok = YES;
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSPDFPboardType]])
  {
    shouldBePDFData = YES;
    data = [pboard dataForType:NSPDFPboardType];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:@"com.adobe.pdf"]])
  {
    shouldBePDFData = YES;
    data = [pboard dataForType:@"com.adobe.pdf"];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFileContentsPboardType]])
  {
    shouldBePDFData = YES;
    data = [pboard dataForType:NSFileContentsPboardType];
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
  {
    ok = YES;
    /*shouldBePDFData = YES;
    NSArray* plist = [pboard propertyListForType:NSFilenamesPboardType];
    if (plist && [plist count])
    {
      NSString* filename = [plist objectAtIndex:0];
      data = [NSData dataWithContentsOfFile:filename options:NSUncachedRead error:nil];
    }*/
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSRTFDPboardType]])
  {
    ok = YES;
  }
  else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
  {
    ok = YES;
  }

  if (shouldBePDFData)
    ok = CGPDFDocumentPossibleFromData(data);
  acceptDrag = ok ? NSDragOperationCopy : NSDragOperationNone;
  return acceptDrag;
}
//end draggingEntered:

-(NSDragOperation) draggingUpdated:(id <NSDraggingInfo>)sender
{
  NSDragOperation result = acceptDrag ? NSDragOperationCopy : NSDragOperationNone;
  /*
  BOOL isAltPressed = NO;
  CGEventRef event = CGEventCreate(NULL);
  CGEventFlags mods = CGEventGetFlags(event);
  isAltPressed = ((mods & kCGEventFlagMaskAlternate) != 0);
  if (event) CFRelease(event);
  if (!isAltPressed)*/
  [super draggingUpdated:sender];
  return result;
}
//end draggingUpdated:

-(BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard* pboard = [sender draggingPasteboard];
  NSString* type = nil;
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])
  {
    NSColor* color = [NSColor colorWithData:[pboard dataForType:NSColorPboardType]];
    NSColor* rgbColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    [self insertText:[NSString stringWithFormat:@"\\color[rgb]{%f,%f,%f}", 
                       [rgbColor redComponent], [rgbColor greenComponent], [rgbColor blueComponent]]];
  }
  else if ((type = [pboard availableTypeFromArray:
        [NSArray arrayWithObjects:LibraryItemsWrappedPboardType, LibraryItemsArchivedPboardType, LatexitEquationsPboardType, NSPDFPboardType, nil]]))
  {
    LatexitEquation* equation = nil;
    if ([type isEqualToString:LibraryItemsWrappedPboardType])
    {
      NSArray* libraryItemsWrappedArray = [pboard propertyListForType:type];
      unsigned int count = [libraryItemsWrappedArray count];
      while(count-- && !equation)
      {
        NSString* objectIDAsString = [libraryItemsWrappedArray objectAtIndex:count];
        NSManagedObject* libraryItem = [[[LibraryManager sharedManager] managedObjectContext] managedObjectForURIRepresentation:[NSURL URLWithString:objectIDAsString]];
        LibraryEquation* libraryEquation =
          ![libraryItem isKindOfClass:[LibraryEquation class]] ? nil : (LibraryEquation*)libraryItem;
        equation = [libraryEquation equation];
      }//end while(count-- && !equation)
    }//end if ([type isEqualToString:LibraryItemsWrappedPboardType])
    else if ([type isEqualToString:LibraryItemsArchivedPboardType])
    {
      NSArray* libraryItemsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
      unsigned int count = [libraryItemsArray count];
      while(count-- && !equation)
      {
        LibraryEquation* libraryEquation =
          [[libraryItemsArray objectAtIndex:count] isKindOfClass:[LibraryEquation class]] ? [libraryItemsArray objectAtIndex:count] : nil;
        equation = [libraryEquation equation];
      }
    }//end if ([type isEqualToString:LibraryItemsArchivedPboardType])
    else if ([type isEqualToString:LatexitEquationsPboardType])
    {
      NSArray* latexitEquationsArray = [NSKeyedUnarchiver unarchiveObjectWithData:[pboard dataForType:type]];
      equation = [latexitEquationsArray lastObject];
    }//end if ([type isEqualToString:LatexitEquationsPboardType])
    NSAttributedString* sourceText = [equation sourceText];
    if (sourceText && ![[sourceText string] isEqualToString:@""])
      [self insertTextAtMousePosition:sourceText];
  }//end if ([type isEqualToString:LibraryItemsWrappedPboardType])
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.apple.flat-rtfd", NSRTFDPboardType, nil]]))
  {
    NSData* rtfdData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    NSData* pdfWrapperData = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    [attributedString release];
    if (pdfWrapperData)
      [(id)[self nextResponder] performDragOperation:sender];
    else
      [super performDragOperation:sender];
  }//end if ([pboard availableTypeFromArray:[NSArray arrayWithObject:@"com.apple.flat-rtfd", NSRTFDPboardType, nil]])
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFPboardType, nil]]))
  {
    NSData* rtfData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSMutableAttributedString* attributedString = [[NSMutableAttributedString alloc] initWithRTF:rtfData documentAttributes:&docAttributes];
    [attributedString setAttributes:nil range:NSMakeRange(0, [attributedString length])];
    if (attributedString)
      [self insertTextAtMousePosition:attributedString];
    else
      [super performDragOperation:sender];
    [attributedString release];
  }//end if ([pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFPboardType, nil]])
  
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]))
  {
    NSString* lastFilePath = [[pboard propertyListForType:NSFilenamesPboardType] lastObject];
    CFStringRef uti = !lastFilePath ? NULL :
                         UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension,
                                                               (CFStringRef)[lastFilePath pathExtension], 
                                                               NULL);
    BOOL isPdf = UTTypeConformsTo(uti, CFSTR("com.adobe.pdf"));
    NSAttributedString* equationSourceAttributedString = nil;
    if (isPdf)
    {
      NSData* pdfContent = [NSData dataWithContentsOfFile:lastFilePath];
      if (!CGPDFDocumentPossibleFromData(pdfContent))
        pdfContent = nil;
      LatexitEquation* latexitEquation = !pdfContent ? nil :
        [[[LatexitEquation alloc] initWithPDFData:pdfContent useDefaults:NO] autorelease];
      equationSourceAttributedString = latexitEquation ? [latexitEquation sourceText] :
        [[[NSAttributedString alloc] initWithString:CGPDFDocumentCreateStringRepresentationFromData(pdfContent)] autorelease];
    }//end if (utiPdf)

    BOOL isRtf = !isPdf && !equationSourceAttributedString && UTTypeConformsTo(uti, CFSTR("public.rtf"));
    NSAttributedString* rtfContent = !isRtf ? nil :
      [[[NSAttributedString alloc] initWithRTF:[NSData dataWithContentsOfFile:lastFilePath]
                           documentAttributes:nil] autorelease];

    BOOL isText = !isPdf && !equationSourceAttributedString && !isRtf && !rtfContent && UTTypeConformsTo(uti, CFSTR("public.plain-text"));
    NSStringEncoding encoding = NSUTF8StringEncoding;
    NSError* error = nil;
    NSString* plainTextContent = !isText ? nil :
      [NSString stringWithContentsOfFile:lastFilePath guessEncoding:&encoding error:&error];
      
    if (equationSourceAttributedString)
      [self insertText:equationSourceAttributedString];
    else if (rtfContent)
      [self insertText:rtfContent];
    else if (plainTextContent)
      [self insertText:plainTextContent];
    
    if (uti) CFRelease(uti);
  }//end if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
  else
    [super performDragOperation:sender];
  return YES;
}
//end performDragOperation:

-(IBAction) paste:(id)sender
{
  //if this view is the first responder, it may allow pasting rich LaTeXiT data, but delegates that elsewhere
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];

  NSString* type = nil;
  BOOL done = NO;
  
  if ((type = [pasteboard availableTypeFromArray:
                [NSArray arrayWithObjects:LibraryItemsWrappedPboardType, LibraryItemsArchivedPboardType, LatexitEquationsPboardType, nil]]))
  {
    //do nothing, pass to next responder
  }//end LibraryItemsWrappedPboardType, LibraryItemsArchivedPboardType, LatexitEquationsPboardType
  
  if (!done && (type = [pasteboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.adobe.pdf", nil]]))
  {
    NSData* pdfData = [pasteboard dataForType:type];
    //[pdfData writeToFile:[NSString stringWithFormat:@"%@/Desktop/toto.pdf", NSHomeDirectory()] atomically:YES];
    LatexitEquation* latexitEquation = [[[LatexitEquation alloc] initWithPDFData:pdfData useDefaults:NO] autorelease];
    if (latexitEquation)
    {
      [(id)[self nextResponder] paste:sender];
      done = YES;
    }//end if (latexitEquation)
  }//end @"com.adobe.pdf"

  if (!done && (type = [pasteboard availableTypeFromArray:[NSArray arrayWithObjects:NSPDFPboardType, nil]]))
  {
    NSData* pdfData = [pasteboard dataForType:type];
    //[pdfData writeToFile:[NSString stringWithFormat:@"%@/Desktop/tmp.pdf", NSHomeDirectory()] atomically:YES];
    LatexitEquation* latexitEquation = [[[LatexitEquation alloc] initWithPDFData:pdfData useDefaults:NO] autorelease];
    if (latexitEquation)
    {
      [(id)[self nextResponder] paste:sender];
      done = YES;
    }//end if (latexitEquation)
  }//end NSPDFPboardType

  /*if (!done && (type = [pasteboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.apple.iWork.TSPNativeMetadata", nil]]))
  {
    [(id)[self nextResponder] paste:sender];
    done = YES;
  }//end @"com.apple.iWork.TSPNativeMetadata"*/

  if (!done && (type = [pasteboard availableTypeFromArray:[NSArray arrayWithObjects:NSFilesPromisePboardType, nil]]))
  {
    [(id)[self nextResponder] paste:sender];
    done = YES;
  }//end NSFilesPromisePboardType
  
  if (!done && ((type = [pasteboard availableTypeFromArray:[NSArray arrayWithObjects:@"com.apple.flat-rtfd", NSRTFDPboardType, nil]])))
  {
    NSData* rtfdData = [pasteboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    NSData* pdfWrapperData = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    [attributedString release];
    LatexitEquation* latexitEquation = !pdfWrapperData ? nil : [[[LatexitEquation alloc] initWithPDFData:pdfWrapperData useDefaults:NO] autorelease];
    if (latexitEquation)
    {
      [(id)[self nextResponder] paste:sender];
      done = YES;
    }
    else if (pdfWrapperData)
    {
      NSString* pdfString = CGPDFDocumentCreateStringRepresentationFromData(pdfWrapperData);
      if (pdfString)
        [self insertText:pdfString];
      done = YES;
    }
    else
    {
        NSMutableAttributedString* attributedString = [[NSMutableAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
      [attributedString setAttributes:nil range:NSMakeRange(0, [attributedString length])];
      if (attributedString)
        [self insertText:attributedString];
      [attributedString release];
      //[super paste:sender];
      done = YES;
    }
  }//end @"com.apple.flat-rtfd"

  if (!done && ((type = [pasteboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFPboardType, nil]])))
  {
    NSData* rtfData = [pasteboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSMutableAttributedString* attributedString = [[NSMutableAttributedString alloc] initWithRTF:rtfData documentAttributes:&docAttributes];
    [attributedString setAttributes:nil range:NSMakeRange(0, [attributedString length])];
    if (attributedString)
      [self insertText:attributedString];
    //[super paste:sender];
    done = YES;
  }//end @"NSRTFPboardType"
  
  /*
  #error DEBUG
  if (!done)//check totally empirically
  {
    NSSet* typesAlreadyDone = [NSSet setWithObjects:
      LibraryItemsWrappedPboardType, LibraryItemsArchivedPboardType, LatexitEquationsPboardType,
      @"com.adobe.pdf", NSPDFPboardType,
      @"com.apple.flat-rtfd", NSRTFDPboardType, nil];
    NSEnumerator* enumerator = [[pasteboard types] objectEnumerator];
    while((type = [enumerator nextObject]))
    {
      if (![typesAlreadyDone containsObject:type])
      {
        NSData* maybePDFData = [pasteboard dataForType:type];
        [maybePDFData writeToFile:@"/Users/chacha/Desktop/dada.dat" atomically:NO];
        LatexitEquation* latexitEquation = [[[LatexitEquation alloc] initWithPDFData:maybePDFData useDefaults:NO] autorelease];
        if (latexitEquation)
        {
          [(id)[self nextResponder] paste:sender];
          done = YES;
        }//end if (latexitEquation)
      }//end if (![typesAlreadyDone containsObject:type])
    }//end for each type
  }//end if (!done)
  */

  if (!done)
    [super paste:sender];

  NSFont* currentFont = [[self typingAttributes] objectForKey:NSFontAttributeName];
  currentFont = [[PreferencesController sharedController] editionFont];
  if (currentFont)
  {
    NSRange range = NSMakeRange(0, [[self textStorage] length]);
    [self setFont:currentFont range:range];
    //[self setAlignment:NSLeftTextAlignment range:range];
  }//end if (currentFont)
}
//end paste:

-(BOOL) validateMenuItem:(id)sender
{
  BOOL ok = YES;
  if ([sender action] == @selector(copy:))
    return [super validateMenuItem:sender];
  else if ([sender action] == @selector(paste:))
    return YES;
  return ok;
}
//end validateMenuItem:

-(BOOL) resignFirstResponder
{
  BOOL result = NO;
  self->previousSelectedRangeLocation = [self selectedRange].location;
  result = [super resignFirstResponder];
  return result;
}
//end resignFirstResponder

-(void) restorePreviousSelectedRangeLocation
{
  NSRange currentTextRange = NSMakeRange(0, [[[self textStorage] string] length]);
  if (self->previousSelectedRangeLocation <= currentTextRange.length)
    [self setSelectedRange:NSMakeRange(self->previousSelectedRangeLocation, 0)];
}
//end restorePreviousSelectedRangeLocation

-(void) keyDown:(NSEvent*)theEvent
{
  BOOL isSmallReturn = NO;
  NSString* charactersIgnoringModifiers = [theEvent charactersIgnoringModifiers];
  if (![charactersIgnoringModifiers isEqualToString:@""])
  {
    unichar character = [charactersIgnoringModifiers characterAtIndex:0];
    isSmallReturn = (character == 3);//return key
  }
  if (!isSmallReturn)
  {
    NSString* characters = [theEvent characters];
    NSArray* textShortcuts = [[PreferencesController  sharedController] editionTextShortcuts];
    NSEnumerator* enumerator = [textShortcuts objectEnumerator];
    NSDictionary* dict = nil;
    NSDictionary* textShortcut = nil;
    while(!textShortcut && (dict = [enumerator nextObject]))
    {
      if ([[dict objectForKey:@"input"] isEqualToString:characters] && [[dict objectForKey:@"enabled"] boolValue])
        textShortcut = dict;
    }
    if (!textShortcut)
      [super keyDown:theEvent];
    else
    {
      if (![[theEvent charactersIgnoringModifiers] isEqualToString:characters])
        [self deleteBackward:self];
      NSRange range = [self selectedRange];
      NSString* left = [textShortcut objectForKey:@"left"];
      NSString* right = [textShortcut objectForKey:@"right"];
      if (!left)  left  = @"";
      if (!right) right = @"";
      if (range.location == NSNotFound)
        [self insertText:[left stringByAppendingString:right]];
      else
      {
        NSString* selectedText = [[self string] substringWithRange:range];
        [self replaceCharactersInRange:range withString:[NSString stringWithFormat:@"%@%@%@",left,selectedText,right]];
        [self setSelectedRange:NSMakeRange(range.location+[left length]+range.length, 0)];
      }
    }
  }
  else
    [[(MyDocument*)[AppController currentDocument] lowerBoxLatexizeButton] performClick:self];
}
//end keyDown:

//method taken from Smultron
//it allows parenthesis detection for user friendly selection
-(NSRange) selectionRangeForProposedRange:(NSRange)proposedSelRange granularity:(NSSelectionGranularity)granularity
{
	if (granularity != NSSelectByWord || [[self string] length] == proposedSelRange.location)// If it's not a double-click return unchanged
		return [super selectionRangeForProposedRange:proposedSelRange granularity:granularity];
	
	unsigned int location = [super selectionRangeForProposedRange:proposedSelRange granularity:NSSelectByCharacter].location;
	unsigned int originalLocation = location;

	NSString *completeString = [self string];
	unichar characterToCheck = [completeString characterAtIndex:location];
	unsigned short skipMatchingBrace = 0;
	unsigned int lengthOfString = [completeString length];
	if (lengthOfString == proposedSelRange.location) // to avoid crash if a double-click occurs after any text
		return [super selectionRangeForProposedRange:proposedSelRange granularity:granularity];
	
	BOOL triedToMatchBrace = NO;
  static const unichar parenthesis[3][2] = {{'(', ')'}, {'[', ']'}, {'$', '$'}};
  int parenthesisIndex = 0;
  for(parenthesisIndex = 0 ;
      (parenthesisIndex<3) && (characterToCheck != parenthesis[parenthesisIndex][1]) ;
      ++parenthesisIndex);
	
  //detect if characterToCheck is a closing brace, and find the opening brace
	if (parenthesisIndex < 3)
  {
		triedToMatchBrace = YES;
		while (location--)
    {
			characterToCheck = [completeString characterAtIndex:location];
			if (characterToCheck == parenthesis[parenthesisIndex][0])
      {
				if (!skipMatchingBrace)
					return NSMakeRange(location, originalLocation - location + 1);
				else
					--skipMatchingBrace;
			}
      else if (characterToCheck == parenthesis[parenthesisIndex][1])
        ++skipMatchingBrace;
		}
		NSBeep();
	}

	// If it has a found a "starting" brace but not found a match, a double-click should only select the "starting" brace and not what it usually would select at a double-click
	if (triedToMatchBrace)
		return [super selectionRangeForProposedRange:NSMakeRange(proposedSelRange.location, 1) granularity:NSSelectByCharacter];
	else
		return [super selectionRangeForProposedRange:proposedSelRange granularity:granularity];
}
//end selectionRangeForProposedRange:granularity:

-(SMLSyntaxColouring*) syntaxColouring
{
  return syntaxColouring;
}
//end syntaxColouring

-(NSRange) rangeForUserCompletion
{
  NSRange range = [super rangeForUserCompletion];
  BOOL canExtendRange = (range.location != 0) && (range.location != NSNotFound) && (range.length+1 != NSNotFound);
  NSRange extendedRange = canExtendRange ? NSMakeRange(range.location-1, range.length+1) : range;
  NSString* extendedWord = [[self string] substringWithRange:extendedRange];
  BOOL isBackslashedWord = ([extendedWord length] && [extendedWord characterAtIndex:0] == '\\');
  return isBackslashedWord ? extendedRange : range;
}
//end rangeForUserCompletion

-(NSArray*) completionsForPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger*)index
{
  //first, normal system calling [super completionsForPartialWordRange:...]
  NSMutableArray* propositions =
    [NSMutableArray arrayWithArray:[super completionsForPartialWordRange:charRange indexOfSelectedItem:index]];

  //then, check the LaTeX dictionary (will work for a backslashed word)    
  NSString* text = [self string];
  NSString* word = [text substringWithRange:charRange];
  BOOL isBackslashedWord = ([word length] && [word characterAtIndex:0] == '\\');
  NSMutableArray* newPropositions = [NSMutableArray array];

  if (isBackslashedWord)
  {
    NSMutableArray* keywordsToCheck = [NSMutableArray array];
    unsigned int nbPackages = WellKnownLatexKeywords ? [WellKnownLatexKeywords count] : 0;
    while(nbPackages--)
    {
      NSDictionary* package = [WellKnownLatexKeywords objectAtIndex:nbPackages];
      //NSString*     packageName = [package objectForKey:@"name"];
      //if ([text rangeOfString:packageName options:NSCaseInsensitiveSearch].location != NSNotFound)
        [keywordsToCheck addObjectsFromArray:[package objectForKey:@"keywords"]];
    }
  
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"word BEGINSWITH %@", word];
    [newPropositions setArray:[keywordsToCheck filteredArrayUsingPredicate:predicate]];
    
    unsigned int nbPropositions = [newPropositions count];
    while(nbPropositions--)
    {
      NSDictionary* typeAndKeyword = [newPropositions objectAtIndex:nbPropositions];
      NSString* type    = [typeAndKeyword objectForKey:@"type"];
      NSString* keyword = [typeAndKeyword objectForKey:@"word"];
      if ([type isEqualToString:@"normal"])
        [propositions addObject:keyword];
      else if ([type isEqualToString:@"braces"])
        [propositions addObject:[keyword stringByAppendingString:@"{}"]];
      else if ([type isEqualToString:@"braces2"])
        [propositions addObject:[keyword stringByAppendingString:@"{}{}"]];
    }
  }
  
  //if no proposition is found, do as if the backslash was not there
  if (isBackslashedWord && ![propositions count])
  {
    NSRange reducedRange = NSMakeRange(charRange.location+1, charRange.length-1);
    [newPropositions setArray:[super completionsForPartialWordRange:reducedRange indexOfSelectedItem:index]];
    //add the missing backslashes
    unsigned int count = [newPropositions count];
    while(count--)
    {
      NSString* proposition = [newPropositions objectAtIndex:count];
      [newPropositions replaceObjectAtIndex:count withObject:[NSString stringWithFormat:@"\\%@", proposition]];
    }
    [propositions setArray:newPropositions];
  }
  
  if (!isBackslashedWord) //try a latex environment and add normal completions
  {
    NSMutableArray* keywordsToCheck = [NSMutableArray array];
    unsigned int nbPackages = WellKnownLatexKeywords ? [WellKnownLatexKeywords count] : 0;
    while(nbPackages--)
    {
      NSDictionary* package = [WellKnownLatexKeywords objectAtIndex:nbPackages];
      //NSString*     packageName = [package objectForKey:@"name"];
      //if ([text rangeOfString:packageName options:NSCaseInsensitiveSearch].location != NSNotFound)
        [keywordsToCheck addObjectsFromArray:[package objectForKey:@"keywords"]];
    }
  
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"word BEGINSWITH %@", word];
    [newPropositions setArray:[keywordsToCheck filteredArrayUsingPredicate:predicate]];
    
    unsigned int nbPropositions = [newPropositions count];
    while(nbPropositions--)
    {
      NSDictionary* typeAndKeyword = [newPropositions objectAtIndex:nbPropositions];
      NSString* type    = [typeAndKeyword objectForKey:@"type"];
      NSString* keyword = [typeAndKeyword objectForKey:@"word"];
      if ([type isEqualToString:@"environment"])
        [propositions addObject:keyword];
    }
  }
  
  [propositions sortUsingSelector:@selector(caseInsensitiveCompare:)];
  
  return propositions;
}
//end completionsForPartialWordRange:indexOfSelectedItem;

-(void) changeColor:(id)sender
{
  //overwritten to do nothing (only black fonr is expected)
}
//end changeColor:

-(void) colorDidChange:(NSNotification*)notification
{
  NSColor* color = [[NSColorPanel sharedColorPanel] color];
  NSRange selectedRange = !color ? NSMakeRange(0, 0) : [self selectedRange];
  NSString* input = !selectedRange.length ? nil : [[[self textStorage] string] substringWithRange:selectedRange];
  NSString* output = nil;
  if (input)
  {
    NSColor* rgbColor = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    NSString* replacement = [NSString stringWithFormat:@"{\\\\color[rgb]{%f,%f,%f}$1}",
      [rgbColor redComponent], [rgbColor greenComponent], [rgbColor blueComponent]];
    BOOL isMatching = ([input stringByMatching:@"^\\{\\\\color\\[rgb\\]\\{[^\\}]*\\}(.*)\\}$" options:RKLMultiline
                                       inRange:NSMakeRange(0, [input length]) capture:1 error:nil] != nil);
    if (replacement)
      output = !isMatching ? nil :
        [input stringByReplacingOccurrencesOfRegex:@"^\\{\\\\color\\[rgb\\]\\{[^\\}]*\\}(.*)\\}$" withString:replacement
                                           options:RKLMultiline range:NSMakeRange(0, [input length]) error:nil];
    if (!output)
      output = [NSString stringWithFormat:@"{\\color[rgb]{%f,%f,%f}%@}",
                     [rgbColor redComponent], [rgbColor greenComponent], [rgbColor blueComponent], input];
    if (output)
      [self replaceCharactersInRange:selectedRange withString:output withUndo:YES];
  }//end if (input)
}
//end colorDidChange:

-(void) replaceCharactersInRange:(NSRange)range withString:(NSString*)string withUndo:(BOOL)withUndo
{
  NSString* input = !range.length ? nil : [[[self textStorage] string] substringWithRange:range];
  if (input && string)
  {
    NSRange newRange = NSMakeRange(range.location, [string length]);
    if (withUndo)
      [[[self undoManager] prepareWithInvocationTarget:self] replaceCharactersInRange:newRange withString:input withUndo:withUndo];
    [self replaceCharactersInRange:range withString:string];
    [self setSelectedRange:newRange];
  }//end if (input && string)
}
//end replaceCharactersInRange:withString:withUndo:

-(void) insertTextAtMousePosition:(id)object
{
  unsigned int index = [self characterIndexForPoint:[NSEvent mouseLocation]];
  unsigned int length = [[self textStorage] length];
  if (index <= length)
  {
    NSDictionary* attributes =
      [NSDictionary dictionaryWithObjectsAndKeys:
        [[PreferencesController sharedController] editionFont], NSFontAttributeName,
        nil];
    NSMutableAttributedString* attributedString =
      [object isKindOfClass:[NSAttributedString class]] ? [[object mutableCopy] autorelease] :
      [[[NSMutableAttributedString alloc] initWithString:object] autorelease];
    [attributedString addAttributes:attributes range:NSMakeRange(0, [attributedString length])];
    [[self textStorage] insertAttributedString:attributedString atIndex:index];
    [self->syntaxColouring recolourCompleteDocument];
  }//end if (index <= length)
}
//end insertTextAtMousePosition:

@end
