//
//  CHDragFileWrapper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/11/13.
//  Copyright 2014 LAIC. All rights reserved.
//

#import "CHDragFileWrapper.h"


@implementation CHDragFileWrapper

+(id) dragFileWrapperWithFileName:(NSString*)fileName uti:(NSString*)uti
{
  return [[[[self class] alloc] initWithFileName:fileName uti:uti] autorelease];
}
//end dragFileWrapperWithFileName:

-(id) initWithFileName:(NSString*)aFileName uti:(NSString*)aUti
{
  if (!(self = [super init]))
    return nil;
  self->fileName = [aFileName copy];
  self->uti      = [aUti copy];
  return self;
}
//end initWithFileName:

-(void) dealloc
{
  [self->fileName release];
  [self->uti release];
  [super dealloc];
}
//end dealloc

-(NSString*) fileName
{
  NSString* result = [[self->fileName copy] autorelease];
  return result;
}
//end fileName

-(NSString*) uti
{
  NSString* result = [[self->uti copy] autorelease];
  return result;
}
//end uti

-(NSArray*) writableTypesForPasteboard:(NSPasteboard*)pasteboard
{
  NSArray* result = [NSArray arrayWithObjects:self->uti, nil];
  return result;
}
//end writableTypesForPasteboard:

-(id) pasteboardPropertyListForType:(NSString*)type
{
  NSURL* result = [NSURL fileURLWithPath:self->fileName];
  return result;
}
//end pasteboardPropertyListForType:

@end
