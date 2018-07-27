//  LogTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This NSTableView reports errors at certain lines of the latex source code

#import <Cocoa/Cocoa.h>

//when the user clicks a line, he will be teleported to the error in the body of the latex source,
//in another view of the document window. A notification suits well.
extern NSString* ClickErrorLineNotification;

@interface LogTableView : NSTableView {
  NSMutableArray* errorLines;//the lines where the errors are located
}

//updates contents thnaks to the array of error strings
-(void) setErrors:(NSArray*)errors;
@end
