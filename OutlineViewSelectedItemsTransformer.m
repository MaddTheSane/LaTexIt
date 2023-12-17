//
//  OutlineViewSelectedItemsTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
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

+(id) transformerWithOutlineView:(NSOutlineView*)outlineView;
{
#ifdef ARC_ENABLED
  id result = [[[self class] alloc] initWithOutlineView:outlineView];
#else
  id result = [[[[self class] alloc] initWithOutlineView:outlineView] autorelease];
#endif
  return result;
}
//end transformerWithClass:

-(id) initWithOutlineView:(NSOutlineView*)aOutlineView;
{
  if ((!(self = [super init])))
    return nil;
  #ifdef ARC_ENABLED
  self->outlineView = aOutlineView;
  #else
  self->outlineView = [aOutlineView retain];
  #endif
  return self;
}
//end initWithOutlineView:

-(void) dealloc
{
#ifdef ARC_ENABLED
#else
  [self->outlineView release];
  [super dealloc];
#endif
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = [self->outlineView itemsAtRowIndexes:[value dynamicCastToClass:[NSIndexSet class]]];
  return result;
}
//end transformedValue:

@end
