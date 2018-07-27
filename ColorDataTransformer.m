//
//  ColorDataTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 11/11/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "ColorDataTransformer.h"

#import "NSColorExtended.h"

@implementation ColorDataTransformer

static ColorDataTransformer* sharedColorDataTransformer;

+(void) initialize
{
  @synchronized(self)
  {
    if (!sharedColorDataTransformer)
    {
      sharedColorDataTransformer = [[ColorDataTransformer alloc] init];
      [NSValueTransformer setValueTransformer:sharedColorDataTransformer forName:@"ColorDataTransformer"];
    }
  }//end @synchronized(self)
}
//end initialize

+(Class) transformedValueClass
{
  return [NSColor class];
}
//end transformedValueClass

+(BOOL) allowsReverseTransformation
{
  return YES;
}
//end allowsReverseTransformation

-(id) transformedValue:(id)value
{
  id result = [value isKindOfClass:[NSColor class]] ? value :
              [value isKindOfClass:[NSData class]]  ? [NSColor colorWithData:value] :
              nil;
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = [value isKindOfClass:[NSColor class]] ? [value colorAsData] : nil;
  return result;
}
//end reverseTransformedValue:

@end
