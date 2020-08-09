//  LogTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/03/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

//This NSTableView reports errors at certain lines of the latex source code

#import "LogTableView.h"

//when the user clicks a line, he will be teleported to the error in the body of the latex source,
//in another view of the document window. A notification suits well.
NSString* const ClickErrorLineNotification = @"ClickErrorLineNotification";

@implementation LogTableView

-(instancetype) initWithCoder:(NSCoder*)coder
{
  if ((!(self = [super initWithCoder:coder])))
    return nil;
  self->errorLines = [[NSMutableArray alloc] init];
  return self;
}
//end initWithCoder:

-(void) awakeFromNib
{
  self.delegate = self;
  self.dataSource = self;
}

//updates contents thnaks to the array of error strings
-(void) setErrors:(NSArray*)errors
{
  [errorLines removeAllObjects];
  for(NSString *line in errors)
  {
    NSArray* components = [line componentsSeparatedByString:@":"];
    if (components.count >= 3)
    {
      NSNumber* lineNumber = @([[components objectAtIndex:1] integerValue]);
      NSString* message    = [[components subarrayWithRange:NSMakeRange(2, [components count]-2)]
                                    componentsJoinedByString:@""];
      NSDictionary* dictionary =
        @{@"line": lineNumber, @"message": message};
      [errorLines addObject:dictionary];
    }
    else
    {
      NSRange separator = [line rangeOfString:@"! LaTeX Error:"];
      if (separator.location != NSNotFound)
      {
        NSNumber* lineNumber = @0; //dummy line number error
        NSString* message    = [line substringFromIndex:(separator.location+separator.length)];
        NSDictionary* dictionary =
          @{@"line": lineNumber, @"message": message};
        [errorLines addObject:dictionary];
      }
    }
  }
  [self reloadData];
}

//NSTableViewDataSource protocol
-(NSInteger) numberOfRowsInTableView:(NSTableView*)aTableView
{
  return errorLines.count;
}
//end numberOfRowsInTableView:

-(id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
  id object = errorLines[rowIndex][aTableColumn.identifier];
  //if the line number is equal to 0, do not display it
  if ([aTableColumn.identifier isEqualToString:@"line"] && ![object integerValue])
    object = nil;
  return object;
}

//a quick teleportation to the error if the user double-clicks a line
-(void) mouseDown:(NSEvent*) theEvent
{
  [super mouseDown:theEvent];
  NSInteger row = self.selectedRow;
  if (row >= 0)
  {
    NSNumber* lineError = [self tableView:self objectValueForTableColumn:[self tableColumnWithIdentifier:@"line"] row:row];
    NSString* message = [self tableView:self objectValueForTableColumn:[self tableColumnWithIdentifier:@"message"] row:row];
    [[NSNotificationCenter defaultCenter] postNotificationName:ClickErrorLineNotification object:self
       userInfo:lineError ? @{@"lineError": lineError, @"message": message}
                          : @{@"message": message}];
  }
}

@end
