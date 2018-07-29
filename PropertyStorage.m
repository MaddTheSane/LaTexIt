//
//  PropertyStorage.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/06/14.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "PropertyStorage.h"


@implementation PropertyStorage

-(instancetype) init
{
  return [self initWithDictionary:nil];
}
//end init

-(instancetype) initWithDictionary:(NSDictionary*)aDictionary
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
  id result = dictionary[key];
  return result;
}
//end objectForKey:

-(void) setObject:(id)object forKey:(id)key
{
  [self willChangeValueForKey:key];
  dictionary[key] = object;
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
  id result = self[key];
  return result;
}
//end valueForKey:

-(void) setValue:(id)object forKey:(id)key
{
  self[key] = object;
}
//end setValue:forKey:

- (nullable NSNumber*)objectForKeyedSubscript:(NSString*)key
{
  return self[key];
}

- (void)setObject:(nullable NSNumber*)obj forKeyedSubscript:(NSString*)key
{
  self[key] = obj;
}


@end
