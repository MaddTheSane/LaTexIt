//
//  NSWindowExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/07/12.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import "NSWindowExtended.h"

#import "Utils.h"

@interface NSWindow (Bridge10_7)
-(void) setAnimationBehavior:(NSInteger)newAnimationBehavior;
@end

@implementation NSWindow (Extended)

-(void) setAnimationEnabled:(BOOL)value
{
  if ([self respondsToSelector:@selector(setAnimationBehavior:)])
    [self setAnimationBehavior:(value ? 0 : 2)];
}
//end setAnimationEnabled:

-(NSPoint) bridge_convertPointToScreen:(NSPoint)point
{
  NSPoint result1 = point;
  NSPoint result2 = point;
  if (isMacOS10_12OrAbove())
    result1 = [self convertPointToScreen:point];
  else
    result2 = [self convertRectToScreen:NSMakeRect(point.x, point.y, 0, 0)].origin;
  return result1;
}
//end bridge_convertPointToScreen:

@end
