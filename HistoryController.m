//
//  HistoryController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/09.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import "HistoryController.h"
#import "HistoryManager.h"

#import "HistoryItem.h"
#import "LatexitEquation.h"
#import "NSObjectExtended.h"
#import "Utils.h"

@implementation HistoryController

-(id) initWithContent:(id)content
{
  if ((!(self = [super initWithContent:content])))
    return nil;
  /*if ([self respondsToSelector:@selector(setAutomaticallyRearrangesObjects:)])
    [self setValue:@(YES) forKey:@"automaticallyRearrangesObjects"];*/
  [self addObserver:self forKeyPath:NSContentBinding options:0 context:0];
  return self;
}
//end initWithContent:

-(void) dealloc
{
  [self removeObserver:self forKeyPath:NSContentBinding];
  #ifdef ARC_ENABLED
  #else
  [super dealloc];
  #endif
}
//end dealloc

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:NSContentBinding])
  {
    if (![self automaticallyRearrangesObjects])
      [self rearrangeObjects];
  }//end if ([keyPath isEqualToString:NSContentBinding])
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) addObject:(id)object
{
  [super addObject:object];
  if (![self automaticallyRearrangesObjects])
    [self rearrangeObjects];
}
//end addObject:

-(void) removeObject:(id)object
{
  [super removeObject:object];
  if (![self automaticallyRearrangesObjects])
    [self rearrangeObjects];
}
//end removeObject:

-(void) addObjects:(NSArray*)objects
{
  [super addObjects:objects];
  if (![self automaticallyRearrangesObjects])
    [self rearrangeObjects];
}
//end addObjects:

-(void) removeObjects:(NSArray*)objects
{
  [super removeObjects:objects];
  if (![self automaticallyRearrangesObjects])
    [self rearrangeObjects];
}
//end removeObjects:

@end
