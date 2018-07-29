//
//  PropertyStorage.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/06/14.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
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

-(id) objectForKey:(id)key
{
  id result = [dictionary objectForKey:key];
  return result;
}
//end objectForKey:

-(void) setObject:(id)object forKey:(id)key
{
  [self willChangeValueForKey:key];
  [dictionary setObject:object forKey:key];
  [self didChangeValueForKey:key];
}
//end setObject:forKey:

-(void) setDictionary:(NSDictionary*)value
{
  if (!value)
    [dictionary removeAllObjects];
  else
    [dictionary setDictionary:value];
}
//end setDictionary

-(NSDictionary*) dictionary
{
  NSDictionary* result = [dictionary copy];
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

- (nullable NSNumber*)objectForKeyedSubscript:(NSString*)key
{
  return [self objectForKey:key];
}

- (void)setObject:(nullable NSNumber*)obj forKeyedSubscript:(NSString*)key
{
  [self setObject:obj forKey:key];
}


@end
