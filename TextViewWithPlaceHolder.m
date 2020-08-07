//
//  TextViewWithPlaceHolder.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/02/13.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "TextViewWithPlaceHolder.h"

#import "NSObjectExtended.h"

@implementation TextViewWithPlaceHolder


-(void) dealloc
{
  [self->placeHolder release];
  [self->attributedPlaceHolder release];
  [super dealloc];
}
//end dealloc

-(NSString*) placeHolder
{
  return [[self->placeHolder copy] autorelease];
}
//end placeHolder

-(void) setPlaceHolder:(NSString*)value
{
  if (value != self->placeHolder)
  {
    [self->placeHolder release];
    self->placeHolder = [value copy];
    NSColor *textColor = [NSColor disabledControlTextColor];
    NSDictionary *attributes = @{NSFontAttributeName:[NSFont controlContentFontOfSize:0],NSForegroundColorAttributeName:textColor};
    [self->attributedPlaceHolder release];
    self->attributedPlaceHolder = !self->placeHolder ? nil :
      [[NSAttributedString alloc] initWithString:self->placeHolder attributes:attributes];
  }//end if (value != self->placeHolder)
}
//end setPlaceHolder:

-(BOOL) becomeFirstResponder
{
  BOOL result = [self isEditable] && [super becomeFirstResponder];
  [self setNeedsDisplay:YES];
  return result;
}
//end becomeFirstResponder

-(BOOL) resignFirstResponder
{
  [self setNeedsDisplay:YES];
  return [super resignFirstResponder];
}
//end resignFirstResponder

-(void) drawRect:(NSRect)rect
{
  [super drawRect:rect];
  if (self->placeHolder && ![self->placeHolder isEqualToString:@""] && (self != [[self window]
firstResponder] && [[[self textStorage] string] isEqualToString:@""]))
  {
    NSClipView* clipView = [[self superview] dynamicCastToClass:[NSClipView class]];
    [self->attributedPlaceHolder drawInRect:!clipView ? [self bounds] : [clipView documentVisibleRect]];
  }
}
//end drawRect:

@end
