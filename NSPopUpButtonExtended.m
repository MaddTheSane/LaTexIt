//
//  NSPopUpButtonExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/05/10.
//  Copyright 2010 LAIC. All rights reserved.
//

#import "NSPopUpButtonExtended.h"


@implementation NSPopUpButton (Extended)

-(id) addItemWithTitle:(NSString*)title tag:(int)tag
{
  NSInteger nbItemsBefore = [self numberOfItems];
  id item = [self itemWithTitle:title];
  if (!item)
  {
    [self addItemWithTitle:title];
    item = [self itemAtIndex:nbItemsBefore];
  }
  [item setTag:tag];
  return item;
}
//end addItemWithTitle:tag:

@end
