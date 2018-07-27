//  LibraryCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.

//The LibraryCell is the kind of cell displayed in the NSOutlineView of the Library drawer
//It contains an image and a text. It is a copy of the ImageAndTextCell provided by Apple
//in the developer documentation

#import "LibraryCell.h"
#import "LibraryTableView.h"

@implementation LibraryCell

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  backgroundColor = nil;//there may be no color
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [image release];
  image = nil;
  [super dealloc];
}
//end dealloc

-(id) copyWithZone:(NSZone*)zone
{
  LibraryCell* cell = (LibraryCell*) [super copyWithZone:zone];
  if (cell)
  {
    cell->image = [image retain];
    cell->backgroundColor = [backgroundColor copy];
  }
  return cell;
}
//end copyWithZone:

-(void) setBackgroundColor:(NSColor*)color
{
  [color retain];
  [backgroundColor release];
  backgroundColor = color;
}
//end setBackgroundColor:

-(NSColor*) backgroundColor
{
  return backgroundColor;
}
//end backgroundColor

-(void) setImage:(NSImage*)anImage
{
  [anImage retain];
  [image release];
  image = anImage;
}
//end setImage:

-(NSImage*) image
{
  return image;
}
//end image

-(NSRect) imageFrameForCellFrame:(NSRect)cellFrame
{
  NSRect rect = NSZeroRect;
  if (image)
  {
    rect.size = [image size];
    rect.origin = cellFrame.origin;
    rect.origin.x += 3;
    rect.origin.y += ceil((cellFrame.size.height - rect.size.height) / 2);
  }
  return rect;
}
//end imageFrameForCellFrame:

-(void) editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent
{
  LibraryTableView* libraryTableView = (LibraryTableView*)controlView;
  library_row_t libraryRowType = [libraryTableView libraryRowType];
  if ((libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT)
       #ifndef PANTHER
       || (aRect.size.height < 30)
       #endif
     )
  {
    NSRect textFrame  = NSZeroRect;
    NSRect imageFrame = NSZeroRect;
    NSDivideRect(aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
    [super editWithFrame:textFrame inView:controlView editor:textObj delegate:anObject event: theEvent];
  }
}
//end editWithFrame:inView:editor:delegate:event:

-(void) selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(int)selStart length:(int)selLength
{
  LibraryTableView* libraryTableView = (LibraryTableView*)controlView;
  library_row_t libraryRowType = [libraryTableView libraryRowType];
  if ((libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT)
        #ifndef PANTHER
        || (aRect.size.height < 30)
        #endif
       )
  {
    NSRect textFrame  = NSZeroRect;
    NSRect imageFrame = NSZeroRect;
    NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
    [super selectWithFrame:textFrame inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
  }
}
//end selectWithFrame:inView:editor:delegate:start:length

-(void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  NSString* savTitle = [[self title] retain];//if displaying only image, we will temporarily reset the title
  if (image)
  {
    NSSize imageSize = [image size];
    NSRect imageFrame = NSZeroRect;
    
    LibraryTableView* libraryTableView = (LibraryTableView*)controlView;
    library_row_t libraryRowType = [libraryTableView libraryRowType];
    if ((libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT)
        #ifndef PANTHER
        || (cellFrame.size.height < 30)
        #endif
       )
      NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
    else// if (libraryRowType == LIBRARY_ROW_IMAGE_LARGE)
    {
      imageFrame = NSMakeRect(0, 0, imageSize.width, imageSize.height);
      float factor = imageSize.height ? cellFrame.size.height/imageSize.height : 0;
      cellFrame.size.width = imageSize.width*factor;
    }

    if ([self drawsBackground] && !(libraryRowType == LIBRARY_ROW_IMAGE_LARGE))
    {
      [[super backgroundColor] set];//calls super backgroundColor to get the original background color
      NSRectFill(imageFrame);
    }

    if ((libraryRowType == LIBRARY_ROW_IMAGE_LARGE) && [self backgroundColor] && [self drawsBackground])
    {
      [[self backgroundColor] set];
      NSRectFill(cellFrame);
    }

    
    if ((libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT)
        #ifndef PANTHER
        || (cellFrame.size.height < 30)
        #endif
       )
    {
      imageFrame.origin.x += 3;
      imageFrame.size = imageSize;
      if ([controlView isFlipped])
	imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
      else
	imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
      [image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
    }
    else// if (libraryRowType == LIBRARY_ROW_IMAGE_LARGE)
    {
      [self setTitle:@""];
      NSSize savSize = imageFrame.size;
      [image setScalesWhenResized:YES];
      [image setSize:cellFrame.size];
      imageFrame = cellFrame;
      if ([controlView isFlipped])
	imageFrame.origin.y += ceil((cellFrame.size.height + imageFrame.size.height) / 2);
      else
	imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
      [image compositeToPoint:imageFrame.origin operation:NSCompositeSourceOver];
      [image setSize:savSize];
    }
  }
  [super drawWithFrame:cellFrame inView:controlView];
  
  //restores the title that may have been reset
  [self setTitle:savTitle];
  [savTitle release];
}
//end drawWithFrame:inView:

-(NSSize) cellSize
{
  NSSize cellSize = [super cellSize];
  cellSize.width += (image ? [image size].width : 0) + 3;
  return cellSize;
}
//end cellSize

-(void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  LibraryTableView* libraryTableView = (LibraryTableView*)controlView;
  library_row_t libraryRowType = [libraryTableView libraryRowType];
  if ((libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT)
      #ifndef PANTHER
      || (cellFrame.size.height < 30)
      #endif
     )
  {
    cellFrame.origin.x += 8;
    [super drawInteriorWithFrame:cellFrame inView:controlView];
  }
}
//end drawInteriorWithFrame:inView:

@end
