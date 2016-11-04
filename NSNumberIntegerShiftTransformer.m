//
//  NSNumberIntegerShiftTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import "NSNumberIntegerShiftTransformer.h"

@implementation NSNumberIntegerShiftTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithShift:[NSNumber numberWithInt:0]] forName:[self name]];
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
  return [NSNumber class];
}
//end transformedValueClass

+(BOOL) allowsReverseTransformation
{
  return YES;
}
//end allowsReverseTransformation

+(id) transformerWithShift:(NSNumber*)shift
{
  id result = [[[[self class] alloc] initWithShift:shift] autorelease];
  return result;
}
//end transformerWithShift:

-(id) initWithShift:(NSNumber*)aShift
{
  if ((!(self = [super init])))
    return nil;
  self->shift = [aShift copy];
  return self;
}
//end initWithShift:

-(void) dealloc
{
  [self->shift release];
  [super dealloc];
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = [NSNumber numberWithInt:[value intValue]+[self->shift intValue]];
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = [NSNumber numberWithInt:[value intValue]-[self->shift intValue]];
  return result;
}
//end reverseTransformedValue:

@end
