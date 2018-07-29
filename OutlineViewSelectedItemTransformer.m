//
//  OutlineViewSelectedItemTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "OutlineViewSelectedItemTransformer.h"

#import "NSObjectExtended.h"
#import "NSOutlineViewExtended.h"

@implementation OutlineViewSelectedItemTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithOutlineView:nil firstIfMultiple:NO] forName:[self name]];
}
//end initialize

+(NSString*) name
{
  NSString* result = [self className];
  return result;
}
//end name

+(Class) transformedValueClass
{
  return [NSObject class];
}
//end transformedValueClass

+(BOOL) allowsReverseTransformation
{
  return NO;
}
//end allowsReverseTransformation

+(instancetype) transformerWithOutlineView:(NSOutlineView*)outlineView firstIfMultiple:(BOOL)firstIfMultiple
{
  id result = [[[self class] alloc] initWithOutlineView:outlineView firstIfMultiple:firstIfMultiple];
  return result;
}
//end transformerWithClass:

-(instancetype) initWithOutlineView:(NSOutlineView*)aOutlineView firstIfMultiple:(BOOL)aFirstIfMultiple
{
  if ((!(self = [super init])))
    return nil;
  self->outlineView = aOutlineView;
  self->firstIfMultiple = aFirstIfMultiple;
  return self;
}
//end initWithOutlineView:

-(id) transformedValue:(id)value
{
  id result = nil;
  NSIndexSet* indexSet = [value dynamicCastToClass:[NSIndexSet class]];
  NSUInteger count = indexSet.count;
  result = !count ? nil :
  (self->firstIfMultiple || (count == 1)) ? [self->outlineView itemsAtRowIndexes:indexSet][0] :
    nil;
  return result;
}
//end transformedValue:

@end
