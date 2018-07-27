//
//  ServiceRegularExpressionFiltersController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/01/13.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import "ServiceRegularExpressionFiltersController.h"

#import "NSObjectExtended.h"
#import "PreferencesController.h"
#import "RegexKitLite.h"

@implementation ServiceRegularExpressionFiltersController

-(id) newObject
{
  id result = nil;
  NSArray* objects = [self arrangedObjects];
  NSArray* selectedObjects = [self selectedObjects];
  id modelObject = (selectedObjects && [selectedObjects count]) ? [selectedObjects objectAtIndex:0] :
                   (objects && [objects count]) ? [objects objectAtIndex:0] : nil;
  result = modelObject ? [modelObject mutableCopy] :
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], ServiceRegularExpressionFilterEnabledKey,
      @"(\\(.*\\))", ServiceRegularExpressionFilterInputPatternKey,
      @"\\1", ServiceRegularExpressionFilterOutputPatternKey,
      nil];
  return result;
}
//end newObject

-(void) add:(id)sender
{
  id newObject = [self newObject];
  [self addObject:newObject];
  [self setSelectedObjects:[NSArray arrayWithObjects:newObject, nil]];
}
//end add:

-(NSString*) applyFilter:(NSString*)value
{
  NSMutableString* result = [[value mutableCopy] autorelease];
  NSEnumerator* enumerator = [[self arrangedObjects] objectEnumerator];
  NSDictionary* filter = nil;
  while((filter = [enumerator nextObject]))
  {
    BOOL enabled = [[filter objectForKey:ServiceRegularExpressionFilterEnabledKey] boolValue];
    if (enabled)
    {
      NSString* inputPattern = [filter objectForKey:ServiceRegularExpressionFilterInputPatternKey];
      NSString* outputPattern = [filter objectForKey:ServiceRegularExpressionFilterOutputPatternKey];
      if (!outputPattern)
        outputPattern = @"";
      if (inputPattern && ![inputPattern isEqualToString:@""])
      {
        @try{
          [result replaceOccurrencesOfRegex:inputPattern withString:outputPattern options:RKLMultiline|RKLDotAll range:NSMakeRange(0, [result length]) error:nil];
        }
        @catch(NSException*){
        }
      }
    }//end if (enabled)
  }//end for each filter
  return [[result copy] autorelease];
}
//end applyFilter:

-(NSAttributedString*) applyFilterToAttributedString:(NSAttributedString*)value
{
  NSMutableAttributedString* result = [[value mutableCopy] autorelease];
  NSEnumerator* enumerator = [[self arrangedObjects] objectEnumerator];
  NSDictionary* filter = nil;
  while((filter = [enumerator nextObject]))
  {
    BOOL enabled = [[filter objectForKey:ServiceRegularExpressionFilterEnabledKey] boolValue];
    if (enabled)
    {
      NSString* inputPattern = [filter objectForKey:ServiceRegularExpressionFilterInputPatternKey];
      NSString* outputPattern = [filter objectForKey:ServiceRegularExpressionFilterOutputPatternKey];
      if (!outputPattern)
        outputPattern = @"";
      if (inputPattern && ![inputPattern isEqualToString:@""])
      {
        @try{
          [result replaceOccurrencesOfRegex:inputPattern withString:outputPattern options:RKLMultiline|RKLDotAll range:NSMakeRange(0, [result length]) error:nil];
        }
        @catch(NSException*){
        }
      }
    }//end if (enabled)
  }//end for each filter
  return [[result copy] autorelease];
}
//end applyFilterToAttributedString:

@end