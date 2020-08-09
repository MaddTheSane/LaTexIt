//
//  IsInTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "IsKindOfClassTransformer.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation IsKindOfClassTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithClass:nil] forName:[self name]];
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
  return NO;
}
//end allowsReverseTransformation

+(instancetype) transformerWithClass:(id)aClass
{
  id result = [[[self class] alloc] initWithClass:aClass];
  return result;
}
//end transformerWithClass:

-(instancetype) initWithClass:(Class)aClass
{
  if ((!(self = [super init])))
    return nil;
  self->theClass = aClass;
  return self;
}
//end initWithClass:

-(id) transformedValue:(id)value
{
  id result = @([value isKindOfClass:self->theClass]);
  return result;
}
//end transformedValue:

@end
