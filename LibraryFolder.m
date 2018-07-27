//
//  LibraryFolder.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/07/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import "LibraryFolder.h"

#import "LatexitEquation.h"
#import "LibraryGroupItem.h"

@implementation LibraryFolder

-(void) encodeWithCoder:(NSCoder*)coder
{
}
//end encodeWithCoder:

-(id) initWithCoder:(NSCoder*)coder
{
  id oldSelf = [super init];
  self = [[LibraryGroupItem alloc] initWithCoder:coder];
  [oldSelf autorelease];
  oldSelf = nil;
  if (!self)
    return nil;
  [(LibraryGroupItem*)self setExpanded:[[coder decodeObjectForKey:@"isExpanded"] boolValue]];
  NSArray* children = [[coder decodeObjectForKey:@"children"] retain];
  [children makeObjectsPerformSelector:@selector(setParent:) withObject:self];
  return self;
}
//end initWithCoder:

@end
