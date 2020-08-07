//
//  NSSegmentedControlExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 18/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "NSSegmentedControlExtended.h"

@implementation NSSegmentedControl (Extended)

-(NSInteger) selectedSegmentTag
{
  NSInteger result = -1;
  NSInteger selectedSegment = [self selectedSegment];
  result = [[self cell] tagForSegment:selectedSegment];
  return result;
}
//end selectedSegmentTag

-(void) sizeToFitWithSegmentWidth:(CGFloat)segmentWidth useSameSize:(BOOL)useSameSize
{
  NSInteger nbSegments = [self segmentCount];
  NSInteger i = 0;
  CGFloat maxSize = 0;
  for(i = 0 ; i<nbSegments ; ++i)
  {
    [self setWidth:segmentWidth forSegment:i];
    CGFloat width = [self widthForSegment:i];
    maxSize = MAX(maxSize, width);
  }
  if (useSameSize)
  for(i = 0 ; i<nbSegments ; ++i)
    [self setWidth:maxSize forSegment:i];
}
//end sizeToFitWithSegmentWidth:useSameSize:

@end
