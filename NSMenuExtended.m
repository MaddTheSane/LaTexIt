//
//  NSMenuExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/05/10.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSMenuExtended.h"


@implementation NSMenu (Extended)

-(NSMenuItem*) addItemWithTitle:(NSString*)aString target:(id)target action:(SEL)aSelector
                  keyEquivalent:(NSString*)keyEquivalent  keyEquivalentModifierMask:(int)keyEquivalentModifierMask
                  tag:(int)tag;
{
  NSMenuItem* result = [self addItemWithTitle:aString action:aSelector keyEquivalent:keyEquivalent];
  [result setTarget:target];
  [result setKeyEquivalentModifierMask:keyEquivalentModifierMask];
  [result setTag:tag];
  return result;
}
//end addItemWithTitle:target:action:keyEquivalent:keyEquivalentModifierMask:

@end
