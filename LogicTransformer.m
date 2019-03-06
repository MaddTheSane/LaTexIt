//
//  LogicTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "LogicTransformer.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation LogicTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithTransformers:nil logicOperator:LOGIC_TRANSFORMER_OPERATOR_AND] forName:[self name]];
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

+(instancetype) transformerWithTransformers:(NSArray*)transformers logicOperator:(logic_transformer_operator_t)logicOperator
{
  id result = [[[self class] alloc] initWithTransformers:transformers logicOperator:logicOperator];
  return result;
}
//end transformerWithTransformers:

-(instancetype) initWithTransformers:(NSArray*)theTransformers logicOperator:(logic_transformer_operator_t)aLogicOperator
{
  if ((!(self = [super init])))
    return nil;
  self->transformers  = [theTransformers copy];
  self->logicOperator = aLogicOperator;
  return self;
}
//end initWithTransformers:logicOperator:

-(id) transformedValue:(id)value
{
  id result = nil;
  BOOL localResult = NO;
  if (self->logicOperator == LOGIC_TRANSFORMER_OPERATOR_AND)
  {
    localResult = YES;
    NSEnumerator* enumerator = [self->transformers objectEnumerator];
    NSValueTransformer* transformer = nil;
    while(localResult && ((transformer = [enumerator nextObject])))
      localResult &= [[transformer transformedValue:value] boolValue];
  }//end if (self->logicOperator == LOGIC_TRANSFORMER_OPERATOR_AND)
  else if (self->logicOperator == LOGIC_TRANSFORMER_OPERATOR_OR)
  {
    localResult = NO;
    NSEnumerator* enumerator = [self->transformers objectEnumerator];
    NSValueTransformer* transformer = nil;
    while(!localResult && ((transformer = [enumerator nextObject])))
      localResult |= [[transformer transformedValue:value] boolValue];
  }//end if (self->logicOperator == LOGIC_TRANSFORMER_OPERATOR_OR)
  result = @(localResult);
  return result;
}
//end transformedValue:

@end
