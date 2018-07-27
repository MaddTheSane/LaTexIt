//
//  NotifyingScrollView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/08/08.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import "NotifyingScrollView.h"

NSString* NotifyingScrollViewDidScrollNotification = @"NotifyingScrollViewDidScrollNotification";

@implementation NotifyingScrollView

-(void) reflectScrolledClipView:(NSClipView *)aClipView
{
  [super reflectScrolledClipView:aClipView];
  [[NSNotificationCenter defaultCenter] postNotificationName:NotifyingScrollViewDidScrollNotification object:self];
}
//end reflectScrolledClipView:

@end
