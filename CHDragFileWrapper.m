//
//  CHDragFileWrapper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/11/13.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "CHDragFileWrapper.h"


@implementation CHDragFileWrapper

+(id) dragFileWrapperWithFileName:(NSString*)fileName uti:(NSString*)uti
{
  #ifdef ARC_ENABLED
  return [[[self class] alloc] initWithFileName:fileName uti:uti];
  #else
  return [[[[self class] alloc] initWithFileName:fileName uti:uti] autorelease];
  #endif
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
  #ifdef ARC_ENABLED
  #else
  [self->fileName release];
  [self->uti release];
  [super dealloc];
  #endif
}
//end dealloc

-(NSString*) fileName
{
  #ifdef ARC_ENABLED
  NSString* result = [self->fileName copy];
  #else
  NSString* result = [[self->fileName copy] autorelease];
  #endif
  return result;
}
//end fileName

-(NSString*) uti
{
  #ifdef ARC_ENABLED
  NSString* result = [self->uti copy];
  #else
  NSString* result = [[self->uti copy] autorelease];
  #endif
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
  NSURL* result = !self->fileName ? nil : [NSURL fileURLWithPath:self->fileName];
  return result;
}
//end pasteboardPropertyListForType:

@end
