//
//  NotifyingScrollView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/08/08.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
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
