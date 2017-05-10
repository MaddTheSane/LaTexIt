//
//  OutlineViewSelectedItemTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2015 __MyCompanyName__. All rights reserved.
//

#import "OutlineViewSelectedItemTransformer.h"

#import "NSObjectExtended.h"
#import "NSOutlineViewExtended.h"

#if __has_feature(objc_arc)
#error this file needs to be compiled without Automatic Reference Counting (ARC)
#endif

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

+(id) transformerWithOutlineView:(NSOutlineView*)outlineView firstIfMultiple:(BOOL)firstIfMultiple
{
#ifdef ARC_ENABLED
  id result = [[[self class] alloc] initWithOutlineView:outlineView firstIfMultiple:firstIfMultiple];
#else
  id result = [[[[self class] alloc] initWithOutlineView:outlineView firstIfMultiple:firstIfMultiple] autorelease];
#endif
  return result;
}
//end transformerWithClass:

-(id) initWithOutlineView:(NSOutlineView*)aOutlineView firstIfMultiple:(BOOL)aFirstIfMultiple
{
  if ((!(self = [super init])))
    return nil;
#ifdef ARC_ENABLED
  self->outlineView = aOutlineView;
#else
  self->outlineView = [aOutlineView retain];
#endif
  self->firstIfMultiple = aFirstIfMultiple;
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
  id result = nil;
  NSIndexSet* indexSet = [value dynamicCastToClass:[NSIndexSet class]];
  NSUInteger count = [indexSet count];
  result = !count ? nil :
  (self->firstIfMultiple || (count == 1)) ? [[self->outlineView itemsAtRowIndexes:indexSet] objectAtIndex:0] :
    nil;
  return result;
}
//end transformedValue:

@end
