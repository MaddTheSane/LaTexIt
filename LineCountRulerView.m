//
//  LineCountRulerView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/03/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.
//

#import "LineCountRulerView.h"

#import "LineCountTextView.h"

static NSImage* errorIcon = nil;

@implementation LineCountRulerView

+(void) initialize
{
  if (!errorIcon)
  {
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* resourcePath = [mainBundle resourcePath];
    NSString* fileName = [resourcePath stringByAppendingPathComponent:@"error.tiff"];
    errorIcon = [[NSImage alloc] initWithContentsOfFile:fileName];
  }
}

-(id) initWithScrollView:(NSScrollView*)scrollView orientation:(NSRulerOrientation)orientation
{
  if (![super initWithScrollView:scrollView orientation:orientation])
    return nil;
  [self setRuleThickness:32];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:)
                                               name:LineCountDidChangeNotification object:nil];
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(void) textDidChange:(NSNotification*)aNotification
{
  if ([aNotification object] == [self clientView])
    [self setNeedsDisplay:YES];
}

//the shift allows to start the numeratation at another number than 1
-(void) setLineShift:(int)aShift
{
  lineShift = aShift;
  [self setNeedsDisplay:YES];
}

-(int) lineShift
{
  return lineShift;
}

//draws error markers and line numbers
-(void)drawHashMarksAndLabelsInRect:(NSRect)aRect
{
  NSRect visibleRect  = [(NSClipView*)[[self clientView] superview] documentVisibleRect];
  NSLayoutManager* lm = [(NSTextView*)[self clientView] layoutManager];
  NSTextContainer* tc = [(NSTextView*)[self clientView] textContainer];
  NSArray* lineRanges = [(LineCountTextView*)[self clientView] lineRanges];
  
  NSDictionary* attributes = [NSDictionary dictionaryWithObject:[NSColor grayColor] forKey:NSForegroundColorAttributeName];
  unsigned int lineNumber = 0;
  for(lineNumber = 1 ; lineNumber <= [lineRanges count] ; ++lineNumber)
  {
    NSRange lineRange = NSRangeFromString([lineRanges objectAtIndex:lineNumber-1]);
    NSRect rect = [lm boundingRectForGlyphRange:lineRange inTextContainer:tc];
    rect.size.width = MAX(rect.size.width, 1);
    if (NSIntersectsRect(rect, visibleRect))
    {
      NSString* numberString = [NSString stringWithFormat:@"%d", lineNumber+lineShift];
      NSAttributedString* attrNumberString = [[[NSAttributedString alloc] initWithString:numberString
                                                                          attributes:attributes] autorelease];
      NSPoint origin = NSMakePoint([self frame].size.width-[attrNumberString size].width-2,
                                   rect.origin.y-visibleRect.origin.y);
      [attrNumberString drawAtPoint:origin];
    }
  }
}

//adds an error marker
-(void) setErrorAtLine:(int)lineIndex message:(NSString*)message
{
  --lineIndex; //0 based-system
  lineIndex -= lineShift;
  NSArray* lineRanges = [(LineCountTextView*)[self clientView] lineRanges];
  if ((lineIndex >= 0) && ((unsigned int) lineIndex < [lineRanges count]))
  {
    NSRange lineRange = NSRangeFromString([lineRanges objectAtIndex:lineIndex]);
    NSLayoutManager* lm = [(NSTextView*)[self clientView] layoutManager];
    NSTextContainer* tc = [(NSTextView*)[self clientView] textContainer];
    NSRect rect = [lm boundingRectForGlyphRange:lineRange inTextContainer:tc];
    NSSize iconSize = [errorIcon size];
    NSRulerMarker* marker =
      [[NSRulerMarker alloc] initWithRulerView:self markerLocation:rect.origin.y image:errorIcon
                                   imageOrigin:NSMakePoint(0, iconSize.height)];
    [self addMarker:marker];
    [marker release];
    [self addToolTipRect:NSMakeRect(0,rect.origin.y, iconSize.width, iconSize.height) owner:message userData:NULL];
    [self setNeedsDisplay:YES];
  }
}

//removes error markers
-(void) clearErrors
{
  [self removeAllToolTips];
  NSArray* markers = [self markers];
  NSEnumerator* enumerator = [markers objectEnumerator];
  NSRulerMarker* marker = [enumerator nextObject];
  while(marker)
  {
    [self removeMarker:marker];
    marker = [enumerator nextObject];
  }
  [self setNeedsDisplay:YES];
}

@end
