//
//  Semaphore.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 09/10/06.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "Semaphore.h"

#import "NSObjectExtended.h"

@implementation Semaphore

//designated initializer
-(id) initWithValue:(NSUInteger)initialValue
{
  if ((!(self = [super init])))
    return nil;
  int error = pthread_condattr_init(&self->cond_attr);
  error = error ? error : pthread_cond_init(&self->cond, &self->cond_attr);
  error = error ? error : pthread_mutexattr_init(&self->mutex_attr);
  error = error ? error : pthread_mutex_init(&self->mutex, &self->mutex_attr);
  if (error)
  {
    #ifdef ARC_ENABLED
    #else
    [self autorelease];
    #endif
    self = nil;
    return nil;
  }
  self->value = initialValue;
  return self;
}
//end initWithValue:

-(id) init
{
  return [self initWithValue:0];
}
//end init

-(void) dealloc
{
  pthread_condattr_destroy(&self->cond_attr);
  pthread_cond_destroy(&self->cond);
  pthread_mutexattr_destroy(&self->mutex_attr);
  pthread_mutex_destroy(&self->mutex);
  #ifdef ARC_ENABLED
  #else
  [super dealloc];
  #endif
}
//end dealloc

-(void) P:(NSUInteger)n
{
  pthread_mutex_lock(&self->mutex);
  while(self->value<n)
    pthread_cond_wait(&self->cond, &self->mutex);
  self->value -= n;
  pthread_mutex_unlock(&self->mutex);
  pthread_cond_broadcast(&self->cond);
}
//end P:

-(void) P
{
  [self P:1];
}
//end P

-(void) V:(NSUInteger)n
{
  pthread_mutex_lock(&self->mutex);
  self->value += n;
  pthread_mutex_unlock(&self->mutex);
  pthread_cond_broadcast(&self->cond);
}
//end V:

-(void) V
{
  [self V:1];
}
//end V

-(NSUInteger) R
{
  return self->value;
}
//end R

-(void) Z
{
  pthread_mutex_lock(&self->mutex);
  while(self->value)
    pthread_cond_wait(&self->cond, &self->mutex);
  pthread_mutex_unlock(&self->mutex);
}
//end Z

//NSCoding protocol
-(id) initWithCoder:(NSCoder*)coder
{
  return [self initWithValue:[[[coder decodeObjectForKey:@"value"] dynamicCastToClass:[NSNumber class]] unsignedIntegerValue]];
}
//end initWithCoder:

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:@([self R]) forKey:@"value"];
}
//end encodeWithCoder:

@end
