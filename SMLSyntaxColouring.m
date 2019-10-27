// SMLTextView delegate

// Smultron version 1.2.5, 2005-05-08
// Written by Peter Borg, pgw3@mac.com
// Copyright (C) 2004-2005 Peter Borg
// For the latest version of the code go to http://smultron.sourceforge.net
// Released under GNU General Public License, http://www.gnu.org/copyleft/gpl.html

//Note by Pierre Chatelier : I have modified some parts of the code, the original code can be found as pointed above

#import "SMLSyntaxColouring.h"

#import "NSColorExtended.h"
#import "PreferencesController.h"

#import "Utils.h"

@implementation SMLSyntaxColouring

static NSArray *syntaxDefinitionsArray;

+(void)initialize
{
	if (self == [SMLSyntaxColouring class]) {
		NSMutableArray *syntaxDefinitionsStandardArray = [[NSMutableArray alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"SyntaxDefinitions" ofType:@"plist"]];
   NSArray* libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask , YES);
   NSString* libraryPath = [libraryPaths count] ? [libraryPaths objectAtIndex:0] : nil;
		NSString *path = !libraryPaths ? nil : [[[libraryPath stringByAppendingPathComponent:@"Application Support"] stringByAppendingPathComponent:@"Smultron"] stringByAppendingPathComponent:@"SyntaxDefinitions.plist"];
		if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
			NSArray *syntaxDefinitionsUserArray = [[NSMutableArray alloc] initWithContentsOfFile:path];
			[syntaxDefinitionsStandardArray addObjectsFromArray:syntaxDefinitionsUserArray];
			[syntaxDefinitionsUserArray release];
		}
		NSMutableArray *temporaryArray = [[NSMutableArray alloc] initWithArray:[syntaxDefinitionsStandardArray sortedArrayUsingSelector:@selector(sortByName:)]];
		NSArray *keys = [NSArray arrayWithObjects:@"name", @"file", @"extensions", nil];
		NSDictionary *standard = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"Standard", @"standard", [NSArray arrayWithObject:[NSString string]], nil] forKeys:keys];
		NSDictionary *none = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:@"None", @"none", [NSArray array], nil] forKeys:keys];
		[temporaryArray insertObject:standard atIndex:0];
		[temporaryArray insertObject:none atIndex:1];
		syntaxDefinitionsArray = [[NSArray alloc] initWithArray:temporaryArray];
		[syntaxDefinitionsStandardArray release];
		[temporaryArray release];
	}
}

+(NSArray *)syntaxDefinitionsArray
{
	return syntaxDefinitionsArray;
}

-(id)initWithTextView:(NSTextView*)aTextView
{
	if ((!(self = [super init])))
    return nil;
    
  userDefaults = [NSUserDefaults standardUserDefaults];
  
  textView = aTextView;
  layoutManager = [textView layoutManager];
  [self setColours];
  [self setSyntaxDefinitionsForExtension:@"tex"];
  
  letterCharacterSet = [NSCharacterSet letterCharacterSet];
  NSMutableCharacterSet *tempSet = [[NSCharacterSet letterCharacterSet] mutableCopy];
  [tempSet addCharactersInString:@"_:@#"];
  keywordStartCharacterSet = [tempSet copy];
  [tempSet release];
  
  tempSet = [[NSCharacterSet whitespaceAndNewlineCharacterSet] mutableCopy];
  [tempSet formUnionWithCharacterSet:[NSCharacterSet symbolCharacterSet]];
  [tempSet formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
  [tempSet removeCharactersInString:@"_"];
  keywordEndCharacterSet = [tempSet copy];
  [tempSet release];
  
  completeString = [textView string];
  textContainer = [textView textContainer];
  if (YES)//[[SMLDocumentsArray sharedInstance] currentDocumentIsSyntaxColoured])
    [self pageRecolour];
  //[textView setDelegate:self];
  [[textView textStorage] setDelegate:(id)self];
  undoManager = [[NSUndoManager alloc] init];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkIfCanUndo) name:NSUndoManagerDidUndoChangeNotification
                                             object:undoManager];
  highlightColour = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor selectedTextBackgroundColor], NSBackgroundColorAttributeName, nil];

  return self;
}

-(void) textStorageDidProcessEditing:(NSNotification*)aNotification
{
  NSTextStorage* textStorage = [self->layoutManager textStorage];
  [textStorage removeAttribute:NSLinkAttributeName range:NSMakeRange(0, [textStorage length])];
}
//end textStorageDidProcessEditing:


-(NSUndoManager*) undoManagerForTextView:(NSTextView*)aTextView
{
  return [self undoManager];
}
//END undoManagerForTextView:

-(void) setColours
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  BOOL syntaxColoring = [preferencesController editionSyntaxColoringEnabled];
  [textView setBackgroundColor:[preferencesController editionSyntaxColoringTextBackgroundColor]];
  [[textView textStorage] setForegroundColor:[preferencesController editionSyntaxColoringTextForegroundColor]];
  [textView setInsertionPointColor:[preferencesController editionSyntaxColoringTextForegroundColor]];
	if (self->commandsColour) {
		[self->commandsColour release];
		self->commandsColour = nil;
	}
  NSColor* color = [preferencesController editionSyntaxColoringTextForegroundColor];
  color = syntaxColoring ? [preferencesController editionSyntaxColoringCommandColor] : color;
  self->commandsColour = [[NSDictionary alloc] initWithObjectsAndKeys:color, NSForegroundColorAttributeName, nil];
  
	if (self->commentsColour) {
		[self->commentsColour release];
		self->commentsColour = nil;
	}
  color = syntaxColoring ? [preferencesController editionSyntaxColoringCommentColor] : color;
  self->commentsColour = [[NSDictionary alloc] initWithObjectsAndKeys:color, NSForegroundColorAttributeName, nil];
  
	if (self->instructionsColour) {
		[self->instructionsColour release];
		self->instructionsColour = nil;
	}
  color = syntaxColoring ? [preferencesController editionSyntaxColoringCommandColor] : color;
  self->instructionsColour = [[NSDictionary alloc] initWithObjectsAndKeys:color, NSForegroundColorAttributeName, nil];
	
	if (self->keywordsColour) {
		[self->keywordsColour release];
		self->keywordsColour = nil;
	}
  color = syntaxColoring ? [preferencesController editionSyntaxColoringKeywordColor] : color;
  self->keywordsColour = [[NSDictionary alloc] initWithObjectsAndKeys:color, NSForegroundColorAttributeName, nil];
	
	if (self->stringsColour) {
		[self->stringsColour release];
		self->stringsColour = nil;
	}
  color = syntaxColoring ? [preferencesController editionSyntaxColoringMathsColor] : color;
  self->stringsColour = [[NSDictionary alloc] initWithObjectsAndKeys:color, NSForegroundColorAttributeName, nil];
  
	if (self->variablesColour) {
		[self->variablesColour release];
		self->variablesColour = nil;
	}
  color = syntaxColoring ? [preferencesController editionSyntaxColoringKeywordColor] : color;
  self->variablesColour = [[NSDictionary alloc] initWithObjectsAndKeys:color, NSForegroundColorAttributeName, nil];
}

