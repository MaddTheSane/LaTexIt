//
//  NSNumberIntegerShiftTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "NSNumberIntegerShiftTransformer.h"

@implementation NSNumberIntegerShiftTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithShift:@0] forName:[self name]];
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

+(instancetype) transformerWithShift:(NSNumber*)shift
{
  id result = [[[self class] alloc] initWithShift:shift];
  return result;
}
//end transformerWithShift:

-(instancetype) initWithShift:(NSNumber*)aShift
{
  if ((!(self = [super init])))
    return nil;
  self->shift = [aShift copy];
  return self;
}
//end initWithShift:

-(id) transformedValue:(id)value
{
  id result = @([value integerValue]+[self->shift integerValue]);
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = @([value integerValue]-[self->shift integerValue]);
  return result;
}
//end reverseTransformedValue:

@end
