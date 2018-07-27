//
//  NSWindowExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/07/12.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSWindowExtended.h"

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

@end