-(void)setSyntaxDefinitionsForExtension:(NSString *)extension
{	
	NSString *fileToUse = nil;
  if ([userDefaults integerForKey:@"SyntaxColouringMatrix"] == 1) //Always use...
    fileToUse = [NSString stringWithString:[[[SMLSyntaxColouring syntaxDefinitionsArray]
                             objectAtIndex:[userDefaults integerForKey:@"SyntaxColouringPopUp"]] objectForKey:@"file"]];

	if (!fileToUse) fileToUse = @"standard"; //be sure to set it to something
	/*[self setSyntaxDefinitionName:[[[SMLSyntaxColouring syntaxDefinitionsArray]
                  objectAtIndex:[[SMLDocumentsArray sharedInstance] currentSyntaxDefinition]] objectForKey:@"name"]];*/
	
	NSDictionary *syntaxDictionary;
	syntaxDictionary = [[NSDictionary alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:fileToUse ofType:@"plist"]];
	
	if (!syntaxDictionary) // if it can't find it in the bundle try in Application Support
  {
		NSString *path =
      [[[[[NSHomeDirectory() stringByAppendingPathComponent:@"Library"]
                             stringByAppendingPathComponent:@"Application Support"]
                             stringByAppendingPathComponent:@"Smultron"]
                             stringByAppendingPathComponent:fileToUse]
                             stringByAppendingString:@".plist"];
    path = [[NSBundle mainBundle] pathForResource:@"tex" ofType:@"plist"];
		syntaxDictionary = [[NSDictionary alloc] initWithContentsOfFile:path];
	}
	
	if (!syntaxDictionary) syntaxDictionary =
    [[NSDictionary alloc] initWithContentsOfFile:
      [[NSBundle mainBundle] pathForResource:
        [[[SMLSyntaxColouring syntaxDefinitionsArray] objectAtIndex:[userDefaults integerForKey:@"SyntaxColouringPopUp"]]
           objectForKey:@"file"] ofType:@"plist"]]; //if it can't find a syntax file use the one from preferences
	
	if (!syntaxDictionary)// if it still can't find a syntax file display a sheet and return; this roundabout way of doing this (using performSelector) is because otherwise the sheet does not have a window to attach to when the program start, if the sheet needs to be displayed at startup
		[self performSelector:@selector(openSyntaxColourAlertSheet) withObject:nil afterDelay:0.0];
	
	NSMutableArray *keywordsAndAutocompleteWordsTemporary = [[NSMutableArray alloc] init];
	
	//if the plist file is malformed be sure to set it to something
	if ([syntaxDictionary objectForKey:@"keywords"]) {
		NSSet *keywordsSet = [[NSSet alloc] initWithArray:[syntaxDictionary objectForKey:@"keywords"]];
		[self setKeywords:keywordsSet];
		[keywordsSet release];
		[keywordsAndAutocompleteWordsTemporary addObjectsFromArray:[syntaxDictionary objectForKey:@"keywords"]];
	} else { 
		[self setKeywords:nil];
	}
	
	if ([syntaxDictionary objectForKey:@"autocompleteWords"]) {
		[self setAutocompleteWords:[syntaxDictionary objectForKey:@"autocompleteWords"]];
		[keywordsAndAutocompleteWordsTemporary addObjectsFromArray:[self autocompleteWords]];
	} else { 
		[self setAutocompleteWords:nil];
	}
	
	if ([userDefaults boolForKey:@"ColourAutocompleteWordsAsKeywords"]) {
		[self setKeywords:[NSSet setWithArray:keywordsAndAutocompleteWordsTemporary]];
	}
	
	[self setKeywordsAndAutocompleteWords:[keywordsAndAutocompleteWordsTemporary sortedArrayUsingSelector:@selector(compare:)]];
	[keywordsAndAutocompleteWordsTemporary release];
	
	if ([syntaxDictionary objectForKey:@"recolourKeywordIfAlreadyColoured"])
		[self setRecolourKeywordIfAlreadyColoured:[[syntaxDictionary valueForKey:@"recolourKeywordIfAlreadyColoured"] boolValue]];
	else 
		[self setRecolourKeywordIfAlreadyColoured:YES];
	
	if ([syntaxDictionary objectForKey:@"keywordsCaseSensitive"])
		[self setKeywordsCaseSensitive:[[syntaxDictionary valueForKey:@"keywordsCaseSensitive"] boolValue]];
	else 
		[self setKeywordsCaseSensitive:NO];
	
	if (![self keywordsCaseSensitive]) {
		NSMutableArray *lowerCaseKeywords = [[NSMutableArray alloc] init];
		NSEnumerator *enumerator = [[self keywords] objectEnumerator];
		id item;
		while ((item = [enumerator nextObject]))
			[lowerCaseKeywords addObject:[item lowercaseString]];
		
		NSSet *lowerCaseKeywordsSet = [[NSSet alloc] initWithArray:lowerCaseKeywords];
		[self setKeywords:lowerCaseKeywordsSet];
		[lowerCaseKeywordsSet release];
		[lowerCaseKeywords release];
	}
	
	if ([syntaxDictionary objectForKey:@"beginCommand"])
		[self setBeginCommand:[syntaxDictionary objectForKey:@"beginCommand"]];
	else 
		[self setBeginCommand:@""];
	
	if ([syntaxDictionary objectForKey:@"endCommand"])
		[self setEndCommand:[syntaxDictionary objectForKey:@"endCommand"]];
	else 
		[self setEndCommand:@""];
	
	if ([syntaxDictionary objectForKey:@"beginInstruction"])
		[self setBeginInstruction:[syntaxDictionary objectForKey:@"beginInstruction"]];
	else 
		[self setBeginInstruction:@""];
	
	if ([syntaxDictionary objectForKey:@"endInstruction"])
		[self setEndInstruction:[syntaxDictionary objectForKey:@"endInstruction"]];
	else 
		[self setEndInstruction:@""];
	
	if ([syntaxDictionary objectForKey:@"beginVariable"])
		[self setBeginVariable:[NSCharacterSet characterSetWithCharactersInString:[syntaxDictionary objectForKey:@"beginVariable"]]];
	else 
		[self setBeginVariable:[NSCharacterSet characterSetWithCharactersInString:@""]];
	
	if ([syntaxDictionary objectForKey:@"endVariable"])
		[self setEndVariable:[NSCharacterSet characterSetWithCharactersInString:[syntaxDictionary objectForKey:@"endVariable"]]];
	else 
		[self setEndVariable:[NSCharacterSet characterSetWithCharactersInString:@""]];
	
	if ([syntaxDictionary objectForKey:@"firstString"]) {
		[self setFirstString:[syntaxDictionary objectForKey:@"firstString"]];
		if (![[syntaxDictionary objectForKey:@"firstString"] isEqual:@""])
			[self setFirstStringUnichar:[[syntaxDictionary objectForKey:@"firstString"] characterAtIndex:0]];
	} else { 
		[self setFirstString:@""];
	}
	
	if ([syntaxDictionary objectForKey:@"secondString"]) {
		[self setSecondString:[syntaxDictionary objectForKey:@"secondString"]];
		if (![[syntaxDictionary objectForKey:@"secondString"] isEqual:@""])
			[self setSecondStringUnichar:[[syntaxDictionary objectForKey:@"secondString"] characterAtIndex:0]];
	} else { 
		[self setSecondString:@""];
	}
	
	if ([syntaxDictionary objectForKey:@"firstSingleLineComment"])
		[self setFirstSingleLineComment:[syntaxDictionary objectForKey:@"firstSingleLineComment"]];
	else 
		[self setFirstSingleLineComment:@""];
	
	if ([syntaxDictionary objectForKey:@"secondSingleLineComment"])
		[self setSecondSingleLineComment:[syntaxDictionary objectForKey:@"secondSingleLineComment"]];
	else 
		[self setSecondSingleLineComment:@""];
	
	if ([syntaxDictionary objectForKey:@"beginFirstMultiLineComment"])
		[self setBeginFirstMultiLineComment:[syntaxDictionary objectForKey:@"beginFirstMultiLineComment"]];
	else 
		[self setBeginFirstMultiLineComment:@""];
	
	if ([syntaxDictionary objectForKey:@"endFirstMultiLineComment"])
		[self setEndFirstMultiLineComment:[syntaxDictionary objectForKey:@"endFirstMultiLineComment"]];
	else 
		[self setEndFirstMultiLineComment:@""];
	
	if ([syntaxDictionary objectForKey:@"beginSecondMultiLineComment"])
		[self setBeginSecondMultiLineComment:[syntaxDictionary objectForKey:@"beginSecondMultiLineComment"]];
	else 
		[self setBeginSecondMultiLineComment:@""];
	
	if ([syntaxDictionary objectForKey:@"endSecondMultiLineComment"])
		[self setEndSecondMultiLineComment:[syntaxDictionary objectForKey:@"endSecondMultiLineComment"]];
	else 
		[self setEndSecondMultiLineComment:@""];
	
	[syntaxDictionary release];
}

