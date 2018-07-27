//  NSTaskExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSTask class

#import "NSTaskExtended.h"

@implementation NSTask (Extended)

//returns a string containing the equivalent command line of the NSTask
-(NSString*) commandLine
{
  NSMutableString* commandLine = [NSMutableString stringWithFormat:@"%@", [self launchPath]];
  NSEnumerator* enumerator = [[self arguments] objectEnumerator];
  NSString* argument = [enumerator nextObject];
  while(argument)
  {
    [commandLine appendString:@" "];
    [commandLine appendString:argument];
    argument = [enumerator nextObject];
  }
  return commandLine;
}

@end
