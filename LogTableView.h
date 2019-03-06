//  LogTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/03/05.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.

//This NSTableView reports errors at certain lines of the latex source code

#import <Cocoa/Cocoa.h>

//when the user clicks a line, he will be teleported to the error in the body of the latex source,
//in another view of the document window. A notification suits well.
extern NSNotificationName const ClickErrorLineNotification;

@interface LogTableView : NSTableView <NSTableViewDataSource, NSTableViewDelegate> {
  NSMutableArray* errorLines;//the lines where the errors are located
}

//! updates contents thanks to the array of error strings
-(void) setErrors:(NSArray<NSString*>*)errors;

//NSTableViewDataSource
-(id) tableView:(NSTableView*)aTableView objectValueForTableColumn:(NSTableColumn*)aTableColumn row:(NSInteger)rowIndex;

@end
