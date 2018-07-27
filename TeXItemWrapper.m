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

-(id) initWithItem:(NSDictionary*)aData
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
  NSString* result = [[self->data objectForKey:@"sourceText"] dynamicCastToClass:[NSString class]];
  return [result copy];
}
//end title

-(NSDictionary*) data
{
  return self->data;
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
  return self->equation;
}
//end equation

-(void) setEquation:(LatexitEquation*)value
{
  if (value != self->equation)
  {
    [self willChangeValueForKey:@"equation"];
    self->equation = value;
    [self didChangeValueForKey:@"equation"];
  }//end if (value != self->equation)
}
//end setEquation:

@end

