//
//  TeXItemWrapper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/18.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
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

-(NSDictionary*) data
{
  #ifdef ARC_ENABLED
  return self->data;
  #else
  return [[self->data retain] autorelease];
  #endif
}
//end data

-(BOOL) enabled
{
  return self->enabled;
}
//end enabled

-(void) setEnabled:(BOOL)value
{
  if (value != self->enabled)
  {
    [self willChangeValueForKey:@"enabled"];
    self->enabled = value;
    [self didChangeValueForKey:@"enabled"];
  }//end if (value != self->enabled)
}
//end setEnabled:

-(BOOL) checked
{
  return self->checked;
}
//end checked

-(void) setChecked:(BOOL)value
{
  if (value != self->checked)
  {
    [self willChangeValueForKey:@"checked"];
    self->checked = value;
    [self didChangeValueForKey:@"checked"];
  }//end if (value != self->checked)
}
//end setChecked:

-(NSInteger) importState
{
  return self->importState;
}
//end importState

-(void) setImportState:(NSInteger)value
{
  if (value != self->importState)
  {
    [self willChangeValueForKey:@"importState"];
    self->importState = value;
    [self didChangeValueForKey:@"importState"];
  }//end if (value != self->importState)
}
//end setImportState:

-(LatexitEquation*) equation
{
  #ifdef ARC_ENABLED
  return self->equation;
  #else
  return [[self->equation retain] autorelease];
  #endif
}
//end equation

-(void) setEquation:(LatexitEquation*)value
{
  if (value != self->equation)
  {
    [self willChangeValueForKey:@"equation"];
    #ifdef ARC_ENABLED
    self->equation = value;
    #else
    [self->equation release];
    self->equation = [value retain];
    #endif
    [self didChangeValueForKey:@"equation"];
  }//end if (value != self->equation)
}
//end setEquation:

@end

