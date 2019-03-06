//
//  NSButtonExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/05/11.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "NSButtonExtended.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSButton (Extended)

-(NSColor*) textColor
{
  NSColor* result = nil;
  NSAttributedString* attributedTitle = self.attributedTitle;
  NSUInteger length = attributedTitle.length;
  NSRange range = NSMakeRange(0, MIN(length, 1U)); // take color from first char
  NSDictionary* attributes = [attributedTitle fontAttributesInRange:range];
  result = !attributes ? [NSColor controlTextColor] :
    attributes[NSForegroundColorAttributeName];
  return result;
}
//end textColor

-(void) setTextColor:(NSColor*)textColor
{
  NSMutableAttributedString* attributedTitle =
    [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedTitle];
  NSUInteger length = attributedTitle.length;
  NSRange range = NSMakeRange(0, length);
  [attributedTitle addAttribute:NSForegroundColorAttributeName value:textColor range:range];
  [attributedTitle fixAttributesInRange:range];
  self.attributedTitle = attributedTitle;
}
//end setTextColor:

@end
