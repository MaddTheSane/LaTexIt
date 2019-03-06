//
//  PropertyStorage.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/06/14.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "PropertyStorage.h"


@implementation PropertyStorage

-(id) init
{
  return [self initWithDictionary:nil];
}
//end init

-(id) initWithDictionary:(NSDictionary*)aDictionary
{
  if (!((self = [super init])))
    return nil;
  self->dictionary = !aDictionary ?
    [[NSMutableDictionary alloc] init] :
    [[NSMutableDictionary alloc] initWithDictionary:aDictionary];
  return self;
}
//end initWithDictionary:

-(void) dealloc
{
  [self->dictionary release];
  [super dealloc];
}
//end dealloc

-(id) objectForKey:(id)key
{
  id result = [self->dictionary objectForKey:key];
  return result;
}
//end objectForKey:

-(void) setObject:(id)object forKey:(id)key
{
  [self willChangeValueForKey:key];
  [self->dictionary setObject:object forKey:key];
  [self didChangeValueForKey:key];
}
//end setObject:forKey:

-(void) setDictionary:(NSDictionary*)value
{
  if (!value)
    [self->dictionary removeAllObjects];
  else
    [self->dictionary setDictionary:value];
}
//end setDictionary

-(NSDictionary*) dictionary
{
  NSDictionary* result = [[self->dictionary copy] autorelease];
  return result;
}
//end dictionary

-(id) valueForKey:(NSString*)key
{
  id result = [self objectForKey:key];
  return result;
}
//end valueForKey:

-(void) setValue:(id)object forKey:(id)key
{
  [self setObject:object forKey:key];
}
//end setValue:forKey:

@end
