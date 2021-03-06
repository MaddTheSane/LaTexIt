//
//  NSMutableSetExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/10/10.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "NSMutableSetExtended.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSMutableSet (Extended)

-(void) safeAddObject:(id)object
{
  if (object)
    [self addObject:object];
}
//end safeAddObject:

@end
