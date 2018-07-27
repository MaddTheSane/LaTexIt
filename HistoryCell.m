//  HistoryCell.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/03/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

//This class is the kind of cell used to display history items in the history drawer
//It may take in account the different fields of an history item (image, date...)

#import "HistoryCell.h"

#import "NSImageExtended.h"
#import "Utils.h"

// CoreGraphics gradient helpers
typedef struct {
  CGFloat red1, green1, blue1, alpha1;
  CGFloat red2, green2, blue2, alpha2;
} twoRgba_t;

static void _linearColorBlendFunction(void *info, const CGFloat *inData, CGFloat *outData)
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
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  self->dateFormatter = [[NSDateFormatter alloc] init];
  [self->dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
  self->backgroundColor = nil;//there may be no color
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [self->dateFormatter release];
  [super dealloc];
}
//end dealloc

-(void) setBackgroundColor:(NSColor*)color
{
  [color retain];
  [self->backgroundColor release];
  self->backgroundColor = color;
}
//end setBackgroundColor:

-(id) copyWithZone:(NSZone*)zone
{
  HistoryCell* cell = (HistoryCell*) [super copyWithZone:zone];
  if (cell)
  {
    cell->dateFormatter = [self->dateFormatter retain];
    cell->backgroundColor = [self->backgroundColor copy];
  }
  return cell;
}
//end copyWithZone:

-(void) drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
  if (self->backgroundColor)
  {
    [self->backgroundColor set];
    NSRectFill(cellFrame);
  }
  NSRect headerRect = NSMakeRect(cellFrame.origin.x-1, cellFrame.origin.y-1, cellFrame.size.width+3, 16);
  NSRect imageRect = NSMakeRect(cellFrame.origin.x, cellFrame.origin.y+headerRect.size.height,
                                cellFrame.size.width, cellFrame.size.height-headerRect.size.height);
  BOOL drawScaled = YES;
  if (!drawScaled)
    [super drawInteriorWithFrame:imageRect inView:controlView]; //the image is displayed in a subrect of the cell
  else
  {
    NSImage* image = [self image];
    NSImageRep* imageRep = [image bestImageRepresentationInContext:[NSGraphicsContext currentContext]];
    NSPDFImageRep* pdfImageRep = ![imageRep isKindOfClass:[NSPDFImageRep class]] ? nil : (NSPDFImageRep*)imageRep;
    NSRect bounds = !pdfImageRep ? NSMakeRect(0.f, 0.f, [imageRep pixelsWide], [imageRep pixelsHigh]) :
                    [pdfImageRep bounds];
    NSRect imageDrawRect = adaptRectangle(bounds, imageRect, YES, NO, YES);
    [NSGraphicsContext saveGraphicsState];
    NSAffineTransform* transform = [NSAffineTransform transform];
    [transform translateXBy:imageDrawRect.origin.x yBy:imageDrawRect.origin.y];
    [transform translateXBy:0 yBy:imageDrawRect.size.height/2];
    [transform scaleXBy:1.f yBy:[image isFlipped] ^ [controlView isFlipped] ? -1.f : 1.f];
    [transform translateXBy:0 yBy:-imageDrawRect.size.height/2];
    [transform concat];
    [imageRep drawInRect:NSMakeRect(0, 0, imageDrawRect.size.width, imageDrawRect.size.height)];
    [NSGraphicsContext restoreGraphicsState];
  }//end if (drawScaled)

  //now we add the date
  NSDate* date = [[self representedObject] date];
  [self->dateFormatter setDateStyle:NSDateFormatterNoStyle];
  [self->dateFormatter setTimeStyle:NSDateFormatterNoStyle];
  [self->dateFormatter setDateStyle:NSDateFormatterFullStyle];
  NSString* dateString = [self->dateFormatter stringFromDate:date];
  [self->dateFormatter setDateStyle:NSDateFormatterNoStyle];
  [self->dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
  NSString* timeString = [self->dateFormatter stringFromDate:date];
  [self->dateFormatter setTimeStyle:NSDateFormatterNoStyle];
  NSString* dateTimeString = [NSString stringWithFormat:@"%@, %@", dateString, timeString];
  NSAttributedString* attrString = !dateTimeString ? nil :
    [[NSAttributedString alloc] initWithString:dateTimeString attributes:nil];
  NSSize textSize = !attrString ? NSZeroSize : [attrString size];

  NSRect textRect = NSMakeRect(headerRect.origin.x+(headerRect.size.width  - textSize.width ) / 2, headerRect.origin.y,
                               textSize.width, headerRect.size.height);
  textRect.origin.x = MAX(headerRect.origin.x, textRect.origin.x);
    
  BOOL isSelectedCell = NO;
  NSIndexSet* indexSet = [(NSTableView*)controlView selectedRowIndexes];
  NSUInteger index = [indexSet firstIndex];
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
//end drawInteriorWithFrame:inView:

-(void) drawGradientInRect:(NSRect)rect withColor:(NSColor*)color
{
  // Take the color apart
  NSColor *alternateSelectedControlColor = color ? color : [NSColor grayColor];
  CGFloat hue, saturation, brightness, alpha;
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
  static const CGFloat domainAndRange[8] = {0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0};
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
//end drawGradientInRect:withColor:

@end