-(void)openSyntaxColourAlertSheet
{
	//[[SMLMainController sharedInstance] standardAlertSheetWithTitle:NSLocalizedString(@"Could not find the syntax file to match this document", @"Indicate that the program could not find the syntax file to match this document in Could-not-find-syntax-file sheet") andMessage:NSLocalizedString(@"Please check the installation of the application and the preferences", @"Indicate that they should Please check the installation of the application and the preferences in Could-not-find-syntax-file sheet")];
	//[[SMLMainController sharedInstance] reloadDataInTableView]; // to show icon in tableView 
	return;
}

-(void)recolourCompleteDocument
{
	//if ([defaults boolForKey:@"ShowSpinningProgressIndicator"])
	//	[[SMLMainController sharedInstance] startProgressIndicator];
	[self recolourRange:NSMakeRange(0, [completeString length]) completeRecolour:YES];
	//if ([defaults boolForKey:@"ShowSpinningProgressIndicator"])
	//	[[SMLMainController sharedInstance] stopProgressIndicator];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:textView];
}

-(void)removeColoursFromRange:(NSRange)range
{
  [layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:range];
}

-(void)removeAllColours
{
  [self removeColoursFromRange:NSMakeRange(0, [completeString length])];
}

- (void)textViewDidChangeSelection:(NSNotification *)aNotification
{
	completeStringLength = [completeString length];
	if (completeStringLength == 0) return;
	
	//[[SMLMainController sharedInstance] updateStatusBar];
	
	if (![userDefaults boolForKey:@"ShowMatchingBraces"]) return;
	editedRange = [textView selectedRange];
	cursorLocation = editedRange.location;
	differenceBetweenLastAndPresent = cursorLocation - lastCursorLocation;
	lastCursorLocation = cursorLocation;
	if (differenceBetweenLastAndPresent != 1 && differenceBetweenLastAndPresent != -1) return; // if the difference is more than one they've moved the cursor with the mouse or it has been moved by resetSelectedRange below and we shouldn't check for matching braces then
	
	if (differenceBetweenLastAndPresent == 1) // check if the cursor has moved forward
		cursorLocation--;
	if (cursorLocation == completeStringLength) return;
	
	characterToCheck = [completeString characterAtIndex:cursorLocation];
	skipMatchingBrace = 0;
	
	if (characterToCheck == ')') {
		while (cursorLocation--) {
			characterToCheck = [completeString characterAtIndex:cursorLocation];
			if (characterToCheck == '(') {
				if (!skipMatchingBrace) {
					[layoutManager addTemporaryAttributes:[self highlightColour] forCharacterRange:NSMakeRange(cursorLocation, 1)];
					[self performSelector:@selector(resetBackgroundColour:) withObject:NSStringFromRange(NSMakeRange(cursorLocation, 1)) afterDelay:0.12];
					return;
				} else
					skipMatchingBrace--;
			} else if (characterToCheck == ')') skipMatchingBrace++;
		}
		NSBeep();
	} else if (characterToCheck == ']') {
		while (cursorLocation--) {
			characterToCheck = [completeString characterAtIndex:cursorLocation];
			if (characterToCheck == '[') {
				if (!skipMatchingBrace) {
					[layoutManager addTemporaryAttributes:[self highlightColour] forCharacterRange:NSMakeRange(cursorLocation, 1)];
					[self performSelector:@selector(resetBackgroundColour:) withObject:NSStringFromRange(NSMakeRange(cursorLocation, 1)) afterDelay:0.12];
					return;
				} else
					skipMatchingBrace--;
			} else if (characterToCheck == ']') skipMatchingBrace++;
		}
		NSBeep();
	} else if (characterToCheck == '}') {
		while (cursorLocation--) {
			characterToCheck = [completeString characterAtIndex:cursorLocation];
			if (characterToCheck == '{') {
				if (!skipMatchingBrace) {
					[layoutManager addTemporaryAttributes:[self highlightColour] forCharacterRange:NSMakeRange(cursorLocation, 1)];
					[self performSelector:@selector(resetBackgroundColour:) withObject:NSStringFromRange(NSMakeRange(cursorLocation, 1)) afterDelay:0.12];
					return;
				} else
					skipMatchingBrace--;
			} else if (characterToCheck == '}') skipMatchingBrace++;
		}
		NSBeep();
	}
}

-(void)resetBackgroundColour:(id)sender
{
	[layoutManager removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:NSRangeFromString(sender)];
}

-(void)textDidChange:(NSNotification*)notification
{
	//if ([completeString length] < 2)
	//	[[SMLMainController sharedInstance] updateStatusBar]; // one needs to call this from here as well because otherwise it won't update the status bar if you write one character and delete it in an empty document, because the textViewDidChangeSelection delegate method won't be called.
	
	//if (![[SMLDocumentsArray sharedInstance] currentDocumentIsEdited])
	//  [[SMLMainController sharedInstance] currentDocumentHasChanged];

	//[[SMLMainController sharedInstance] lineNumbersCheckWidth:NO recolour:NO];
	//if (![[SMLDocumentsArray sharedInstance] currentDocumentIsSyntaxColoured]) //if we shouldn't syntax colour, remove all timers and return
	//  [self removeAllTimers];
  //else
	[self pageRecolour];
	
	if (autocompleteWordsTimer) {
		[autocompleteWordsTimer setFireDate:[NSDate dateWithTimeIntervalSinceNow:[userDefaults floatForKey:@"AutocompleteAfterDelay"]]];
	} else if ([userDefaults boolForKey:@"AutocompleteSuggestAutomatically"]) {
		autocompleteWordsTimer = [[NSTimer scheduledTimerWithTimeInterval:[userDefaults floatForKey:@"AutocompleteAfterDelay"]
																	   target:self 
																	 selector:@selector(autocompleteWordsTimerSelector) 
																	 userInfo:nil 
																	  repeats:NO] retain];
	}
}

