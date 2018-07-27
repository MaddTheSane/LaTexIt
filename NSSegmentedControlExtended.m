//
//  NSSegmentedControlExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/07/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.
//

//this file is an extension of the NSSegmentedControl class
//It is only useful to compile LaTeXiT for Panther

#import "NSSegmentedControlExtended.h"

@implementation NSSegmentedControl (Extended)

#ifdef PANTHER
-(BOOL) selectSegmentWithTag:(int)tag //does exists in MacOS 10.4
{
  int segmentToSelect = -1;
  const int segmentCount = [self segmentCount];
  int i = 0;
  for(i = 0 ; (segmentToSelect<0) && (i<segmentCount) ; ++i)
    segmentToSelect = ([[self cell] tagForSegment:i] == tag) ? i : -1;

   if (segmentToSelect >= 0)
     [self setSelected:YES forSegment:segmentToSelect];

  return (segmentToSelect >= 0);
}
#endif

@end
