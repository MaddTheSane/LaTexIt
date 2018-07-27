//  HistoryCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/03/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.

//This class is the kind of cell used to display history items in the history drawer
//It may take in account the different fields of an history item (image, date...)

#import "HistoryCell.h"

@implementation HistoryCell

-(id) initWithCoder:(NSCoder*)coder
{
  self = [super initWithCoder:coder];
  if (self)
  {
    dateFormatter = [[NSDateFormatter alloc] initWithDateFormat:@"%a %d %b %Y, %H:%M:%S" allowNaturalLanguage:YES];
    backgroundColor = nil;//there may be no color
  }
  return self;
}

-(void) dealloc
{
  [dateFormatter release];
  [super dealloc];
}

-(void) setBackgroundColor:(NSColor*)color
{
  [color retain];
  [backgroundColor release];
  backgroundColor = color;
}

-(id) copyWithZone:(NSZone*)zone
{
  HistoryCell* cell = (HistoryCell*) [super copyWithZone:zone];
  if (cell)
  {
    cell->dateFormatter = [dateFormatter retain];
    cell->backgroundColor = [backgroundColor copy];
  }
  return cell;
}

-(void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  if (backgroundColor)
  {
    [backgroundColor set];
    NSRectFill(cellFrame);
  }
  const float margin   = 14; //the margin above to put the date into
  const float sepThick = 1;  //thickness of the separator between the date and the image
  NSRect imageRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y+margin+sepThick,
                                cellFrame.size.width, cellFrame.size.height-margin-sepThick);
  [super drawInteriorWithFrame:imageRect inView:controlView]; //the image is displayed in a subrect of the cell

  //now we add the date
  NSDate* date = [[self representedObject] date];
  NSString* dateString = [dateFormatter stringForObjectValue:date];
  NSAttributedString* attrString = [[NSAttributedString alloc] initWithString:dateString attributes:nil];
  NSSize textSize = [attrString size];
  NSRect textRect = NSMakeRect(cellFrame.origin.x+(cellFrame.size.width  - textSize.width ) / 2,
                               cellFrame.origin.y+(margin - textSize.height) / 2,
                               cellFrame.size.width, cellFrame.size.height);
  [attrString drawInRect:textRect]; //the date is displayed
  [attrString release];
  
  //the separator is displayed
  [[NSColor lightGrayColor] set];
  [NSBezierPath fillRect:NSMakeRect(0, cellFrame.origin.y+margin, cellFrame.size.width+4, sepThick)];
}

@end
