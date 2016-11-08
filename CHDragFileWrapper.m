//
//  CHDragFileWrapper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/11/13.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import "CHDragFileWrapper.h"


@implementation CHDragFileWrapper
@synthesize fileName;
@synthesize uti;

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
