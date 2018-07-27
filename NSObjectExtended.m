//
//  NSObjectExtended.m
//  MozoDojo
//
//  Created by Pierre Chatelier on 16/03/07.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "NSObjectExtended.h"

#import "NSArrayExtended.h"
#import "Utils.h"

@implementation NSObject (Extended)

-(void) forwardInvocation:(NSInvocation*)anInvocation
{
  DebugLog(1, @"anInvocation = %@", anInvocation);
}
//end forwardInvocation:

@end
