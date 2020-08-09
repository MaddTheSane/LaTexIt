//
//  OutlineViewSelectedItemsTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "OutlineViewSelectedItemsTransformer.h"

#import "NSObjectExtended.h"
#import "NSOutlineViewExtended.h"

@implementation OutlineViewSelectedItemsTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithOutlineView:nil] forName:[self name]];
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
  return [NSArray class];
}
//end transformedValueClass

+(BOOL) allowsReverseTransformation
{
  return NO;
}
//end allowsReverseTransformation

+(instancetype) transformerWithOutlineView:(NSOutlineView*)outlineView;
{
  id result = [[[self class] alloc] initWithOutlineView:outlineView];
  return result;
}
//end transformerWithClass:

-(instancetype) initWithOutlineView:(NSOutlineView*)aOutlineView;
{
  if ((!(self = [super init])))
    return nil;
  self->outlineView = aOutlineView;
  return self;
}
//end initWithOutlineView:

-(id) transformedValue:(id)value
{
  id result = [self->outlineView itemsAtRowIndexes:[value dynamicCastToClass:[NSIndexSet class]]];
  return result;
}
//end transformedValue:

@end
