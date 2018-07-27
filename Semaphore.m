//
//  Semaphore.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 09/10/06.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import "Semaphore.h"

@implementation Semaphore

//designated initializer
-(id) initWithValue:(unsigned int)initialValue
{
  if ((!(self = [super init])))
    return nil;
  int error = pthread_condattr_init(&cond_attr);
  error = error ? error : pthread_cond_init(&cond, &cond_attr);
  error = error ? error : pthread_mutexattr_init(&mutex_attr);
  error = error ? error : pthread_mutex_init(&mutex, &mutex_attr);
  if (error)
  {
    #ifdef ARC_ENABLED
    #else
    [self autorelease];
    #endif
    self = nil;
    return nil;
  }
  value = initialValue;
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
  pthread_condattr_destroy(&cond_attr);
  pthread_cond_destroy(&cond);
  pthread_mutexattr_destroy(&mutex_attr);
  pthread_mutex_destroy(&mutex);
  #ifdef ARC_ENABLED
  #else
  [super dealloc];
  #endif
}
//end dealloc

-(void) P:(unsigned int)n
{
  pthread_mutex_lock(&mutex);
  while(value<n)
    pthread_cond_wait(&cond, &mutex);
  value -= n;
  pthread_mutex_unlock(&mutex);
  pthread_cond_broadcast(&cond);
}
//end P:

-(void) P
{
  [self P:1];
}
//end P

-(void) V:(unsigned int)n
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

-(unsigned int) R
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
-(id) initWithCoder:(NSCoder*)coder
{
  return [self initWithValue:[coder decodeIntForKey:@"value"]];
}

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeInt:[self R] forKey:@"value"];
}

@end
