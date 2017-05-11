//
//  HistoryController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import "HistoryController.h"
#import "HistoryManager.h"

#import "HistoryItem.h"
#import "LatexitEquation.h"
#import "NSObjectExtended.h"
#import "Utils.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation HistoryController

-(id) initWithContent:(id)content
{
  if ((!(self = [super initWithContent:content])))
    return nil;
  /*if ([self respondsToSelector:@selector(setAutomaticallyRearrangesObjects:)])
    [self setValue:[NSNumber numberWithBool:YES] forKey:@"automaticallyRearrangesObjects"];*/
  [self addObserver:self forKeyPath:NSContentBinding options:0 context:0];
  return self;
}
//end initWithContent:

-(void) dealloc
{
  [self removeObserver:self forKeyPath:NSContentBinding];
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

-(BOOL) automaticallyRearrangesObjects
{
  BOOL result = NO;
  result = [super automaticallyRearrangesObjects];
  return result;
}
//end automaticallyRearrangesObjects

-(void) setAutomaticallyRearrangesObjects:(BOOL)value
{
  [super setAutomaticallyRearrangesObjects:value];
}
//end setAutomaticallyRearrangesObjects:

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
