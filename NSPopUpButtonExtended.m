//
//  NSPopUpButton.m
//  LaTeXiT-panther
//
//  Created by Pierre Chatelier on 27/12/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import "NSPopUpButtonExtended.h"


@implementation NSPopUpButton (Extended)

#ifdef PANTHER
-(void) selectItemWithTag:(int)tag
{
  [self selectItemAtIndex:[self indexOfItemWithTag:tag]];
}
#endif

@end
