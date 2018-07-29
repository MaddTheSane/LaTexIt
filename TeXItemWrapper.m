//
//  TeXItemWrapper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/18.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "TeXItemWrapper.h"

#import "NSObjectExtended.h"
#import "LatexitEquation.h"

@implementation TeXItemWrapper
@synthesize importState;
@synthesize equation;
@synthesize enabled;
@synthesize checked;
@synthesize data;

-(instancetype) initWithItem:(NSDictionary*)aData
{
  if (!(([super init])))
    return nil;
  self->data = [aData copy];
  self->enabled = YES;
  self->checked = YES;
  return self;
}
//end initWithData:

-(NSString*) title
{
  NSString* result = [self->data[@"sourceText"] dynamicCastToClass:[NSString class]];
  return [result copy];
}
//end title

@end

