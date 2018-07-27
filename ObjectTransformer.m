//
//  ObjectTransformer.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import "ObjectTransformer.h"

@implementation ObjectTransformer

+(void) initialize
{
  [self setValueTransformer:[self transformerWithDictionary:nil] forName:[self name]];
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

+(id) transformerWithDictionary:(NSDictionary*)dictionary
{
  id result = [[[[self class] alloc] initWithDictionary:dictionary] autorelease];
  return result;
}
//end transformerWithDictionary:

-(id) initWithDictionary:(NSDictionary*)aDictionary
{
  if ((!(self = [super init])))
    return nil;
  self->dictionary = [aDictionary copy];
  return self;
}
//end initWithDescriptors:

-(void) dealloc
{
  [self->dictionary release];
  [super dealloc];
}
//end dealloc

-(id) transformedValue:(id)value
{
  id result = [self->dictionary objectForKey:value];
  return result;
}
//end transformedValue:

@end
