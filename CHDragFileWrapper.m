//
//  CHDragFileWrapper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/11/13.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "CHDragFileWrapper.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation CHDragFileWrapper
@synthesize fileName;
@synthesize uti;

+(instancetype) dragFileWrapperWithFileName:(NSString*)fileName uti:(NSString*)uti
{
  return [[[self class] alloc] initWithFileName:fileName uti:uti];
}
//end dragFileWrapperWithFileName:

-(instancetype) initWithFileName:(NSString*)aFileName uti:(NSString*)aUti
{
  if (!(self = [super init]))
    return nil;
  self->fileName = [aFileName copy];
  self->uti      = [aUti copy];
  return self;
}
//end initWithFileName:

-(NSArray*) writableTypesForPasteboard:(NSPasteboard*)pasteboard
{
  NSArray* result = @[self->uti];
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
