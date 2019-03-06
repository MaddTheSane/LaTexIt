//
//  NSViewExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/04/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "NSViewExtended.h"

#import "Utils.h"

@implementation NSView (Extended)

-(void) centerInSuperviewHorizontally:(BOOL)horizontally vertically:(BOOL)vertically
{
  NSView* superview = self.superview;
  if (superview)
  {
    NSRect superFrame = superview.frame;
    NSRect selfFrame  = self.frame;
    NSPoint newFrameOrigin = NSMakePoint(
      !horizontally ? selfFrame.origin.x : (superFrame.size.width-selfFrame.size.width)/2,
      !vertically   ? selfFrame.origin.y : (superFrame.size.height-selfFrame.size.height)/2);
    [self setFrameOrigin:newFrameOrigin];
  }//end if (superview)
}
//end centerInSuperviewHorizontally:vertically:

@end
