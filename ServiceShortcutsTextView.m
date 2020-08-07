//
//  ServiceShortcutsTextView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/12/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//This sub-class is a textfield that may catch keyboard shortcuts and display them.
//Note that it inserts Command and Shift because it is used for Service shortcut.

#import "ServiceShortcutsTextView.h"

@implementation ServiceShortcutsTextView

-(id) initWithFrame:(NSRect)frame
{
  if ((!(self = [super initWithFrame:frame])))
    return nil;
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:)
                                        name:NSTextDidChangeNotification object:self];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidEndEditing:)
                                        name:NSTextDidEndEditingNotification object:self];
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super dealloc];
}

-(BOOL) performKeyEquivalent:(NSEvent*)event
{
  NSString* string = [[event charactersIgnoringModifiers] uppercaseString];
  
  const unichar lastCharacter = (string && ![string isEqualToString:@""]) ? [string characterAtIndex:[string length]-1] : '\0';
  const unichar shift = 0x21e7;
  const unichar command = 0x2318;
  const unichar tab[] = {shift, command, lastCharacter};
  
  //if the character is not a letter, do not display "shift"
  NSInteger begin = [[NSCharacterSet letterCharacterSet] characterIsMember:lastCharacter] ? 0 : 1;

  string = lastCharacter ? [NSString stringWithCharacters:tab+begin length:3-begin] : @"";
  [self setString:string];
  return YES;
}

-(void) textDidChange:(NSNotification*)aNotification
{
  NSTextView* textView = [aNotification object];
  NSString* string = [[textView string] uppercaseString];
  
  const unichar lastCharacter = (string && ![string isEqualToString:@""]) ? [string characterAtIndex:[string length]-1] : '\0';
  const unichar shift = 0x21e7;
  const unichar command = 0x2318;
  const unichar tab[] = {shift, command, lastCharacter};
  
  //if the character is not a letter, do not display "shift"
  NSInteger begin = [[NSCharacterSet letterCharacterSet] characterIsMember:lastCharacter] ? 0 : 1;

  [textView setString:lastCharacter ? [NSString stringWithCharacters:tab+begin length:3-begin] : @""];
}

-(void) textDidEndEditing:(NSNotification *)aNotification
{
  NSString* string = [self string];
  const unichar lastCharacter = (string && ![string isEqualToString:@""]) ? [string characterAtIndex:[string length]-1] : '\0';
  if (![[NSCharacterSet alphanumericCharacterSet] characterIsMember:lastCharacter] &&
      ![[NSCharacterSet punctuationCharacterSet] characterIsMember:lastCharacter])
    [self setString:@""];
}

-(void) deleteBackward:(id)sender
{
  [self setString:@""];
}

-(void) cancelOperation:(id)sender
{
 [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidEndEditingNotification object:self];
}

-(void) keyDown:(NSEvent*)event
{
  NSString* characters = [event charactersIgnoringModifiers];
  if (![characters isEqualToString:@""] && ([characters characterAtIndex:0] == 13)) //return
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidEndEditingNotification object:self];
  else
    [super keyDown:event];
}

@end
