//  LineCountTextView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The LineCountTextView is an NSTextView that I have associated with a LineCountRulerView
//This ruler will display the line numbers
//Another feature is the ability to disable the edition of some lines
//Another feature is the ability to add error markers at some lines

#import <Cocoa/Cocoa.h>

extern NSString* LineCountDidChangeNotification;
extern NSString* FontDidChangeNotification;

@class LineCountRulerView;

@interface LineCountTextView : NSTextView {
  NSMutableArray* lineRanges;      //contains the ranges of each line
  NSMutableSet*   forbiddenLines;  //lines that cannot be edited
  LineCountRulerView* lineCountRulerView;
  int lineShift; //the displayed numerotation of the lines may start at a value different from 1
}

-(void) setForbiddenLine:(unsigned int)index forbidden:(BOOL)forbidden; //change status (forbidden or not) of a line
-(void) setLineShift:(int)aShift; //defines the shift in the displayed line numbers
-(int)  lineShift;
-(NSArray*) lineRanges;
-(unsigned int) nbLines; //the number of lines in the text
-(void) clearErrors; //remove error markers
-(void) setErrorAtLine:(unsigned int)lineIndex message:(NSString*)message; //set error markers
-(void) gotoLine:(int)row;//scroll to visible line <row>

@end
