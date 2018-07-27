//  LogTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/03/05.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.

//This NSTableView reports errors at certain lines of the latex source code

#import "LogTableView.h"

//when the user clicks a line, he will be teleported to the error in the body of the latex source,
//in another view of the document window. A notification suits well.
NSString* ClickErrorLineNotification = @"ClickErrorLineNotification";

@implementation LogTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if (![super initWithCoder:coder])
    return nil;
  errorLines = [[NSMutableArray alloc] init];
  return self;
}

-(void) dealloc
{
  [errorLines release];
  [super dealloc];
}

-(void) awakeFromNib
{
  [self setDelegate:self];
  [self setDataSource:self];
}

//updates contents thnaks to the array of error strings
-(void) setErrors:(NSArray*)errors
{
  [errorLines removeAllObjects];
  NSEnumerator* lineEnumerator = [errors objectEnumerator];
  NSString* line = [lineEnumerator nextObject];
  while(line)
  {
    NSArray* components = [line componentsSeparatedByString:@":"];
    if ([components count] >= 3)
    {
      NSNumber* lineNumber = [NSNumber numberWithInt:[[components objectAtIndex:1] intValue]];
      NSString* message    = [[components subarrayWithRange:NSMakeRange(2, [components count]-2)]
                                    componentsJoinedByString:@""];
      NSDictionary* dictionary =
        [NSDictionary dictionaryWithObjectsAndKeys:lineNumber, @"line", message, @"message", nil];
      [errorLines addObject:dictionary];
    }
    else
    {
      NSRange separator = [line rangeOfString:@"! LaTeX Error:"];
      if (separator.location != NSNotFound)
      {
        NSNumber* lineNumber = [NSNumber numberWithInt:0]; //dummy line number error
        NSString* message    = [line substringFromIndex:(separator.location+separator.length)];
        NSDictionary* dictionary =
          [NSDictionary dictionaryWithObjectsAndKeys:lineNumber, @"line", message, @"message", nil];
        [errorLines addObject:dictionary];
      }
    }
    line = [lineEnumerator nextObject];
  }
  [self reloadData];
}

//NSTableViewDataSource protocol
-(int) numberOfRowsInTableView:(NSTableView *)aTableView
{
  return [errorLines count];
}

-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  id object = [[errorLines objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
  //if the line number is equal to 0, do not display it
  if ([[aTableColumn identifier] isEqualToString:@"line"] && ![object intValue])
    object = nil;
  return object;
}

//a quick teleportation to the error if the user double-clicks a line
-(void) mouseDown:(NSEvent*) theEvent
{
  [super mouseDown:theEvent];
  int row = [self selectedRow];
  if (row >= 0)
  {
    NSNumber* lineError = [self tableView:self objectValueForTableColumn:[self tableColumnWithIdentifier:@"line"] row:row];
    NSString* message = [self tableView:self objectValueForTableColumn:[self tableColumnWithIdentifier:@"message"] row:row];
    [[NSNotificationCenter defaultCenter] postNotificationName:ClickErrorLineNotification object:self
       userInfo:lineError ? [NSDictionary dictionaryWithObjectsAndKeys:lineError, @"lineError", message, @"message", nil]
                          : [NSDictionary dictionaryWithObjectsAndKeys:message, @"message", nil]];
  }
}

@end
