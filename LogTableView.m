//  LogTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/03/05.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.

//This NSTableView reports errors at certain lines of the latex source code

#import "LogTableView.h"

//when the user clicks a line, he will be teleported to the error in the body of the latex source,
//in another view of the document window. A notification suits well.
NSString* ClickErrorLineNotification = @"ClickErrorLineNotification";

@implementation LogTableView

-(id) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  self->errorLines = [[NSMutableArray alloc] init];
  return self;
}
//end initWithCoder:

-(void) dealloc
{
  [errorLines release];
  [super dealloc];
}

-(void) awakeFromNib
{
  [self setDelegate:(id)self];
  [self setDataSource:(id)self];
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
      NSNumber* lineNumber = [NSNumber numberWithInteger:[[components objectAtIndex:1] integerValue]];
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
        NSNumber* lineNumber = [NSNumber numberWithInteger:0]; //dummy line number error
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
-(NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView
{
  return [errorLines count];
}
//end numberOfRowsInTableView:

-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
  id object = [[errorLines objectAtIndex:rowIndex] objectForKey:[aTableColumn identifier]];
  //if the line number is equal to 0, do not display it
  if ([[aTableColumn identifier] isEqualToString:@"line"] && ![object integerValue])
    object = nil;
  return object;
}

//a quick teleportation to the error if the user double-clicks a line
-(void) mouseDown:(NSEvent*) theEvent
{
  [super mouseDown:theEvent];
  NSInteger row = [self selectedRow];
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
