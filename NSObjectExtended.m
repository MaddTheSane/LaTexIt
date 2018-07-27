//
//  NSObjectExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/07.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import "NSObjectExtended.h"

#import "NSArrayExtended.h"
#import "Utils.h"

@implementation NSObject (Extended)

+(Class) dynamicCastToClass:(Class)aClass
{
  Class result = ![self isSubclassOfClass:aClass] ? nil : aClass;
  return result;
}
//end dynamicCastToClass:

-(id) dynamicCastToClass:(Class)aClass
{
  id result = ![self isKindOfClass:aClass] ? nil : self;
  return result;
}
//end dynamicCastToClass:

-(void) forwardInvocation:(NSInvocation*)anInvocation
{
  DebugLog(1, @"anInvocation = %@", anInvocation);
}
//end forwardInvocation:

-(id) managedObjectContext
{
  id result = nil;
  return result;
}
//end managedObjectContext
@end
