//
//  Semaphore.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 09/10/06.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "Semaphore.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif
#import "NSObjectExtended.h"

@implementation Semaphore

//designated initializer
-(instancetype) initWithValue:(NSUInteger)initialValue
{
  if ((!(self = [super init])))
    return nil;
  int error = pthread_condattr_init(&cond_attr);
  error = error ? error : pthread_cond_init(&cond, &cond_attr);
  error = error ? error : pthread_mutexattr_init(&mutex_attr);
  error = error ? error : pthread_mutex_init(&mutex, &mutex_attr);
  if (error)
  {
    self = nil;
    return nil;
  }
  value = initialValue;
  return self;
}
//end initWithValue:

-(instancetype) init
{
  return [self initWithValue:0];
}
//end init

-(void) dealloc
{
  pthread_condattr_destroy(&cond_attr);
  pthread_cond_destroy(&cond);
  pthread_mutexattr_destroy(&mutex_attr);
  pthread_mutex_destroy(&mutex);
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
  pthread_mutex_lock(&mutex);
  value += n;
  pthread_mutex_unlock(&mutex);
  pthread_cond_broadcast(&cond);
}
//end V:

-(void) V
{
  [self V:1];
}
//end V

-(NSUInteger) R
{
  return value;
}
//end R

-(void) Z
{
  pthread_mutex_lock(&mutex);
  while(value)
    pthread_cond_wait(&cond, &mutex);
  pthread_mutex_unlock(&mutex);
}
//end Z

//NSCoding protocol
-(instancetype) initWithCoder:(NSCoder*)coder
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
