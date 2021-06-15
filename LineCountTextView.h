//  LineCountTextView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.

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
  NSInteger           lineShift; //the displayed numerotation of the lines may start at a value different from 1
  NSDragOperation     acceptDrag;
  NSInteger           spellCheckerDocumentTag;
  NSUInteger          previousSelectedRangeLocation;
  BOOL                tabKeyInsertsSpacesEnabled;
  NSUInteger          tabKeyInsertsSpacesCount;
  BOOL                editionAutoCompleteOnBackslashEnabled;
  NSString*           spacesString;
  NSUInteger          disableAutoColorChangeLevel;
  
  BOOL                lastCharacterEnablesAutoCompletion;
}

-(void) setAttributedString:(NSAttributedString*)value;//triggers recolouring
-(void) insertText:(id)aString newSelectedRange:(NSRange)selectedRange;

-(LineCountRulerView*) lineCountRulerView;
-(void) setForbiddenLine:(NSUInteger)index forbidden:(BOOL)forbidden; //change status (forbidden or not) of a line
-(void) setLineShift:(NSInteger)aShift; //defines the shift in the displayed line numbers
-(NSInteger) lineShift;
-(NSArray*) lineRanges;
-(NSUInteger) nbLines; //the number of lines in the text
-(void) clearErrors; //remove error markers
-(void) setErrorAtLine:(NSUInteger)lineIndex message:(NSString*)message; //set error markers
-(BOOL) gotoLine:(NSInteger)row;//scroll to visible line <row>

-(void) refreshCheckSpelling;
-(SMLSyntaxColouring*) syntaxColouring;

-(void) restorePreviousSelectedRangeLocation;

//NSTextDelegate
-(void) textDidChange:(NSNotification*)notification;

@end
