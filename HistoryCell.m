//  HistoryCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//This class is the kind of cell used to display history items in the history drawer
//It may take in account the different fields of an history item (image, date...)

#import "HistoryCell.h"

// CoreGraphics gradient helpers
typedef struct {
  float red1, green1, blue1, alpha1;
  float red2, green2, blue2, alpha2;
} twoRgba_t;

static void _linearColorBlendFunction(void *info, const float *inData, float *outData)
{
  twoRgba_t* twoRgbaColors = (twoRgba_t*) info;
  
  outData[0] = (1.0 - *inData) * twoRgbaColors->red1   + (*inData) * twoRgbaColors->red2;
  outData[1] = (1.0 - *inData) * twoRgbaColors->green1 + (*inData) * twoRgbaColors->green2;
  outData[2] = (1.0 - *inData) * twoRgbaColors->blue1  + (*inData) * twoRgbaColors->blue2;
  outData[3] = (1.0 - *inData) * twoRgbaColors->alpha1 + (*inData) * twoRgbaColors->alpha2;
}

static void _linearColorReleaseInfoFunction(void *info)
{
  free(info);
}

static const CGFunctionCallbacks linearFunctionCallbacks = {0, &_linearColorBlendFunction, &_linearColorReleaseInfoFunction};
// end CoreGraphics gradient helpers

@interface HistoryCell (PrivateAPI)
-(void) drawGradientInRect:(NSRect)rect withColor:(NSColor*)color;
@end

@implementation HistoryCell

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  dateFormatter = [[NSDateFormatter alloc] initWithDateFormat:@"%a %d %b %Y, %H:%M:%S" allowNaturalLanguage:YES];
  backgroundColor = nil;//there may be no color
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
  NSRect headerRect = NSMakeRect(cellFrame.origin.x-1, cellFrame.origin.y-1, cellFrame.size.width+3, 16);
  NSRect imageRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y+headerRect.size.height,
                                cellFrame.size.width, cellFrame.size.height-headerRect.size.height);
  [super drawInteriorWithFrame:imageRect inView:controlView]; //the image is displayed in a subrect of the cell

  //now we add the date
  NSDate* date = [[self representedObject] date];
  NSString* dateString = [dateFormatter stringForObjectValue:date];
  NSAttributedString* attrString = [[NSAttributedString alloc] initWithString:dateString attributes:nil];
  NSSize textSize = [attrString size];

  NSRect textRect = NSMakeRect(headerRect.origin.x+(headerRect.size.width  - textSize.width ) / 2, headerRect.origin.y,
                               textSize.width, headerRect.size.height);
  BOOL isSelectedCell = NO;
  NSIndexSet* indexSet = [(NSTableView*)controlView selectedRowIndexes];
  unsigned int index = [indexSet firstIndex];
  while(!isSelectedCell && (index != NSNotFound))
  {
    isSelectedCell |= NSIntersectsRect(headerRect, [(NSTableView*)controlView rectOfRow:index]);
    index = [indexSet indexGreaterThanIndex:index];
  }
  
  if (!isSelectedCell)
    [self drawGradientInRect:headerRect withColor:[NSColor lightGrayColor]];
  else
  {
    [[NSColor grayColor] set];
    NSRectFill(headerRect);
    NSRect insideHeaderRect = NSMakeRect(headerRect.origin.x+.25, headerRect.origin.y+.25, headerRect.size.width-.5, headerRect.size.height-.5);
    [self drawGradientInRect:insideHeaderRect withColor:[NSColor grayColor]];
  }
  [attrString drawInRect:textRect]; //the date is displayed
  [attrString release];
}

-(void) drawGradientInRect:(NSRect)rect withColor:(NSColor*)color
{
  // Take the color apart
  NSColor *alternateSelectedControlColor = color ? color : [NSColor grayColor];
  float hue, saturation, brightness, alpha;
  [[alternateSelectedControlColor
      colorUsingColorSpaceName:NSDeviceRGBColorSpace] getHue:&hue
      saturation:&saturation brightness:&brightness alpha:&alpha];

  // Create synthetic darker and lighter versions
  NSColor *lighterColor = [NSColor colorWithDeviceHue:hue
     saturation:MAX(0.0, saturation-.12) brightness:MIN(1.0,
     brightness+0.30) alpha:alpha];
  NSColor *darkerColor = [NSColor colorWithDeviceHue:hue
     saturation:MIN(1.0, (saturation > .04) ? saturation+0.12 :
     0.0) brightness:MAX(0.0, brightness-0.045) alpha:alpha];
  
  // Set up the helper function for drawing washes
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  twoRgba_t* twoColors = (twoRgba_t*) malloc(1*sizeof(twoRgba_t));
  
  // We malloc() the helper data because we may draw this wash during printing, in which case it won't necessarily be evaluated
  // immediately. We need for all the data the shading function needs to draw to potentially outlive us.
  [lighterColor getRed:&twoColors->red1 green:&twoColors->green1 blue:&twoColors->blue1 alpha:&twoColors->alpha1];
  [darkerColor  getRed:&twoColors->red2 green:&twoColors->green2 blue:&twoColors->blue2 alpha:&twoColors->alpha2];
  static const float domainAndRange[8] = {0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0};
  CGFunctionRef linearBlendFunctionRef = CGFunctionCreate(twoColors, 1, domainAndRange, 4, domainAndRange, &linearFunctionCallbacks);
  
  // Draw a soft wash underneath it
  CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
  CGContextSaveGState(context);
  CGContextClipToRect(context, CGRectMake(NSMinX(rect), NSMinY(rect), NSWidth(rect), NSHeight(rect)));
  CGShadingRef cgShading = CGShadingCreateAxial(colorSpace, CGPointMake(0, NSMinY(rect)),
                                                            CGPointMake(0, NSMaxY(rect)), linearBlendFunctionRef, NO, NO);
  CGContextDrawShading(context, cgShading);
  CGShadingRelease(cgShading);
  CGContextRestoreGState(context);

  CGFunctionRelease(linearBlendFunctionRef);
  CGColorSpaceRelease(colorSpace);
}

@end
