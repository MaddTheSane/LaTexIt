//
//  NSObjectExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/07.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
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

-(BOOL) isDarkMode
{
  BOOL result = NO;
  if (isMacOS10_14OrAbove())
  {
    NSString* _NSAppearanceNameAqua = @"NSAppearanceNameAqua";
    NSString* _NSAppearanceNameDarkAqua = @"NSAppearanceNameDarkAqua";
    SEL effectiveAppearanceSelector = NSSelectorFromString(@"effectiveAppearance");
    DebugLog(1, @"<%@> supports <%@> : %d", self, NSStringFromSelector(effectiveAppearanceSelector),
            [self respondsToSelector:effectiveAppearanceSelector]);
    id effectiveAppearance = ![self respondsToSelector:effectiveAppearanceSelector] ? nil :
    [self performSelector:effectiveAppearanceSelector];
    DebugLog(1, @"isDarkMode: effectiveAppearance = <%@>", effectiveAppearance);
    SEL bestMatchFromAppearancesWithNamesSelector = NSSelectorFromString(@"bestMatchFromAppearancesWithNames:");
    NSArray* modes = [NSArray arrayWithObjects:_NSAppearanceNameAqua, _NSAppearanceNameDarkAqua, nil];
    DebugLog(1, @"isDarkMode: modes = <%@>", modes);
    DebugLog(1, @"<%@> supports <%@> : %d", effectiveAppearance, NSStringFromSelector(bestMatchFromAppearancesWithNamesSelector),
                   [effectiveAppearance respondsToSelector:bestMatchFromAppearancesWithNamesSelector]);
    id mode = ![effectiveAppearance respondsToSelector:bestMatchFromAppearancesWithNamesSelector] ? nil :
    [effectiveAppearance performSelector:bestMatchFromAppearancesWithNamesSelector withObject:modes];
    DebugLog(1, @"isDarkMode: mode = <%@>", mode);
    NSString* modeAsString = [mode dynamicCastToClass:[NSString class]];
    result = [modeAsString isEqualToString:_NSAppearanceNameDarkAqua];
    DebugLog(1, @"isDarkMode: result = <%d>", result);
  }//end if (isMacOS10_14OrAbove())
  return result;
}
//end isDarkMode()

@end
