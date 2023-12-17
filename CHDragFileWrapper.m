//
//  CHDragFileWrapper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/11/13.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
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
  if (self = [super init]) {
    self->fileName = [aFileName copy];
    self->uti      = [aUti copy];
  }
  return self;
}
//end initWithFileName:

#ifndef ARC_ENABLED
-(void) dealloc
{
  [self->fileName release];
  [self->uti release];
  [super dealloc];
}
//end dealloc
#endif

@synthesize fileName;
@synthesize uti;

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
