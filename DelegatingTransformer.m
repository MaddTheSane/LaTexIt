//
//  DelegateTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/07/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import "DelegatingTransformer.h"


@implementation DelegatingTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithDelegate:nil context:nil] forName:[self name]];
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
  return YES;
}
//end allowsReverseTransformation

+(id) transformerWithDelegate:(id<DelegatingTransformerDelegate>)delegate context:(id)context
{
  id result = [[[[self class] alloc] initWithDelegate:delegate context:context] autorelease];
  return result;
}
//end transformerWithReference:

-(id) initWithDelegate:(id<DelegatingTransformerDelegate>)aDelegate context:(id)aContext
{
  if ((!(self = [super init])))
    return nil;
  self->context  = [aContext retain];
  self->delegate = aDelegate;
  return self;
}
//end initWithFalseValue:

-(void) dealloc
{
  [self->context release];
  [super dealloc];
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = [self->delegate transformer:self reverse:NO value:value context:self->context];
  return result;
}
//end transformedValue:

-(id) reverseTransformedValue:(id)value
{
  id result = [self->delegate transformer:self reverse:YES value:value context:self->context];
  return result;
}
//end reverseTransformedValue:

@end
