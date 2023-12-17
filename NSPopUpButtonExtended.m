//
//  NSPopUpButtonExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/05/10.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import "NSPopUpButtonExtended.h"


@implementation NSPopUpButton (Extended)

-(id) addItemWithTitle:(NSString*)title tag:(NSInteger)tag
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

-(NSMenuItem*) addItemWithTitle:(NSString*)aString target:(id)target action:(SEL)action tag:(NSInteger)tag
{
  NSMenuItem* result = [self addItemWithTitle:aString tag:tag];
  [result setTarget:target];
  [result setAction:action];
  return result;
}
//end addItemWithTitle:target:action:tag:


@end
