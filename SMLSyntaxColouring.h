// Smultron version 1.2.5, 2005-05-08
// Written by Peter Borg, pgw3@mac.com
// Copyright (C) 2004-2005 Peter Borg
// For the latest version of the code go to http://smultron.sourceforge.net
// Released under GNU General Public License, http://www.gnu.org/copyleft/gpl.html

//Note by Pierre Chatelier : I have modified some parts of the code, the original code can be found as pointed above

#import <Cocoa/Cocoa.h>
//@class SMLTextView;

@interface SMLSyntaxColouring : NSObject {
	NSUndoManager *undoManager;
	NSTextView *textView;
	NSLayoutManager *layoutManager;
	NSTimer *startPageRecolourTimer;
	NSTimer *startCompleteRecolourTimer;
	NSTimer *autocompleteWordsTimer;
	NSUserDefaults *userDefaults;
	NSUInteger currentYOfSelectedCharacter;
	NSUInteger lastYOfSelectedCharacter;
	NSUInteger currentYOfLastCharacterInLine;
	NSUInteger lastYOfLastCharacterInLine;
	NSUInteger currentYOfLastCharacter;
	NSUInteger lastYOfLastCharacter;
	NSUInteger lastCursorLocation;
	
	NSCharacterSet *letterCharacterSet;
	NSCharacterSet *keywordStartCharacterSet;
	NSCharacterSet *keywordEndCharacterSet;
	
	NSDictionary *commandsColour;
	NSDictionary *commentsColour;
	NSDictionary *instructionsColour;
	NSDictionary *keywordsColour;
	NSDictionary *stringsColour;
	NSDictionary *variablesColour;
	
	NSDictionary *highlightColour;
	
	NSEnumerator *wordEnumerator;
	NSSet *keywords;
	NSArray *autocompleteWords;
	NSArray *keywordsAndAutocompleteWords;
	BOOL keywordsCaseSensitive;
	BOOL recolourKeywordIfAlreadyColoured;
	NSString *beginCommand;
	NSString *endCommand;
	NSString *beginInstruction;
	NSString *endInstruction;
	NSCharacterSet *beginVariable;
	NSCharacterSet *endVariable;
	NSString *firstString;
	unichar firstStringUnichar;
	NSString *secondString;
	unichar secondStringUnichar;
	NSString *firstSingleLineComment;
	NSString *secondSingleLineComment;
	NSString *beginFirstMultiLineComment;
	NSString *endFirstMultiLineComment;
	NSString *beginSecondMultiLineComment;
	NSString *endSecondMultiLineComment;
	NSString *syntaxDefinitionName;
	
	NSString *completeString;
	NSString *searchString;
	NSScanner *scanner;
	NSScanner *completeDocumentScanner;
	NSUInteger beginning;
	NSUInteger end;
	NSUInteger endOfLine;
	NSUInteger index;
	NSUInteger length;
	NSUInteger searchStringLength;
	NSUInteger commandLocation;
	NSUInteger skipEndCommand;
	NSUInteger beginLocationInMultiLine;
	NSUInteger endLocationInMultiLine;
	NSUInteger searchSyntaxLength;
	NSUInteger rangeLocation;
	NSRange rangeOfLine;
	NSString *keyword;
	BOOL shouldOnlyColourTillTheEndOfLine;
	unichar commandCharacterTest;
	unichar beginCommandCharacter;
	unichar endCommandCharacter;
	BOOL shouldColourMultiLineStrings;
	BOOL foundMatch;
	NSUInteger completeStringLength;
	unichar characterToCheck;
	NSRange editedRange;
	NSUInteger cursorLocation;
	NSInteger differenceBetweenLastAndPresent;
	NSUInteger skipMatchingBrace;
	NSRect visibleRect;
	NSRange visibleRange;
	NSUInteger beginningOfFirstVisibleLine;
	NSUInteger endOfLastVisibleLine;
	NSRange selectedRange;
	NSUInteger stringLength;
	NSString *keywordTestString;
	NSRange searchRange;
	
	NSTextContainer *textContainer;
}

+(NSArray *)syntaxDefinitionsArray;

-(instancetype) initWithTextView:(NSTextView*)aTextView NS_DESIGNATED_INITIALIZER;

-(void) setColours;
-(void) setSyntaxDefinitionsForExtension:(NSString *)extension;
-(void) recolourCompleteDocument;
-(void) recolourRange:(NSRange)range completeRecolour:(BOOL)completeRecolour;
-(void) removeColoursFromRange:(NSRange)range;
-(void) removeAllColours;
-(void) removeAllTimers;

@property (strong) NSEnumerator *wordEnumerator;

@property (copy) NSSet<NSString*> *keywords;
@property (copy) NSArray<NSString*> *autocompleteWords;
@property (copy) NSArray<NSString*> *keywordsAndAutocompleteWords;

@property  BOOL recolourKeywordIfAlreadyColoured;

@property  BOOL keywordsCaseSensitive;

-(void) setBeginCommand:(NSString *)newBeginCommand;
-(void) setEndCommand:(NSString *)newEndCommand;
-(void) setBeginInstruction:(NSString *)newBeginInstruction;
-(void) setEndInstruction:(NSString *)newEndInstruction;
-(void) setBeginVariable:(NSCharacterSet *)newBeginVariable;
-(void) setEndVariable:(NSCharacterSet *)newEndVariable;
-(void) setFirstString:(NSString *)newFirstString;
-(void) setFirstStringUnichar:(unichar)newFirstStringUnichar;
-(void) setSecondString:(NSString *)newSecondString;
-(void) setSecondStringUnichar:(unichar)newSecondStringUnichar;
-(void) setFirstSingleLineComment:(NSString *)newFirstSingleLineComment;
-(void) setSecondSingleLineComment:(NSString *)newSecondSingleLineComment;
-(void) setBeginFirstMultiLineComment:(NSString *)newBeginFirstMultiLineComment;
-(void) setEndFirstMultiLineComment:(NSString *)newEndFirstMultiLineComment;
-(void) setBeginSecondMultiLineComment:(NSString *)newBeginSecondMultiLineComment;
-(void) setEndSecondMultiLineComment:(NSString *)newEndSecondMultiLineComment;

@property (readonly, strong) NSUndoManager *undoManager;
@property (readonly, copy) NSDictionary *highlightColour;

@property (copy) NSString *syntaxDefinitionName;

-(NSString*) guessSyntaxDefinitionFromFirstLine:(NSString *)firstLine;

-(void) pageRecolour;

//NSTextDelegate
-(void)textDidChange:(NSNotification*)notification;

@end
