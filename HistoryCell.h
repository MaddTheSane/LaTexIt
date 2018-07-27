//  HistoryCell.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

#import <Cocoa/Cocoa.h>

//This class is the kind of cell used to display history items in the history drawer
//It may take in account the different fields of an history item (image, date...)

@interface HistoryCell : NSImageCell <NSCopying> {
  NSDateFormatter* dateFormatter;
  NSColor*         backgroundColor;
}

-(void) setBackgroundColor:(NSColor*)color;

@end
