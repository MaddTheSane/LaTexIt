//
//  NSUserDefaultsControllerExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "NSUserDefaultsControllerExtended.h"


@implementation NSUserDefaultsController (Extended)

+(NSString*) adaptedKeyPath:(NSString*)keyPath
{
  NSString* result = [@"values." stringByAppendingString:keyPath];
  return result;
}
//end adaptedKeyPath:

-(NSString*) adaptedKeyPath:(NSString*)keyPath
{
  NSString* result = [[self class] adaptedKeyPath:keyPath];
  return result;
}
//end adaptedKeyPath:

@end