-(void)removeAllTimers
{
	if (startPageRecolourTimer) {
		[startPageRecolourTimer invalidate];
		[startPageRecolourTimer release];
		startPageRecolourTimer = nil;
	}
}

-(void)pageRecolour
{
	visibleRect = [[[textView enclosingScrollView] contentView] documentVisibleRect];
	visibleRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:[textView textContainer]];
	beginningOfFirstVisibleLine = [completeString lineRangeForRange:NSMakeRange(visibleRange.location, 0)].location;
	endOfLastVisibleLine = NSMaxRange([completeString lineRangeForRange:NSMakeRange(NSMaxRange(visibleRange), 0)]);
	
	[self recolourRange:NSMakeRange(beginningOfFirstVisibleLine, endOfLastVisibleLine - beginningOfFirstVisibleLine) completeRecolour:NO];
	if (startPageRecolourTimer) {
		[startPageRecolourTimer invalidate];
		[startPageRecolourTimer release];
		startPageRecolourTimer = nil;
	}
}

-(void)autocompleteWordsTimerSelector
{
	selectedRange = [textView selectedRange];
	stringLength = [completeString length];
	if (selectedRange.location <= stringLength && (selectedRange.length == 0) && (stringLength != 0))
   {
		if (selectedRange.location == stringLength) // if we're at the very end of the document
			[textView complete:self];
		else
    {
			unichar characterAfterSelection = [completeString characterAtIndex:selectedRange.location];
			if ([[NSCharacterSet symbolCharacterSet] characterIsMember:characterAfterSelection] ||
          [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:characterAfterSelection] ||
          [[NSCharacterSet punctuationCharacterSet] characterIsMember:characterAfterSelection] ||
          selectedRange.location == stringLength) // don't autocomplete if we're in the middle of a word
				[textView complete:self];
		}
	}
	
	if (autocompleteWordsTimer) {
		[autocompleteWordsTimer invalidate];
		[autocompleteWordsTimer release];
		autocompleteWordsTimer = nil;
	}
}

