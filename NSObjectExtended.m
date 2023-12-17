//
//  NSObjectExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/07.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
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

-(id) managedObjectContext
{
  id result = nil;
  return result;
}
//end managedObjectContext

-(BOOL) isDarkMode
{
  BOOL result = NO;
  if (@available(macOS 10.14, *)) {
    if ([self conformsToProtocol:@protocol(NSAppearanceCustomization)]) {
      NSAppearance *effectiveAppearance = [(id<NSAppearanceCustomization>)self effectiveAppearance];
      NSArray* modes = @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua];
      NSAppearanceName mode = [effectiveAppearance bestMatchFromAppearancesWithNames:modes];
      result = [mode isEqualToString:NSAppearanceNameDarkAqua];
    }
  }//end if (isMacOS10_14OrAbove())
  return result;
}
//end isDarkMode()

@end
