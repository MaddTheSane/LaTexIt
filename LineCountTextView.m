//  LineCountTextView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The LineCountTextView is an NSTextView that I have associated with a LineCountRulerView
//This ruler will display the line numbers
//Another feature is the ability to disable the edition of some lines
//Another feature is the ability to add error markers at some lines

#import "LineCountTextView.h"

#import "HistoryManager.h"
#import "LibraryManager.h"
#import "LineCountRulerView.h"
#import "MyDocument.h"
#import "NSColorExtended.h"
#import "SMLSyntaxColouring.h"

NSString* LineCountDidChangeNotification = @"LineCountDidChangeNotification";
NSString* FontDidChangeNotification      = @"FontDidChangeNotification";

@interface LineCountTextView (PrivateAPI)
-(void) _computeLineRanges;
@end

@implementation LineCountTextView

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  lineRanges = [[NSMutableArray alloc] init];
  forbiddenLines = [[NSMutableSet alloc] init];
  [self setDelegate:self];
  #ifdef PANTHER
  NSArray* registeredDraggedTypes = [NSArray array];    
  #else
  NSArray* registeredDraggedTypes = [self registeredDraggedTypes];
  #endif
  
  [self registerForDraggedTypes:[registeredDraggedTypes arrayByAddingObject:NSColorPboardType]];
  return self;
}

-(void) awakeFromNib
{
  NSScrollView* scrollView = (NSScrollView*) [[self superview] superview];
  [self setRulerVisible:YES];
  [scrollView setHasHorizontalRuler:NO];
  [scrollView setHasVerticalRuler:YES];
  lineCountRulerView = [[LineCountRulerView alloc] initWithScrollView:scrollView orientation:NSVerticalRuler];
  [scrollView setVerticalRulerView:lineCountRulerView];
  [lineCountRulerView setClientView:self];
  syntaxColouring = [[SMLSyntaxColouring alloc] initWithTextView:self];
}

-(void) dealloc
{
  [syntaxColouring release];
  [lineRanges release];
  [forbiddenLines release];
  [lineCountRulerView release];
  [super dealloc];
}

//as its own delegate, only notifications from self are seen
-(void) textDidChange:(NSNotification*)aNotification
{
  [self _computeLineRanges]; //line ranges are computed at each change. It is not very efficient and will be very slow
                             //for large texts, but in LaTeXiT, texts are small, and I did not know how to do that simply otherwise

  //normal lines are displayed in black
  NSDictionary* normalAttributes =
    [NSDictionary dictionaryWithObjectsAndKeys:[NSColor blackColor], NSForegroundColorAttributeName, nil];
  [[self textStorage] addAttributes:normalAttributes range:NSMakeRange(0, [[self textStorage] length])];

  //forbidden lines are displayed in gray
  NSDictionary* forbiddenAttributes =
    [NSDictionary dictionaryWithObjectsAndKeys:[NSColor colorWithCalibratedRed:0.7 green:0.7 blue:0.7 alpha:1],
                                               NSForegroundColorAttributeName, nil];
  
  //updates text attributes to set the color
  NSEnumerator* enumerator = [forbiddenLines objectEnumerator];
  NSNumber*    numberIndex = [enumerator nextObject];
  while(numberIndex)
  {
    unsigned int index = [numberIndex intValue];
    if (index < [lineRanges count])
      [[self textStorage] addAttributes:forbiddenAttributes range:NSRangeFromString([lineRanges objectAtIndex:index])];
    numberIndex = [enumerator nextObject];
  }

  //line count
  [[NSNotificationCenter defaultCenter] postNotificationName:LineCountDidChangeNotification object:self];
  [syntaxColouring textDidChange:aNotification];
}

-(NSArray*) lineRanges
{
  return lineRanges;
}

-(unsigned int) nbLines
{
  return lineRanges ? [lineRanges count] : 0;
}

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

//remove error markers
-(void) clearErrors
{
  [lineCountRulerView clearErrors];
}

//add error markers
-(void) setErrorAtLine:(unsigned int)lineIndex message:(NSString*)message
{
  [lineCountRulerView setErrorAtLine:lineIndex message:message];
}

//change the shift in displayed numerotation
-(void) setLineShift:(int)aShift
{
  lineShift = aShift;
  [lineCountRulerView setLineShift:aShift];
}

//the shift in displayed numerotation
-(int) lineShift
{
  return lineShift;
}

//change the status (forbidden or not) of a line (forbidden means : cannot be edited)
-(void) setForbiddenLine:(unsigned int)index forbidden:(BOOL)forbidden
{
  if (forbidden)
    [forbiddenLines addObject:[NSNumber numberWithUnsignedInt:index]];
  else
    [forbiddenLines removeObject:[NSNumber numberWithUnsignedInt:index]];
}

//checks if the user is typing in a forbiddenLine; if it is the case, it is discarded
-(BOOL) textView:(NSTextView *)aTextView shouldChangeTextInRange:(NSRange)affectedCharRange
                                               replacementString:(NSString *)replacementString
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

-(void)rulerView:(NSRulerView *)aRulerView handleMouseDown:(NSEvent *)theEvent
{
  //does nothing but prevents console message error
}

-(BOOL) rulerView:(NSRulerView *)aRulerView shouldAddMarker:(NSRulerMarker *)aMarker
{
  return NO;
}

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

//responds to the font manager
-(void) changeFont:(id)sender
{
  NSRange range   = [self selectedRange];
  NSFont* oldFont = [self font];
  NSFont* newFont = [sender convertFont:oldFont];
  if (!range.length)
    [self setTypingAttributes:[NSDictionary dictionaryWithObject:newFont forKey:NSFontAttributeName]];
  else
    [self setFont:newFont range:range];
  [lineCountRulerView setNeedsDisplay:YES];
  [[NSNotificationCenter defaultCenter] postNotificationName:FontDidChangeNotification object:self];
}

//We can drop on the imageView only if the PDF has been made by LaTeXiT (as "creator" document attribute)
//So, the keywords of the PDF contain the whole document state
-(NSDragOperation) draggingEntered:(id <NSDraggingInfo>)sender
{
  NSDragOperation dragOperation = NSDragOperationNone;
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])
    dragOperation = NSDragOperationCopy;
  return dragOperation;
}

-(BOOL) performDragOperation:(id <NSDraggingInfo>)sender
{
  NSPasteboard* pboard = [sender draggingPasteboard];
  if ([pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]])
    [self setBackgroundColor:[NSColor colorWithData:[pboard dataForType:NSColorPboardType]]];
  return YES;
}

-(IBAction) paste:(id)sender
{
  //if this view is the first responder, it may allow pasting rich LaTeXiT data, but delegates that elsewhere
  if ([[NSPasteboard generalPasteboard] availableTypeFromArray:
        [NSArray arrayWithObjects:LibraryItemsPboardType, HistoryItemsPboardType, NSPDFPboardType, nil]])
    [(id)[self nextResponder] paste:sender];
  else
    [super paste:sender];
}

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
    [super keyDown:theEvent];
  else
    [[(MyDocument*)[[NSDocumentController sharedDocumentController] currentDocument] makeLatexButton] performClick:self];
}

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

-(SMLSyntaxColouring*) syntaxColouring
{
  return syntaxColouring;
}

@end
