//
//  DragFilterView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/10.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "DragFilterView.h"

#import "CGExtras.h"

@implementation DragFilterView

-(BOOL) isOpaque
{
  return NO;
}
//end isOpaque

-(void)drawRect:(NSRect)dirtyRect
{
  CGContextRef cgContext = [[NSGraphicsContext currentContext] graphicsPort];
  CGRect roundedRect = CGRectFromNSRect([self bounds]);
  roundedRect.size.width -= 20;
  roundedRect.origin.x += 10;
  roundedRect.size.height -= 10;
  roundedRect.origin.y += 10;
  
  roundedRect.size.height -= 2;
  roundedRect.origin.y += 1;
  
  CGContextSaveGState(cgContext);
  CGContextAddRoundedRect(cgContext, roundedRect, 5, 5);
  CGContextSetRGBFillColor(cgContext, .0, .0, .0, .33);
  CGContextSetShadow(cgContext, CGSizeMake(0, -5), 10);
  CGContextFillPath(cgContext);
  CGContextAddRoundedRect(cgContext, roundedRect, 5, 5);
  CGContextSetShouldAntialias(cgContext, YES);
  CGContextSetRGBStrokeColor(cgContext, .8, .8, .8, 1.);
  CGContextSetLineWidth(cgContext, 3);
  CGContextStrokePath(cgContext);
  CGContextRestoreGState(cgContext);
  [super drawRect:dirtyRect];
}
//end drawRect:

@end
