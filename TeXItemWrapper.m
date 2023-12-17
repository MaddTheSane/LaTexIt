//
//  TeXItemWrapper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/18.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import "TeXItemWrapper.h"

#import "NSObjectExtended.h"

@implementation TeXItemWrapper

-(id) initWithItem:(NSDictionary*)aData
{
  if (!((self = [super init])))
    return nil;
  self->data = [aData copy];
  self->enabled = YES;
  self->checked = YES;
  return self;
}
//end initWithData:

-(void) dealloc
{
  #ifdef ARC_ENABLED
  #else
  [self->data release];
  [self->equation release];
  [super dealloc];
  #endif
}
//end dealloc

-(NSString*) title
{
  NSString* result = [[self->data objectForKey:@"sourceText"] dynamicCastToClass:[NSString class]];
  #ifdef ARC_ENABLED
  return [result copy];
  #else
  return [[result copy] autorelease];
  #endif
}
//end title

@synthesize data;
@synthesize enabled;
@synthesize checked;
@synthesize importState;
@synthesize equation;

@end