-(void)recolourRange:(NSRange)range completeRecolour:(BOOL)completeRecolour
{
	searchString = [completeString substringWithRange:range];
	scanner = [[NSScanner alloc] initWithString:searchString];
	[scanner setCharactersToBeSkipped:nil];
	completeDocumentScanner = [[NSScanner alloc] initWithString:completeString];
	[completeDocumentScanner setCharactersToBeSkipped:nil];
	
	searchStringLength = [searchString length];
	completeStringLength = [completeString length];
	beginLocationInMultiLine = 0;
	rangeLocation = range.location;

	shouldOnlyColourTillTheEndOfLine = NO || [userDefaults boolForKey:@"OnlyColourTillTheEndOfLine"];
	shouldColourMultiLineStrings = YES || [userDefaults boolForKey:@"ColourMultiLineStrings"];
	
	[self removeColoursFromRange:range];

	NS_DURING // if there are any exceptions raised by this section just pass through and stop colouring instead of throwing an exception and refuse to load the textview 
	//commands
	if (![beginCommand isEqual:@""]) {
		searchSyntaxLength = [endCommand length];
		beginCommandCharacter = [beginCommand characterAtIndex:0];
		endCommandCharacter = [endCommand characterAtIndex:0];
		while (![scanner isAtEnd]) {
			[scanner scanUpToString:beginCommand intoString:nil];
			beginning = [scanner scanLocation];
			endOfLine = NSMaxRange([searchString lineRangeForRange:NSMakeRange(beginning, 0)]);
			if (![scanner scanUpToString:endCommand intoString:nil] || [scanner scanLocation] >= endOfLine) {
				[scanner setScanLocation:endOfLine];
				continue; // don't colour it if it hasn't got a closing tag
			} else {
				// to avoid problems with strings like <yada <%=yada%> yada> we need to balance the number of begin- and end-tags
				// if ever there's a beginCommand or endCommand with more than one character then do a check first
				commandLocation = beginning + 1;
				skipEndCommand = 0;
				
				while (commandLocation < endOfLine) {
					commandCharacterTest = [searchString characterAtIndex:commandLocation];
					if (commandCharacterTest == endCommandCharacter) {
						if (!skipEndCommand) 
							break;
						else
							skipEndCommand--;
					}
					if (commandCharacterTest == beginCommandCharacter) skipEndCommand++;
					commandLocation++;
				}
				if (commandLocation < endOfLine)
					[scanner setScanLocation:commandLocation + searchSyntaxLength];
				else
					[scanner setScanLocation:endOfLine];
			}
			[layoutManager addTemporaryAttributes:commandsColour forCharacterRange:NSMakeRange(beginning + rangeLocation, [scanner scanLocation] - beginning)];	 
		}
	}
	

	//instructions
	if (![beginInstruction isEqual:@""]) {
		// if not in completeRecolour, it takes too long to scan the whole document if it's large, so for instructions, first multi-line comment and second multi-line comment search backwards and begin at the start of the first beginInstruction etc. that it finds from the present position and, below, break the loop if it has passed the scanned range (i.e. after the end instruction)
		
		if (!completeRecolour) {
			beginLocationInMultiLine = [completeString rangeOfString:beginInstruction options:NSBackwardsSearch range:NSMakeRange(0, rangeLocation)].location;
			endLocationInMultiLine = [completeString rangeOfString:endInstruction options:NSBackwardsSearch range:NSMakeRange(0, rangeLocation)].location;
			if (beginLocationInMultiLine == NSNotFound || (endLocationInMultiLine != NSNotFound && beginLocationInMultiLine < endLocationInMultiLine)) {
				beginLocationInMultiLine = rangeLocation;
			}			
		} else {
			beginLocationInMultiLine = 0;
		}

		searchSyntaxLength = [endInstruction length];
		while (![completeDocumentScanner isAtEnd]) {
			searchRange = NSMakeRange(beginLocationInMultiLine, range.length);
			if (NSMaxRange(searchRange) > completeStringLength) {
				searchRange = NSMakeRange(beginLocationInMultiLine, completeStringLength - beginLocationInMultiLine);
			}
			
			beginning = [completeString rangeOfString:beginInstruction options:NSLiteralSearch range:searchRange].location;
			if (beginning == NSNotFound) break;
			[completeDocumentScanner setScanLocation:beginning];
			if (![completeDocumentScanner scanUpToString:endInstruction intoString:nil] || [completeDocumentScanner scanLocation] >= completeStringLength) {
				if (shouldOnlyColourTillTheEndOfLine)
					[completeDocumentScanner setScanLocation:NSMaxRange([completeString lineRangeForRange:NSMakeRange(beginning, 0)])];
				else
					[completeDocumentScanner setScanLocation:completeStringLength];
			} else {
				if ([completeDocumentScanner scanLocation] + searchSyntaxLength <= completeStringLength)
					[completeDocumentScanner setScanLocation:[completeDocumentScanner scanLocation] + searchSyntaxLength];
			}

			[layoutManager addTemporaryAttributes:instructionsColour forCharacterRange:NSMakeRange(beginning, [completeDocumentScanner scanLocation] - beginning)];
			if ([completeDocumentScanner scanLocation] > NSMaxRange(range)) break;
			beginLocationInMultiLine = [completeDocumentScanner scanLocation];
		}
	}
	
	
	//keywords
	if ([keywords count]) {
		[scanner setScanLocation:0];
		while (![scanner isAtEnd]) {
			[scanner scanUpToCharactersFromSet:keywordStartCharacterSet intoString:nil];
			beginning = [scanner scanLocation];
			if ((beginning + 1) < searchStringLength) {
				[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
			}
			[scanner scanUpToCharactersFromSet:keywordEndCharacterSet intoString:nil];
			
			end = [scanner scanLocation];
			if (end > searchStringLength || beginning == end) break;
			
			if (![self keywordsCaseSensitive]) {
				keywordTestString = [[completeString substringWithRange:NSMakeRange(beginning + rangeLocation, end - beginning)] lowercaseString];
			} else {
				keywordTestString = [completeString substringWithRange:NSMakeRange(beginning + rangeLocation, end - beginning)];
			}
			if ([keywords containsObject:keywordTestString]) {
				if (!recolourKeywordIfAlreadyColoured) {
					if ([[layoutManager temporaryAttributesAtCharacterIndex:beginning + rangeLocation effectiveRange:NULL] isEqualToDictionary:commandsColour]) {
						continue;
					}
				}	
				[layoutManager addTemporaryAttributes:self->keywordsColour forCharacterRange:NSMakeRange(beginning + rangeLocation, [scanner scanLocation] - beginning)];
			}
		}
	}
	
	
	//variables
	if (![beginVariable isEqual:@""]) {
		[scanner setScanLocation:0];
		while (![scanner isAtEnd]) {
			[scanner scanUpToCharactersFromSet:beginVariable intoString:nil];
			beginning = [scanner scanLocation];
			endOfLine = NSMaxRange([searchString lineRangeForRange:NSMakeRange(beginning, 0)]);		
			if (![scanner scanUpToCharactersFromSet:endVariable intoString:nil] || [scanner scanLocation] >= endOfLine) {
				[scanner setScanLocation:endOfLine];
				length = [scanner scanLocation] - beginning;
			} else {
				length = [scanner scanLocation] - beginning;
				if ([scanner scanLocation] < searchStringLength) {
					[scanner setScanLocation:[scanner scanLocation] + 1];
				}
			}
			[layoutManager addTemporaryAttributes:self->variablesColour forCharacterRange:NSMakeRange(beginning + rangeLocation, length)];
		}
	}	
	
	//second string, first pass
	if (![secondString isEqual:@""]) {
		[scanner setScanLocation:0];
		endOfLine = searchStringLength;
		while (![scanner isAtEnd]) {
			foundMatch = NO;
			[scanner scanUpToString:secondString intoString:nil];
			beginning = [scanner scanLocation];
			if (beginning >= searchStringLength) break;
			characterToCheck = [searchString characterAtIndex:beginning - 1];
			if ([letterCharacterSet characterIsMember:characterToCheck] || [searchString characterAtIndex:beginning - 1] == '\\') {
				[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
				continue; // to avoid e.g. \'
			}		

			if (!shouldColourMultiLineStrings) {
				rangeOfLine = [searchString lineRangeForRange:NSMakeRange(beginning, 0)];
				endOfLine = NSMaxRange(rangeOfLine);
			}
				
			index = beginning + 1;
			while (index < endOfLine) {
				if ([searchString characterAtIndex:index] == secondStringUnichar) {
					if ([searchString characterAtIndex:index - 1] == '\\') {
						index++;
						continue;
					} else {
						index++;
						foundMatch = YES;
						break;
					}
				}
				index++;
			}
			
			if (foundMatch) {
				[scanner setScanLocation:index];
				[layoutManager addTemporaryAttributes:self->stringsColour forCharacterRange:NSMakeRange(beginning + rangeLocation, index - beginning)];
			} else {
				[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
			}
		}
	}
	
	
	//first string
	if (![firstString isEqual:@""]) {
		[scanner setScanLocation:0];
		endOfLine = searchStringLength;
		while (![scanner isAtEnd]) {
			foundMatch = NO;
			[scanner scanUpToString:firstString intoString:nil];
			beginning = [scanner scanLocation];
			if (beginning >= searchStringLength) break;
			characterToCheck = [searchString characterAtIndex:beginning - 1];
			if (characterToCheck == '\\' || [[layoutManager temporaryAttributesAtCharacterIndex:beginning + rangeLocation effectiveRange:NULL] isEqualToDictionary:self->stringsColour] || [letterCharacterSet characterIsMember:characterToCheck]) {
				[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
				continue; // to avoid e.g. \" or if it's on a string
			}
			
			if (!shouldColourMultiLineStrings)
				endOfLine = NSMaxRange([searchString lineRangeForRange:NSMakeRange(beginning, 0)]);
			index = beginning + 1;
			while (index < endOfLine) {
				if ([searchString characterAtIndex:index] == firstStringUnichar) {
					if ([searchString characterAtIndex:index - 1] == '\\') {
						index++;
						continue;
					} else {
						index++;
						foundMatch = YES;
						break;
					}
				}
				index++;
			}
	
			if (foundMatch) {
				[scanner setScanLocation:index];
				[layoutManager addTemporaryAttributes:self->stringsColour forCharacterRange:NSMakeRange(beginning + rangeLocation, index - beginning)];
			} else {
				[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
			}
		}
	}
	
	
	//first single-line comment
	if (![firstSingleLineComment isEqual:@""]) {
		[scanner setScanLocation:0];
		searchSyntaxLength = [firstSingleLineComment length];
		while (![scanner isAtEnd]) {
			[scanner scanUpToString:firstSingleLineComment intoString:nil];
			beginning = [scanner scanLocation];
			if ([firstSingleLineComment isEqual:@"//"]) {
				if (beginning > 0 && [searchString characterAtIndex:beginning - 1] == ':') {
					[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
					continue; // to avoid http:// ftp:// file:// etc.
				}
			} else if ([firstSingleLineComment isEqual:@"#"]) {
				if (searchStringLength > 1) {
					rangeOfLine = [searchString lineRangeForRange:NSMakeRange(beginning, 0)];
					if ([searchString rangeOfString:@"#!" options:NSLiteralSearch range:rangeOfLine].location != NSNotFound) {
						[scanner setScanLocation:NSMaxRange(rangeOfLine)];
						continue; // don't treat the line as a comment if it begins with #!
					} else if ([searchString characterAtIndex:beginning - 1] == '$') {
						[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
						continue; // to avoid $#
					} else if ([searchString characterAtIndex:beginning - 1] == '&') {
						[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
						continue; // to avoid &#
					}
				}
			}
			else if ([firstSingleLineComment isEqual:@"%"])
      {
				if (searchStringLength > 1)
        {
					rangeOfLine = [searchString lineRangeForRange:NSMakeRange(beginning, 0)];
          NSUInteger countPrecedingAntiSlashed = 0;
          NSUInteger prevIndex = beginning;
          while(prevIndex--)
          {
            if ([searchString characterAtIndex:prevIndex] == '\\')
              ++countPrecedingAntiSlashed;
            else
              break;
          }
          if (countPrecedingAntiSlashed && (countPrecedingAntiSlashed%2))
          {
						[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
						continue; // to avoid \%
          }
        }
			}
			if (beginning + rangeLocation + searchSyntaxLength < [[scanner string] length]/*completeStringLength*/) {
				if ([[layoutManager temporaryAttributesAtCharacterIndex:beginning + rangeLocation effectiveRange:NULL] isEqualToDictionary:self->stringsColour]) {
					[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
					continue; // if the comment is within a string disregard it
				}
			}
			endOfLine = NSMaxRange([searchString lineRangeForRange:NSMakeRange(beginning, 0)]);
			[scanner setScanLocation:endOfLine];

			[layoutManager addTemporaryAttributes:commentsColour forCharacterRange:NSMakeRange(beginning + rangeLocation, [scanner scanLocation] - beginning)];
		}
	}
	
	//second single-line comment
	if (![secondSingleLineComment isEqual:@""]) {
		[scanner setScanLocation:0];
		searchSyntaxLength = [secondSingleLineComment length];
		while (![scanner isAtEnd]) {
			[scanner scanUpToString:secondSingleLineComment intoString:nil];
			beginning = [scanner scanLocation];
			
			if ([secondSingleLineComment isEqual:@"//"]) {
				if (beginning > 0 && [searchString characterAtIndex:beginning - 1] == ':') {
					[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
					continue; // to avoid http:// ftp:// file:// etc.
				}
			} else if ([secondSingleLineComment isEqual:@"#"]) {
				if (searchStringLength > 1) {
					rangeOfLine = [searchString lineRangeForRange:NSMakeRange(beginning, 0)];
					if ([searchString rangeOfString:@"#!" options:NSLiteralSearch range:rangeOfLine].location != NSNotFound) {
						[scanner setScanLocation:NSMaxRange(rangeOfLine)];
						continue; // don't treat the line as a comment if it begins with #!
					} else if ([searchString characterAtIndex:beginning - 1] == '$') {
						[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
						continue; // to avoid $#
					} else if ([searchString characterAtIndex:beginning - 1] == '&') {
						[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
						continue; // to avoid &#
					}
				}
			}
			if (beginning + rangeLocation + searchSyntaxLength < completeStringLength) {
				if ([[layoutManager temporaryAttributesAtCharacterIndex:beginning + rangeLocation effectiveRange:NULL] isEqualToDictionary:self->stringsColour]) {
					[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
					continue; // if the comment is within a string disregard it
				}
			}
			endOfLine = NSMaxRange([searchString lineRangeForRange:NSMakeRange(beginning, 0)]);
			[scanner setScanLocation:endOfLine];
			
			[layoutManager addTemporaryAttributes:commentsColour forCharacterRange:NSMakeRange(beginning + rangeLocation, [scanner scanLocation] - beginning)];
		}
	}
	
	//first multi-line comment
	if (![beginFirstMultiLineComment isEqual:@""]) {
		if (!completeRecolour) {
			beginLocationInMultiLine = [completeString rangeOfString:beginFirstMultiLineComment options:NSBackwardsSearch range:NSMakeRange(0, rangeLocation)].location;
			endLocationInMultiLine = [completeString rangeOfString:endFirstMultiLineComment options:NSBackwardsSearch range:NSMakeRange(0, rangeLocation)].location;
			if (beginLocationInMultiLine == NSNotFound || (endLocationInMultiLine != NSNotFound && beginLocationInMultiLine < endLocationInMultiLine)) {
				beginLocationInMultiLine = rangeLocation;
			}			
		} else {
			beginLocationInMultiLine = 0;
		}

		searchSyntaxLength = [endFirstMultiLineComment length];
		while (![completeDocumentScanner isAtEnd]) {
			searchRange = NSMakeRange(beginLocationInMultiLine, range.length);
			if (NSMaxRange(searchRange) > completeStringLength) {
				searchRange = NSMakeRange(beginLocationInMultiLine, completeStringLength - beginLocationInMultiLine);
			}
			beginning = [completeString rangeOfString:beginFirstMultiLineComment options:NSLiteralSearch range:searchRange].location;
			if (beginning == NSNotFound) break;
			[completeDocumentScanner setScanLocation:beginning];
			if (beginning + 1 < completeStringLength) {
				if ([[layoutManager temporaryAttributesAtCharacterIndex:beginning effectiveRange:NULL] isEqualToDictionary:self->stringsColour]) {
					[completeDocumentScanner setScanLocation:MIN(beginning + 1, [[completeDocumentScanner string] length])];
					beginLocationInMultiLine++;
					continue; // if the comment is within a string disregard it
				}
			}
			
			if (![completeDocumentScanner scanUpToString:endFirstMultiLineComment intoString:nil] || [completeDocumentScanner scanLocation] >= completeStringLength) {
				if (shouldOnlyColourTillTheEndOfLine)
					[completeDocumentScanner setScanLocation:NSMaxRange([completeString lineRangeForRange:NSMakeRange(beginning, 0)])];
				else
					[completeDocumentScanner setScanLocation:completeStringLength];
				length = [completeDocumentScanner scanLocation] - beginning;
			} else {
				if ([completeDocumentScanner scanLocation] < completeStringLength)
					[completeDocumentScanner setScanLocation:[completeDocumentScanner scanLocation] + searchSyntaxLength];
				length = [completeDocumentScanner scanLocation] - beginning;
				if ([endFirstMultiLineComment isEqual:@"-->"]) {
					[completeDocumentScanner scanUpToCharactersFromSet:letterCharacterSet intoString:nil]; //search for the first letter after -->
					if ([completeDocumentScanner scanLocation] + 6 < completeStringLength) {// check if there's actually room for a </script>
						if ([completeString rangeOfString:@"</script>" options:NSCaseInsensitiveSearch range:NSMakeRange([completeDocumentScanner scanLocation] - 2, 9)].location != NSNotFound || [completeString rangeOfString:@"</style>" options:NSCaseInsensitiveSearch range:NSMakeRange([completeDocumentScanner scanLocation] - 2, 8)].location != NSNotFound) {
							beginLocationInMultiLine = [completeDocumentScanner scanLocation];
							continue; // if the comment --> is followed by </script> or </style> it is probably not a real comment
						}
					}
					[completeDocumentScanner setScanLocation:beginning + length]; // reset the scanner position
				}
			}

			[layoutManager addTemporaryAttributes:commentsColour forCharacterRange:NSMakeRange(beginning, length)];
			
			if ([completeDocumentScanner scanLocation] > NSMaxRange(range)) break;
			beginLocationInMultiLine = [completeDocumentScanner scanLocation];
		}
	}
	
	//second multi-line comment
	if (![beginSecondMultiLineComment isEqual:@""]) {
		if (!completeRecolour) {
			beginLocationInMultiLine = [completeString rangeOfString:beginSecondMultiLineComment options:NSBackwardsSearch range:NSMakeRange(0, rangeLocation)].location;
			endLocationInMultiLine = [completeString rangeOfString:endSecondMultiLineComment options:NSBackwardsSearch range:NSMakeRange(0, rangeLocation)].location;
			if (beginLocationInMultiLine == NSNotFound || (endLocationInMultiLine != NSNotFound && beginLocationInMultiLine < endLocationInMultiLine)) {
				beginLocationInMultiLine = rangeLocation;
			}			
		} else {
			beginLocationInMultiLine = 0;
		}
		
		searchSyntaxLength = [endSecondMultiLineComment length];
		while (![completeDocumentScanner isAtEnd]) {
			searchRange = NSMakeRange(beginLocationInMultiLine, range.length);
			if (NSMaxRange(searchRange) > completeStringLength) {
				searchRange = NSMakeRange(beginLocationInMultiLine, completeStringLength - beginLocationInMultiLine);
			}
			beginning = [completeString rangeOfString:beginSecondMultiLineComment options:NSLiteralSearch range:searchRange].location;
			if (beginning == NSNotFound) break;
			[completeDocumentScanner setScanLocation:beginning];
			if (beginning + 1 < completeStringLength) {
				if ([[layoutManager temporaryAttributesAtCharacterIndex:beginning effectiveRange:NULL] isEqualToDictionary:self->stringsColour]) {
					[completeDocumentScanner setScanLocation:MIN(beginning + 1, [[completeDocumentScanner string] length])];
					beginLocationInMultiLine++;
					continue; // if the comment is within a string disregard it
				}
			}
			
			if (![completeDocumentScanner scanUpToString:endSecondMultiLineComment intoString:nil] || [completeDocumentScanner scanLocation] >= completeStringLength) {
				if (shouldOnlyColourTillTheEndOfLine)
					[completeDocumentScanner setScanLocation:NSMaxRange([completeString lineRangeForRange:NSMakeRange(beginning, 0)])];
				else
					[completeDocumentScanner setScanLocation:completeStringLength];
				length = [completeDocumentScanner scanLocation] - beginning;
			} else {
				if ([completeDocumentScanner scanLocation] < completeStringLength)
					[completeDocumentScanner setScanLocation:[completeDocumentScanner scanLocation] + searchSyntaxLength];
				length = [completeDocumentScanner scanLocation] - beginning;
				if ([endSecondMultiLineComment isEqual:@"-->"]) {
					[completeDocumentScanner scanUpToCharactersFromSet:letterCharacterSet intoString:nil]; //search for the first letter after -->
					if ([completeDocumentScanner scanLocation] + 6 < completeStringLength) {// check if there's actually room for a </script>
						if ([completeString rangeOfString:@"</script>" options:NSCaseInsensitiveSearch range:NSMakeRange([completeDocumentScanner scanLocation] - 2, 9)].location != NSNotFound || [completeString rangeOfString:@"</style>" options:NSCaseInsensitiveSearch range:NSMakeRange([completeDocumentScanner scanLocation] - 2, 8)].location != NSNotFound) {
							beginLocationInMultiLine = [completeDocumentScanner scanLocation];
							continue; // if the comment --> is followed by </script> or </style> it is probably not a real comment
						}
					}
					[completeDocumentScanner setScanLocation:beginning + length]; // reset the scanner position
				}
			}
			[layoutManager addTemporaryAttributes:commentsColour forCharacterRange:NSMakeRange(beginning, length)];
			
			if ([completeDocumentScanner scanLocation] > NSMaxRange(range)) break;
			beginLocationInMultiLine = [completeDocumentScanner scanLocation];
		}
	}

	//second string, second pass
	if (![secondString isEqual:@""]) {
		[scanner setScanLocation:0];
		endOfLine = searchStringLength;
		while (![scanner isAtEnd]) {
			foundMatch = NO;
			[scanner scanUpToString:secondString intoString:nil];
			beginning = [scanner scanLocation];
			if (beginning >= searchStringLength) break;
			characterToCheck = [searchString characterAtIndex:beginning - 1];
			if ([letterCharacterSet characterIsMember:characterToCheck] || characterToCheck == '\\' || [[layoutManager temporaryAttributesAtCharacterIndex:beginning + rangeLocation effectiveRange:NULL] isEqualToDictionary:self->stringsColour] || [[layoutManager temporaryAttributesAtCharacterIndex:beginning + rangeLocation effectiveRange:NULL] isEqualToDictionary:commentsColour]) {
				[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
				continue; // to avoid e.g. \' and if it's on a string or comment 
			}
			
			if (!shouldColourMultiLineStrings) {
				rangeOfLine = [searchString lineRangeForRange:NSMakeRange(beginning, 0)];
				endOfLine = NSMaxRange(rangeOfLine);
			}
			index = beginning + 1;				
			while (index < endOfLine) {
				if ([searchString characterAtIndex:index] == secondStringUnichar) {
					if ([searchString characterAtIndex:index - 1] == '\\') {
						index++;
						continue;
					} else {
						index++;
						foundMatch = YES;
						break;
					}
				}
				index++;
			}
			
			if (foundMatch) {
				[scanner setScanLocation:index];
				[layoutManager addTemporaryAttributes:self->stringsColour forCharacterRange:NSMakeRange(beginning + rangeLocation, index - beginning)];
			} else {
				[scanner setScanLocation:MIN(beginning + 1, [[scanner string] length])];
			}
		}
	}
	
	NS_HANDLER // if there are any exceptions raised, just continue and leave it uncoloured
  DebugLog(0, @"localException : %@", localException);
	NS_ENDHANDLER	
	[scanner release];
	[completeDocumentScanner release];
}

- (NSEnumerator *)wordEnumerator
{
    return wordEnumerator; 
}

- (void)setWordEnumerator:(NSEnumerator *)newWordEnumerator
{
    [newWordEnumerator retain];
    [wordEnumerator release];
    wordEnumerator = newWordEnumerator;
}

- (NSSet *)keywords
{
    return keywords; 
}

- (void)setKeywords:(NSSet *)newKeywords
{
    [newKeywords retain];
    [keywords release];
    keywords = newKeywords;
}

- (NSArray *)autocompleteWords
{
    return autocompleteWords; 
}

- (void)setAutocompleteWords:(NSArray *)newAutocompleteWords
{
    [newAutocompleteWords retain];
    [autocompleteWords release];
    autocompleteWords = newAutocompleteWords;
}

- (NSArray *)keywordsAndAutocompleteWords
{
    return keywordsAndAutocompleteWords; 
}

- (void)setKeywordsAndAutocompleteWords:(NSArray *)newKeywordsAndAutocompleteWords
{
    [newKeywordsAndAutocompleteWords retain];
    [keywordsAndAutocompleteWords release];
    keywordsAndAutocompleteWords = newKeywordsAndAutocompleteWords;
}

- (BOOL)recolourKeywordIfAlreadyColoured
{
    return recolourKeywordIfAlreadyColoured;
}

- (void)setRecolourKeywordIfAlreadyColoured:(BOOL)flag
{
    recolourKeywordIfAlreadyColoured = flag;
}

- (BOOL)keywordsCaseSensitive
{
    return keywordsCaseSensitive;
}

- (void)setKeywordsCaseSensitive:(BOOL)flag
{
    keywordsCaseSensitive = flag;
}

- (void)setBeginCommand:(NSString *)newBeginCommand
{
    [newBeginCommand retain];
    [beginCommand release];
    beginCommand = newBeginCommand;
}

- (void)setEndCommand:(NSString *)newEndCommand
{
    [newEndCommand retain];
    [endCommand release];
    endCommand = newEndCommand;
}

- (void)setBeginInstruction:(NSString *)newBeginInstruction
{
    [newBeginInstruction retain];
    [beginInstruction release];
    beginInstruction = newBeginInstruction;
}

- (void)setEndInstruction:(NSString *)newEndInstruction
{
    [newEndInstruction retain];
    [endInstruction release];
    endInstruction = newEndInstruction;
}

- (void)setBeginVariable:(NSCharacterSet *)newBeginVariable
{
    [newBeginVariable retain];
    [beginVariable release];
    beginVariable = newBeginVariable;
}

- (void)setEndVariable:(NSCharacterSet *)newEndVariable
{
    [newEndVariable retain];
    [endVariable release];
    endVariable = newEndVariable;
}

- (void)setFirstString:(NSString *)newFirstString
{
    [newFirstString retain];
    [firstString release];
    firstString = newFirstString;
}

- (void)setFirstStringUnichar:(unichar)newFirstStringUnichar
{
    firstStringUnichar = newFirstStringUnichar;
}

- (void)setSecondString:(NSString *)newSecondString
{
    [newSecondString retain];
    [secondString release];
    secondString = newSecondString;
}

- (void)setSecondStringUnichar:(unichar)newSecondStringUnichar
{
    secondStringUnichar = newSecondStringUnichar;
}

- (void)setFirstSingleLineComment:(NSString *)newFirstSingleLineComment
{
    [newFirstSingleLineComment retain];
    [firstSingleLineComment release];
    firstSingleLineComment = newFirstSingleLineComment;
}

- (void)setSecondSingleLineComment:(NSString *)newSecondSingleLineComment
{
    [newSecondSingleLineComment retain];
    [secondSingleLineComment release];
    secondSingleLineComment = newSecondSingleLineComment;
}

- (void)setBeginFirstMultiLineComment:(NSString *)newBeginFirstMultiLineComment
{
    [newBeginFirstMultiLineComment retain];
    [beginFirstMultiLineComment release];
    beginFirstMultiLineComment = newBeginFirstMultiLineComment;
}

- (void)setEndFirstMultiLineComment:(NSString *)newEndFirstMultiLineComment
{
    [newEndFirstMultiLineComment retain];
    [endFirstMultiLineComment release];
    endFirstMultiLineComment = newEndFirstMultiLineComment;
}

- (void)setBeginSecondMultiLineComment:(NSString *)newBeginSecondMultiLineComment
{
    [newBeginSecondMultiLineComment retain];
    [beginSecondMultiLineComment release];
    beginSecondMultiLineComment = newBeginSecondMultiLineComment;
}

- (void)setEndSecondMultiLineComment:(NSString *)newEndSecondMultiLineComment
{
    [newEndSecondMultiLineComment retain];
    [endSecondMultiLineComment release];
    endSecondMultiLineComment = newEndSecondMultiLineComment;
}

-(NSUndoManager *)undoManager
{
	return undoManager;
}

- (NSString *)syntaxDefinitionName
{
    return syntaxDefinitionName; 
}

- (void)setSyntaxDefinitionName:(NSString *)newSyntaxDefinitionName
{
    [newSyntaxDefinitionName retain];
    [syntaxDefinitionName release];
    syntaxDefinitionName = newSyntaxDefinitionName;
}

- (NSDictionary *)highlightColour
{
    return highlightColour; 
}

-(NSString *)guessSyntaxDefinitionFromFirstLine:(NSString *)firstLine
{
	NSString *returnString;
	NSRange firstLineRange = NSMakeRange(0, [firstLine length]);
	if ([firstLine rangeOfString:@"perl" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"pl";
	else if ([firstLine rangeOfString:@"wish" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"tcl";
	else if ([firstLine rangeOfString:@"sh" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"sh";
	else if ([firstLine rangeOfString:@"php" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"php";
	else if ([firstLine rangeOfString:@"python" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"py";
	else if ([firstLine rangeOfString:@"awk" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"awk";
	else if ([firstLine rangeOfString:@"xml" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"xml";
	else if ([firstLine rangeOfString:@"ruby" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"rb";
	else if ([firstLine rangeOfString:@"%!ps" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"ps";
	else if ([firstLine rangeOfString:@"%pdf" options:NSCaseInsensitiveSearch range:firstLineRange].location != NSNotFound)
		returnString = @"pdf";
	else
		returnString = @"";
	
	return returnString;
}

- (NSArray *)textView:(NSTextView *)theTextView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger*)index
{
	if ([[self keywordsAndAutocompleteWords] count] == 0) {
		return words;
	}
	
	NSString *matchString = [[theTextView string] substringWithRange:charRange];
	NSMutableArray *finalWordsArray = [[NSMutableArray alloc] initWithArray:[self keywordsAndAutocompleteWords]];
	if ([userDefaults boolForKey:@"AutocompleteIncludeStandardWords"]) {
		[finalWordsArray addObjectsFromArray:words];
	}
	
	NSMutableArray *matchArray = [[[NSMutableArray alloc] init] autorelease];
	NSEnumerator *enumerator = [finalWordsArray objectEnumerator];
	NSString *item;
	while ((item = [enumerator nextObject]))
  {
		if ([item rangeOfString:matchString options:NSCaseInsensitiveSearch range:NSMakeRange(0, [item length])].location == 0)
			[matchArray addObject:item];
	}
	[finalWordsArray release];
	
	if ([userDefaults boolForKey:@"AutocompleteIncludeStandardWords"]) { // if no standard words are added there's no need to sort it again as it has already been sorted
		return [matchArray sortedArrayUsingSelector:@selector(compare:)];
	} else {
		return matchArray;
	}
}

-(void)checkIfCanUndo
{
	if (![undoManager canUndo])
  {
		//[[SMLDocumentsArray sharedInstance] setCurrentDocumentIsEdited:NO];
		//[[SMLMainController sharedInstance] setEditedBlob];
		//[[SMLMainController sharedInstance] reloadDataInTableView];
	}
}

-(void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self->startPageRecolourTimer invalidate];
	[self->startPageRecolourTimer release];
	[self->startCompleteRecolourTimer invalidate];
	[self->startCompleteRecolourTimer release];
	
	[self->undoManager release];
	[self->commandsColour release];
	[self->commentsColour release];
	[self->instructionsColour release];
	[self->keywordsColour release];
	[self->stringsColour release];
	[self->variablesColour release];
	
	[self->highlightColour release];
	
	[self->wordEnumerator release];
  [self->keywords release];
	[self->autocompleteWords release];
	[self->keywordsAndAutocompleteWords release];
  [self->beginCommand release];
  [self->endCommand release];
  [self->beginInstruction release];
  [self->endInstruction release];
  [self->beginVariable release];
  [self->endVariable release];
  [self->firstString release];
  [self->secondString release];
  [self->firstSingleLineComment release];
	[self->secondSingleLineComment release];
  [self->beginFirstMultiLineComment release];
  [self->endFirstMultiLineComment release];
  [self->beginSecondMultiLineComment release];
  [self->endSecondMultiLineComment release];
	[self->syntaxDefinitionName release];
	
	[self->keywordStartCharacterSet release];
	[self->keywordEndCharacterSet release];
  
	[super dealloc];
}
@end
