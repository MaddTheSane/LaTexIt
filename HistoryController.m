//
//  HistoryController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "HistoryController.h"
#import "HistoryManager.h"

#import "Utils.h"

@implementation HistoryController

-(id) initWithContent:(id)content
{
  if ((!(self = [super initWithContent:content])))
    return nil;
  if ([self respondsToSelector:@selector(setAutomaticallyRearrangesObjects:)])
    [self setValue:[NSNumber numberWithBool:YES] forKey:@"automaticallyRearrangesObjects"];
  return self;
}
//end initWithContent:

-(void) addObject:(id)object
{
  [super addObject:object];
  if (!isMacOS10_5OrAbove())
    [self rearrangeObjects];
}
//end addObject:

-(void) removeObject:(id)object
{
  [super removeObject:object];
}
//end removeObject:

-(void) addObjects:(NSArray*)objects
{
  [super addObjects:objects];
  if (!isMacOS10_5OrAbove())
    [self rearrangeObjects];
}
//end addObjects:

-(void) removeObjects:(NSArray*)objects
{
  [super removeObjects:objects];
}
//end removeObjects:

@end
