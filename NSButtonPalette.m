//
//  NSButtonPalette.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/10.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "NSButtonPalette.h"


@implementation NSButtonPalette
@synthesize exclusive = isExclusive;
@synthesize delegate;

-(instancetype) init
{
  if (!(self = [super init]))
    return nil;
  self->buttons = [[NSMutableArray alloc] init];
  return self;
}
//end init

-(void) add:(NSButton*)button
{
  [self->buttons addObject:button];
  [button addObserver:self forKeyPath:@"state" options:0 context:nil];
}
//end add:

-(void) remove:(NSButton*)button;
{
  [self->buttons removeObject:button];
  [button removeObserver:self forKeyPath:@"state"];
}
//end remove:

-(NSButton*) buttonWithTag:(NSInteger)tag
{
  NSButton* result = nil;
  NSEnumerator* enumerator = [self->buttons objectEnumerator];
  NSButton* button = nil;
  while(!result && ((button = [enumerator nextObject])))
  {
    if (button.tag == tag)
      result = button;
  }
  //end for each button
  return result;
}
//end buttonWithTag:

-(NSButton*) buttonWithState:(NSInteger)state
{
  NSButton* result = nil;
  NSEnumerator* enumerator = [buttons objectEnumerator];
  NSButton* button = nil;
  while(!result && ((button = [enumerator nextObject])))
  {
    if (button.state == state)
      result = button;
  }
  //end for each button
  return result;
}
//end buttonWithState:

-(NSInteger) selectedTag
{
  NSInteger result = 0;
  for(NSButton* button in buttons)
  {
    if (button.state == NSOnState)
    {
      result = button.tag;
      break;
    }//end if ([button state] == NSOnState)
  }//end for each button
  return result;
}
//end selectedTag

-(void) setSelectedTag:(NSInteger)tag
{
  NSEnumerator* enumerator = [self->buttons objectEnumerator];
  NSButton* button = nil;
  while((button = [enumerator nextObject]))
  {
    button.state = (button.tag == tag) ? NSOnState : NSOffState;
  }//end for each button
}
//end setSelectedTag

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  if ([keyPath isEqualToString:@"state"] && [self->buttons containsObject:object])
  {
    if (isExclusive && (((NSButton*)object).state == NSOnState))
    {
      NSUInteger count = self->buttons.count;
      while(count--)
      {
        NSButton* button = self->buttons[count];
        if (button != object)
          button.state = NSOffState;
      }//end for each button
    }//end if (self->isExclusive && ([object state] == NSOnState))
    if ([delegate respondsToSelector:@selector(buttonPalette:buttonStateChanged:)])
      [delegate buttonPalette:self buttonStateChanged:object];
  }//end if ([keyPath isEqualToString:@"state"] && [self->buttons containsObject:object])
}
//end observeValueForKeyPath:ofObject:change:context:

-(void) buttonPalette:(NSButtonPalette*)buttonPalette buttonStateChanged:(NSButton*)button
{
}
//end buttonPalette:buttonStateChanged:

@end
