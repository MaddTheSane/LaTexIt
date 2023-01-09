//
//  NSFontExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/07/05.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.

//This file is an extension of the NSFont class

#import "NSFontExtended.h"

#import "NSObjectExtended.h"
#import "Utils.h"

@implementation NSFont (Extended)

+(NSFont*) fontWithData:(NSData*)data
{
  NSFont* result = nil;
  NSError* decodingError = nil;
  result = !data ? nil :
    isMacOS10_13OrAbove() ? [NSKeyedUnarchiver unarchivedObjectOfClass:[NSFont class] fromData:data error:&decodingError] :
    [[NSKeyedUnarchiver unarchiveObjectWithData:data] dynamicCastToClass:[NSFont class]];
  if (decodingError != nil)
    DebugLog(0, @"decoding error : %@", decodingError);
  return result;
}
//end fontWithData:

-(NSData*) data
{
  NSData* result =
    isMacOS10_13OrAbove() ? [NSKeyedArchiver archivedDataWithRootObject:self requiringSecureCoding:YES error:nil] :
    [NSKeyedArchiver archivedDataWithRootObject:self];
  return result;
}
//end data

-(NSString*) displayNameWithPointSize
{
  NSString* result = [NSString stringWithFormat:@"%@ %.1f", [self displayName], [self pointSize]];
  return result;
}
//end displayNameWithPointSize

@end
