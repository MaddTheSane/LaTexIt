//
//  ServiceRegularExpressionFiltersController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/01/13.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "ServiceRegularExpressionFiltersController.h"

#import "NSObjectExtended.h"
#import "PreferencesController.h"
#import "RegexKitLite.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation ServiceRegularExpressionFiltersController

-(id) newObject
{
  id result = nil;
  NSArray* objects = self.arrangedObjects;
  NSArray* selectedObjects = self.selectedObjects;
  id modelObject = (selectedObjects && selectedObjects.count) ? selectedObjects[0] :
                   (objects && objects.count) ? objects[0] : nil;
  result = modelObject ? [modelObject mutableCopy] :
    @{ServiceRegularExpressionFilterEnabledKey: @NO,
      ServiceRegularExpressionFilterInputPatternKey: @"(\\(.*\\))",
      ServiceRegularExpressionFilterOutputPatternKey: @"\\1"};
  return result;
}
//end newObject

-(void) add:(id)sender
{
  id newObject = [self newObject];
  [self addObject:newObject];
  [self setSelectedObjects:@[newObject]];
}
//end add:

-(NSString*) applyFilter:(NSString*)value
{
  NSMutableString* result = [value mutableCopy];
  NSEnumerator* enumerator = [self.arrangedObjects objectEnumerator];
  NSDictionary* filter = nil;
  while((filter = [enumerator nextObject]))
  {
    BOOL enabled = [filter[ServiceRegularExpressionFilterEnabledKey] boolValue];
    if (enabled)
    {
      NSString* inputPattern = filter[ServiceRegularExpressionFilterInputPatternKey];
      NSString* outputPattern = filter[ServiceRegularExpressionFilterOutputPatternKey];
      if (!outputPattern)
        outputPattern = @"";
      if (inputPattern && ![inputPattern isEqualToString:@""])
      {
        @try{
          [result replaceOccurrencesOfRegex:inputPattern withString:outputPattern options:RKLMultiline|RKLDotAll range:NSMakeRange(0, result.length) error:nil];
        }
        @catch(NSException*){
        }
      }
    }//end if (enabled)
  }//end for each filter
  result = [result copy];
  return result;
}
//end applyFilter:

-(NSAttributedString*) applyFilterToAttributedString:(NSAttributedString*)value
{
  NSMutableAttributedString* result = [value mutableCopy];
  NSEnumerator* enumerator = [self.arrangedObjects objectEnumerator];
  NSDictionary* filter = nil;
  while((filter = [enumerator nextObject]))
  {
    BOOL enabled = [filter[ServiceRegularExpressionFilterEnabledKey] boolValue];
    if (enabled)
    {
      NSString* inputPattern = filter[ServiceRegularExpressionFilterInputPatternKey];
      NSString* outputPattern = filter[ServiceRegularExpressionFilterOutputPatternKey];
      if (!outputPattern)
        outputPattern = @"";
      if (inputPattern && ![inputPattern isEqualToString:@""])
      {
        @try{
          [result replaceOccurrencesOfRegex:inputPattern withString:outputPattern options:RKLMultiline|RKLDotAll range:NSMakeRange(0, result.length) error:nil];
        }
        @catch(NSException*){
        }
      }
    }//end if (enabled)
  }//end for each filter
  result = [result copy];
  return result;
}
//end applyFilterToAttributedString:

@end
