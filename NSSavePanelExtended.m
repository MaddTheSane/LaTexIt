//
//  NSSavePanelExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/06/14.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "NSSavePanelExtended.h"

#import "NSObjectExtended.h"


@implementation NSSavePanel (Extended)

-(void) validateVisibleColumns2_helper:(id)aView
{
  if ([aView respondsToSelector:@selector(reloadData)])
    [aView reloadData];
  id subViews = [aView respondsToSelector:@selector(subviews)] ? [aView subviews] : nil;
  NSEnumerator* enumerator = [subViews respondsToSelector:@selector(objectEnumerator)] ?
    [[subViews objectEnumerator] dynamicCastToClass:[NSEnumerator class]] : nil;
  id subView = nil;
  while((subView = [enumerator nextObject]))
    [self validateVisibleColumns2_helper:subView];
}
//end validateVisibleColumns2_helper:

-(void) validateVisibleColumns2
{
  id aContentView = [self respondsToSelector:@selector(contentView)] ? self.contentView : nil;
  [self validateVisibleColumns2_helper:aContentView];
}
//end validateVisibleColumns2

@end
