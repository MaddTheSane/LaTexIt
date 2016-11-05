//
//  Semaphore.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 09/10/06.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#include <pthread.h>

@interface Semaphore : NSObject <NSCoding> {
  pthread_condattr_t    cond_attr;
  pthread_cond_t        cond;
  pthread_mutexattr_t   mutex_attr;
  pthread_mutex_t       mutex;
  volatile unsigned int value;
}

-(instancetype) initWithValue:(unsigned int)initialValue NS_DESIGNATED_INITIALIZER; //designated initializer
-(instancetype) init;///<init with value 0

-(void) P:(unsigned int)n;
-(void) V:(unsigned int)n;
-(void) P;///<P with 1
-(void) V;///<V with 1
-(unsigned int) R;
-(void)         Z;

//NSCoding protocol
-(instancetype)   initWithCoder:(NSCoder*)coder;
-(void) encodeWithCoder:(NSCoder*)coder;

@end
