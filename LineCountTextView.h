//  LineCountTextView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.

//The LineCountTextView is an NSTextView that I have associated with a LineCountRulerView
//This ruler will display the line numbers
//Another feature is the ability to disable the edition of some lines
//Another feature is the ability to add error markers at some lines

#import <Cocoa/Cocoa.h>

extern NSString* LineCountDidChangeNotification;
extern NSString* FontDidChangeNotification;
extern NSString* LineCountTextViewDidReceivePDFDataNotification;

@class LineCountRulerView;
@class SMLSyntaxColouring;

@interface LineCountTextView : NSTextView {
  SMLSyntaxColouring* syntaxColouring;
  NSMutableArray*     lineRanges;      //contains the ranges of each line
  NSMutableSet*       forbiddenLines;  //lines that cannot be edited
  LineCountRulerView* lineCountRulerView;
  int                 lineShift; //the displayed numerotation of the lines may start at a value different from 1
  NSDragOperation     acceptDrag;
  BOOL                spellCheckerHasBeenInitialized;
  NSUInteger          previousSelectedRangeLocation;
  BOOL                tabKeyInsertsSpacesEnabled;
  NSUInteger          tabKeyInsertsSpacesCount;
  NSString*           spacesString;
}

-(void) setAttributedString:(NSAttributedString*)value;//triggers recolouring

-(LineCountRulerView*) lineCountRulerView;
-(void) setForbiddenLine:(unsigned int)index forbidden:(BOOL)forbidden; //change status (forbidden or not) of a line
-(void) setLineShift:(int)aShift; //defines the shift in the displayed line numbers
-(int)  lineShift;
-(NSArray*) lineRanges;
-(unsigned int) nbLines; //the number of lines in the text
-(void) clearErrors; //remove error markers
-(void) setErrorAtLine:(unsigned int)lineIndex message:(NSString*)message; //set error markers
-(BOOL) gotoLine:(int)row;//scroll to visible line <row>

-(SMLSyntaxColouring*) syntaxColouring;

-(void) restorePreviousSelectedRangeLocation;

//NSTextDelegate
-(void) textDidChange:(NSNotification*)notification;

@end
