//
//  NSObjectExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/07.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
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
  if (isMacOS10_14OrAbove())
  {
    NSString* _NSAppearanceNameAqua = @"NSAppearanceNameAqua";
    NSString* _NSAppearanceNameDarkAqua = @"NSAppearanceNameDarkAqua";
    SEL effectiveAppearanceSelector = NSSelectorFromString(@"effectiveAppearance");
    id effectiveAppearance = ![self respondsToSelector:effectiveAppearanceSelector] ? nil :
    [self performSelector:effectiveAppearanceSelector];
    SEL bestMatchFromAppearancesWithNamesSelector = NSSelectorFromString(@"bestMatchFromAppearancesWithNames:");
    NSArray* modes = [NSArray arrayWithObjects:_NSAppearanceNameAqua, _NSAppearanceNameDarkAqua, nil];
    id mode = ![effectiveAppearance respondsToSelector:bestMatchFromAppearancesWithNamesSelector] ? nil :
    [effectiveAppearance performSelector:bestMatchFromAppearancesWithNamesSelector withObject:modes];
    NSString* modeAsString = [mode dynamicCastToClass:[NSString class]];
    result = [modeAsString isEqualToString:_NSAppearanceNameDarkAqua];
  }//end if (isMacOS10_14OrAbove())
  return result;
}
//end isDarkMode()

@end
