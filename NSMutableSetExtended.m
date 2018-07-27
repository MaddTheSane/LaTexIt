//
//  NSMutableSetExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/10/10.
//  Copyright 2010 LAIC. All rights reserved.
//

#import "NSMutableSetExtended.h"

@implementation NSMutableSet (Extended)

-(void) safeAddObject:(id)object
{
  if (object)
    [self addObject:object];
}
//end safeAddObject:

@end
