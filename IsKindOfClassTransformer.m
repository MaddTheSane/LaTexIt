//
//  IsInTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "IsKindOfClassTransformer.h"

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

+(id) transformerWithClass:(id)aClass
{
#ifdef ARC_ENABLED
  id result = [[[self class] alloc] initWithClass:aClass];
#else
  id result = [[[[self class] alloc] initWithClass:aClass] autorelease];
#endif
  return result;
}
//end transformerWithClass:

-(id) initWithClass:(Class)aClass
{
  if ((!(self = [super init])))
    return nil;
  self->theClass = aClass;
  return self;
}
//end initWithClass:

-(void) dealloc
{
#ifdef ARC_ENABLED
#else
  [super dealloc];
#endif
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = @([value isKindOfClass:self->theClass]);
  return result;
}
//end transformedValue:

@end
