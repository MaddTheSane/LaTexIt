//  MyDocument.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright Pierre Chatelier 2005 . All rights reserved.

// The main document of LaTeXiT. There is much to say !

#import "MyDocument.h"

#import "AppController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "HistoryView.h"
#import "LibraryDrawer.h"
#import "LibraryFile.h"
#import "LibraryItem.h"
#import "LibraryManager.h"
#import "LibraryView.h"
#import "LineCountTextView.h"
#import "LogTableView.h"
#import "MarginController.h"
#import "MyImageView.h"
#import "NSApplicationExtended.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSSegmentedControlExtended.h"
#import "NSStringExtended.h"
#import "NSTaskExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"

#ifdef PANTHER
#import <LinkBack-panther/LinkBack.h>
#else
#import <LinkBack/LinkBack.h>
#endif

#ifndef PANTHER
#import <Quartz/Quartz.h>
#endif

//In MacOS 10.4.0, 10.4.1 and 10.4.2, these constants are declared but not defined in the PDFKit.framework!
//So I define them myself, but it is ugly. I expect next versions of MacOS to fix that
NSString* PDFDocumentCreatorAttribute = @"Creator"; 
NSString* PDFDocumentKeywordsAttribute = @"Keywords";

//useful to assign a unique id to each document
static unsigned long firstFreeId = 1; //increases when documents are created

//if a document is closed, its id becomes free, and we should consider reusing it instead of increasing firstFreeId
static NSMutableArray* freeIds = nil;

const static int ComposeNoOptions = 0;
const static int ComposeUsingPdfLatex = 0;
const static int ComposeUsingLatexAndDvipdf = 1;

@interface MyDocument (PrivateAPI)

+(unsigned long) _giveId; //returns a free id and marks it as used
+(void) _releaseId:(unsigned long)anId; //releases an id

//compose latex and returns pdf data. the options may specify to use pdflatex or latex+dvipdf
-(NSData*) _composeLaTeX:(NSString*)filePath stdoutLog:(NSString**)stdoutLog stderrLog:(NSString**)stderrLog options:(int)options;

//returns an array of the errors. Each case will contain an error string
-(NSArray*) _filterLatexErrors:(NSString*)fullErrorLog;

//updates the logTableView to report the errors
-(void) _analyzeErrors:(NSArray*)errors;

//computes the tight bounding box of a pdfFile
-(NSRect) _computeBoundingBox:(NSString*)pdfFilePath;

-(void) _lineCountDidChange:(NSNotification*)aNotification;
-(void) _historyDidChange:(NSNotification*)aNotification;
-(void) _selectionDidChange:(NSNotification*)aNotification;
-(void) _clickErrorLine:(NSNotification*)aNotification;
-(void) _historySelectionDidChange;
-(void) _librarySelectionDidChange;

-(void) _setLogTableViewVisible:(BOOL)status;

-(NSString*) _replaceYenSymbol:(NSString*)string; //in Japanese environment, we should replace the Yen symbol by a backslash

-(void) _clearHistorySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
@end

@implementation MyDocument

static NSString* yenString = nil;

+(void) initialize
{
  if (!freeIds)
    freeIds = [[NSMutableArray alloc] init];
  if (!yenString)
  {
    unichar yenChar = 0x00a5;
    yenString = [[NSString stringWithCharacters:&yenChar length:1] retain]; //the yen symbol as a string
  }
}

//returns a free id and marks it as used
+(unsigned long) _giveId
{
  unsigned long anId = firstFreeId;
  @synchronized(freeIds)
  {
    if ([freeIds count]) //first, look into recently released id
    {
      anId = [[freeIds lastObject] unsignedLongValue];
      [freeIds removeLastObject];
    }
    else //if not available, use firstFreeId
      ++firstFreeId;
  }
  return anId;
}

//marks an id as free, and put it into the freeIds array
+(void) _releaseId:(unsigned long) anId
{
  @synchronized(freeIds)
  {
    [freeIds addObject:[NSNumber numberWithUnsignedLong:anId]];
  }
}

-(id) init
{
  self = [super init];
  if (self)
  {
    uniqueId = [MyDocument _giveId];
    jpegQuality = 90;
    jpegColor = [[NSColor whiteColor] retain];
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(_lineCountDidChange:)
                               name:LineCountDidChangeNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(_selectionDidChange:)
                               name:NSTableViewSelectionDidChangeNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(_selectionDidChange:)
                               name:NSOutlineViewSelectionDidChangeNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(_clickErrorLine:)
                               name:ClickErrorLineNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(_historyDidChange:)
                               name:HistoryDidChangeNotification object:nil];
  }
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [MyDocument _releaseId:uniqueId];
  [saveAccessoryView release];
  [jpegColor release];
  [self closeLinkBackLink:linkBackLink];
  [super dealloc];
}

-(void) setNullId//useful for dummy document of AppController
{
  [MyDocument _releaseId:uniqueId];
  uniqueId = 0;
}

-(NSString *) windowNibName
{
    //Override returning the nib file name of the document
    //If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers,
    //you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

-(void) windowControllerDidLoadNib:(NSWindowController *) aController
{
  [super windowControllerDidLoadNib:aController];
  
  [[self windowForSheet] setFrameAutosaveName:[NSString stringWithFormat:@"LaTeXiT-window-%u", uniqueId]];

  //to paste rich LaTeXiT data, we must tune the responder chain  
  [sourceTextView setNextResponder:imageView];

  //useful to avoid conflicts between mouse clicks on imageView and the progressIndicator
  [progressIndicator setNextResponder:imageView];
  
  [saveAccessoryView retain]; //to avoid unwanted deallocation when save panel is closed
  
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  [[typeOfTextControl cell] setTag:DISPLAY forSegment:0];
  [[typeOfTextControl cell] setTag:INLINE  forSegment:1];
  [[typeOfTextControl cell] setTag:TEXT  forSegment:2];
  [typeOfTextControl selectSegmentWithTag:[userDefaults integerForKey:DefaultModeKey]];
  
  [sizeText setDoubleValue:[userDefaults floatForKey:DefaultPointSizeKey]];

  NSColor* initialColor = [[AppController appController] isColorStyAvailable] ?
                              [NSColor colorWithData:[userDefaults dataForKey:DefaultColorKey]] : [NSColor blackColor];
  [colorWell setColor:initialColor];

  NSFont* defaultFont = [NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]];
  [preambleTextView setTypingAttributes:[NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName]];
  [sourceTextView   setTypingAttributes:[NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName]];

  //the initial... variables has been set into a readFromFile
  if (initialPreamble)
  {
    [self setPreamble:[[[NSAttributedString alloc] initWithString:initialPreamble] autorelease]];
    initialPreamble = nil;
  }
  else
  {
    [preambleTextView setForbiddenLine:0 forbidden:YES];
    [preambleTextView setForbiddenLine:1 forbidden:YES];
    [self setPreamble:[[AppController appController] preamble]];
  }
  
  if (initialBody)
  {
    [typeOfTextControl setSelectedSegment:[[typeOfTextControl cell] tagForSegment:TEXT]];
    [self setSourceText:[[[NSAttributedString alloc] initWithString:initialBody] autorelease]];
    initialBody = nil;
  }
  
  if (initialPdfData)
  {
    [self applyPdfData:initialPdfData];
    initialPdfData = nil;
  }

  [historyDrawer setDelegate:self];
  [self _historyDidChange:nil];

  [libraryDrawer setDelegate:self];

  [self updateAvailabilities]; //updates interface to allow latexisation or not, according to current configuration
}

//set the document title that will be displayed as window title. There is no represented file associated
-(void) setDocumentTitle:(NSString*)title
{
  [title retain];
  [documentTitle release];
  documentTitle = title;
  [[[self windowForSheet] windowController] synchronizeWindowTitleWithDocumentName];
}

//some accessors useful sometimes
-(LineCountTextView*) sourceTextView
{
  return sourceTextView;
}

-(NSButton*) makeLatexButton
{
  return makeLatexButton;
}

//automatically called by Cocoa. The name of the document has nothing to do with a represented file
-(NSString*) displayName
{
  NSString* title = documentTitle;
  if (!title)
     title = [NSApp applicationName];
  title = [NSString stringWithFormat:@"%@-%u", title, uniqueId];
  return title;
}

//updates interface to allow latexisation or not, according to current configuration
-(void) updateAvailabilities
{
  AppController* appController = [AppController appController];
  BOOL makeLatexButtonEnabled = [appController isPdfLatexAvailable] && [appController isGsAvailable];
  [makeLatexButton setEnabled:makeLatexButtonEnabled];
  [makeLatexButton setNeedsDisplay:YES];
  if (makeLatexButtonEnabled)
    [makeLatexButton setToolTip:nil];
  else if (![makeLatexButton toolTip])
    [makeLatexButton setToolTip:
      NSLocalizedString(@"pdflatex and/or gs seem unavailable in your system. Please check their installation.",
                        @"pdflatex and/or gs seem unavailable in your system. Please check their installation.")];
  
  BOOL colorStyEnabled = [appController isColorStyAvailable];
  [colorWell setEnabled:colorStyEnabled];
  [colorWell setNeedsDisplay:YES];
  if (colorStyEnabled)
    [colorWell setToolTip:nil];
  else if (![colorWell toolTip])
    [colorWell setToolTip:
      NSLocalizedString(@"color.sty package seems not to be present in your LaTeX installation. "\
                        @"So, color font change is disabled.",
                        @"color.sty package seems not to be present in your LaTeX installation. "\
                        @"So, color font change is disabled.")];

  [[self windowForSheet] display];
}

-(NSData*) dataRepresentationOfType:(NSString *)aType
{
    // Insert code here to write your document from the given data.
    // You can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.
    return nil;
}

//LaTeXiT can open documents
-(BOOL) readFromFile:(NSString *)file ofType:(NSString *)aType
{
  //Insert code here to read your document from the given data.
  //You can also choose to override -loadFileWrapperRepresentation:ofType: or -readFromFile:ofType: instead.
  NSData* data = [NSData dataWithContentsOfFile:file];
  NSString* type = [[file pathExtension] lowercaseString];
  NSString* string = nil;
  if ([type isEqualToString:@"rtf"])
    string = [[[[NSAttributedString alloc] initWithRTF:data documentAttributes:nil] autorelease] string];
  else if ([type isEqualToString:@"pdf"])
    initialPdfData = [NSData dataWithContentsOfFile:file];
  else //by default, we suppose that it is a plain text file
  {
    NSStringEncoding encoding = NSMacOSRomanStringEncoding;
    NSError* error = nil;
    string = [NSString stringWithContentsOfFile:file guessEncoding:&encoding error:&error];
    #ifndef PANTHER
    if (error)
      [self presentError:error];
    #endif
  }

  //if a text document is opened, try to split it into preamble+body
  if (string)
  {
	  NSRange beginDocument = [string rangeOfString:@"\\begin{document}" options:NSCaseInsensitiveSearch];
	  NSRange endDocument   = [string rangeOfString:@"\\end{document}" options:NSCaseInsensitiveSearch];
	  initialPreamble = (beginDocument.location == NSNotFound) ?
							  nil :
							  [string substringWithRange:NSMakeRange(0, beginDocument.location)];
	  initialBody = (beginDocument.location == NSNotFound) ?
						  string :
						  (endDocument.location == NSNotFound) ?
							 [string substringWithRange:
							   NSMakeRange(beginDocument.location+beginDocument.length,
										   [string length]-(beginDocument.location+beginDocument.length))] :
							 [string substringWithRange:
							   NSMakeRange(beginDocument.location+beginDocument.length,
										   endDocument.location-(beginDocument.location+beginDocument.length))];
  }
  return YES;
}

//in Japanese environment, we should replace the Yen symbol by a backslash
//You can read http://www.xs4all.nl/~msneep/articles/japanese.html to know more about that problem
-(NSString*) _replaceYenSymbol:(NSString*)stringWithYen; 
{
  NSMutableString* stringWithBackslash = [NSMutableString stringWithString:stringWithYen];
  [stringWithBackslash replaceOccurrencesOfString:yenString withString:@"\\"
                                          options:NSLiteralSearch range:NSMakeRange(0, [stringWithBackslash length])];
  return stringWithBackslash;
}

-(IBAction) colorDidChange:(id)sender
{
}

//when the linecount changes in the preamble view, the numerotation must change in the body view
-(void) _lineCountDidChange:(NSNotification*)aNotification
{
  if ([aNotification object] == preambleTextView)
    [sourceTextView setLineShift:[[preambleTextView lineRanges] count]];
}

-(void) setFont:(NSFont*)font//changes the font of both preamble and sourceText views
{
  [[preambleTextView textStorage] setFont:font];
  [[sourceTextView textStorage] setFont:font];
}

-(void) setPreamble:(NSAttributedString*)aString
{
  [preambleTextView clearErrors];
  [[preambleTextView textStorage] setAttributedString:aString];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preambleTextView];
  [preambleTextView setNeedsDisplay:YES];
}

-(void) setSourceText:(NSAttributedString*)aString
{
  [sourceTextView clearErrors];
  [[sourceTextView textStorage] setAttributedString:aString];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:sourceTextView];
  [sourceTextView setNeedsDisplay:YES];
}

//called by the Latexise button; will launch the latexisation
-(IBAction) makeLatex:(id)sender
{
  NSString* body = [sourceTextView string];
  BOOL mustProcess = (body && [body length]);

  if (!mustProcess)
  {
    NSAlert* alert = 
      [NSAlert alertWithMessageText:NSLocalizedString(@"Empty LaTeX body", @"Empty LaTeX body")
                      defaultButton:NSLocalizedString(@"Cancel", @"Cancel")
                    alternateButton:NSLocalizedString(@"Process anyway", @"Process anyway")
                        otherButton:nil
          informativeTextWithFormat:NSLocalizedString(@"You did not type any text in the body. The result will certainly be empty.",
                                                      @"You did not type any text in the body. The result will certainly be empty.")];
     int result = [alert runModal];
     mustProcess = (result == NSAlertAlternateReturn);
  }
  
  if (mustProcess)
  {
    [imageView setPdfData:nil cachedImage:nil];       //clears current image
    [imageView setNeedsDisplay:YES];
    [imageView displayIfNeeded];      //refresh it
    [progressIndicator setHidden:NO]; //shows the progress indicator
    [progressIndicator startAnimation:self];
    isBusy = YES; //marks as busy
    
    //computes the parameters thanks to the value of the GUI elements
    NSString* preamble = [[[preambleTextView string] mutableCopy] autorelease];
    NSColor* color = [[[colorWell color] copy] autorelease];
    int selectedSegment = [typeOfTextControl selectedSegment];
    latex_mode_t mode = (latex_mode_t) [[typeOfTextControl cell] tagForSegment:selectedSegment];
    
    //perform effective latexisation
    NSData* pdfData = [self latexiseWithPreamble:preamble body:body color:color mode:mode
                                   magnification:[sizeText doubleValue]];

    //did it work ?
    BOOL failed = !pdfData;
    if (!failed)
    {
      //if it is ok, updates the image view
      [imageView setPdfData:pdfData cachedImage:nil];

      //and insert a new element into the history
      [[HistoryManager sharedManager] addItem:[self historyItemWithCurrentState]];
      [historyView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
      
      //updates the pasteboard content for a live Linkback link, and triggers a sendEdit
      [imageView updateLinkBackLink:linkBackLink];
    }
    
    //hides progress indicator
    [progressIndicator stopAnimation:self];
    [progressIndicator setHidden:YES];
    
    //hides/how the error view
    [self _setLogTableViewVisible:[logTableView numberOfRows]];
    
    //not busy any more
    isBusy = NO;
  }//end if mustProcess
}  

//computes the tight bounding box of a pdfFile
-(NSRect) _computeBoundingBox:(NSString*)pdfFilePath
{
  NSRect boundingBoxRect = NSMakeRect(0, 0, 0, 0);
  
  //We will rely on GhostScript (gs) to compute the bounding box
  NSFileManager* fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:pdfFilePath])
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  
    NSString* directory      = NSTemporaryDirectory();

    NSTask* boundingBoxTask  = [[NSTask alloc] init];
    NSPipe* gs2awkPipe       = [NSPipe pipe];
    NSPipe* outPipe          = [NSPipe pipe];
    NSFileHandle* nullDevice = [NSFileHandle fileHandleWithNullDevice];
    [boundingBoxTask setCurrentDirectoryPath:directory];
    [boundingBoxTask setEnvironment:[AppController environmentDict]];
    [boundingBoxTask setLaunchPath:[userDefaults stringForKey:GsPathKey]];
    [boundingBoxTask setArguments:[NSArray arrayWithObjects:@"-dNOPAUSE",@"-sDEVICE=bbox",@"-dBATCH",@"-q", pdfFilePath, nil]];
    [boundingBoxTask setStandardOutput:gs2awkPipe];
    [boundingBoxTask setStandardError:gs2awkPipe];
    
    NSTask* awkTask = [[NSTask alloc] init];
    [awkTask setCurrentDirectoryPath:directory];
    [awkTask setEnvironment:[AppController environmentDict]];
    [awkTask setLaunchPath:[[AppController appController] findUnixProgram:@"awk" tryPrefixes:[AppController unixBins]
                             environment:[awkTask environment]]];
    [awkTask setArguments:[NSArray arrayWithObjects:@"-F:", @"/%%HiResBoundingBox/{printf \"%s\",substr($2, 2, length($2)-1)}", nil]];
    [awkTask setStandardInput:gs2awkPipe];
    [awkTask setStandardOutput:outPipe];
    [awkTask setStandardError:nullDevice];

    @try
    {
      [boundingBoxTask launch];
      [awkTask         launch];
      [boundingBoxTask waitUntilExit];
      [awkTask         waitUntilExit];
    }
    @catch(NSException* e)
    {
    }
    @finally
    {
      [boundingBoxTask release];
      [awkTask         release];
    }

    NSData*   boundingBoxData   = [[outPipe fileHandleForReading] availableData];
    NSString* boundingBoxString = [[[NSString alloc] initWithData:boundingBoxData encoding:NSUTF8StringEncoding] autorelease];
    NSScanner* scanner = [NSScanner scannerWithString:boundingBoxString];
    NSRect tmpRect = NSMakeRect(0, 0, 0, 0);
    [scanner scanFloat:&tmpRect.origin.x];
    [scanner scanFloat:&tmpRect.origin.y];
    [scanner scanFloat:&tmpRect.size.width];
    [scanner scanFloat:&tmpRect.size.height];
    
    boundingBoxRect = tmpRect; //here I use a tmpRect because gcc version 4.0.0 (Apple Computer, Inc. build 5026) issues a strange warning
    //it considers <boundingBoxRect> to be const when the try/catch/finally above is here. If you just comment try/catch/finally, the
    //warning would disappear
  }
  return boundingBoxRect;
}

//compose latex and returns pdf data. the options may specify to use pdflatex or latex+dvipdf
-(NSData*) _composeLaTeX:(NSString*)filePath stdoutLog:(NSString**)stdoutLog stderrLog:(NSString**)stderrLog options:(int)options
{
  NSData* pdfData = nil;
  
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  
  NSString* directory = [filePath stringByDeletingLastPathComponent];
  NSString* texFile   = filePath;
  NSString* dviFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"dvi"];
  NSString* pdfFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
  NSString* errFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"err"];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  [fileManager removeFileAtPath:dviFile handler:nil];
  [fileManager removeFileAtPath:pdfFile handler:nil];
  
  NSMutableString* stdoutString = [NSMutableString string];
  NSMutableString* stderrString = [NSMutableString string];

  NSString* source = [NSString stringWithContentsOfFile:texFile];
  [stdoutString appendString:[NSString stringWithFormat:@"Source :\n%@\n", source ? source : @""]];

  //it happens that the NSTask fails for some strange reason (fflush problem...), so I will use a simple and ugly system() call
  NSString* systemCall = [NSString stringWithFormat:@"cd %@ && pdflatex %@ -file-line-error -interaction nonstopmode %@ > %@", 
                          directory, (options & ComposeUsingLatexAndDvipdf) ? @"-progname latex" : @"", texFile, errFile];
  [stdoutString appendString:[NSString stringWithFormat:@"\n--------------- %@ ---------------\n%@\n",
                                                        NSLocalizedString(@"processing pdflatex", @"processing pdflatex"),
                                                        systemCall]];
  BOOL failed = (system([systemCall UTF8String]) != 0);
  NSString* errors = [NSString stringWithContentsOfFile:errFile];
  [stdoutString appendString:errors ? errors : @""];
  
  if (failed)
    [stdoutString appendString:[NSString stringWithFormat:@"\n--------------- %@ ---------------\n",
                               NSLocalizedString(@"error while processing pdflatex", @"error while processing pdflatex")]];

  //if !failed and must call dvipdf...
  if (!failed && (options & ComposeUsingLatexAndDvipdf))
  {
    NSTask* dvipdfTask = [[NSTask alloc] init];
    [dvipdfTask setCurrentDirectoryPath:directory];
    [dvipdfTask setEnvironment:[AppController environmentDict]];
    [dvipdfTask setLaunchPath:[userDefaults stringForKey:DvipdfPathKey]];
    [dvipdfTask setArguments:[NSArray arrayWithObject:dviFile]];
    NSPipe* stdoutPipe2 = [NSPipe pipe];
    NSPipe* stderrPipe2 = [NSPipe pipe];
    [dvipdfTask setStandardOutput:stdoutPipe2];
    [dvipdfTask setStandardError:stderrPipe2];

    @try
    {
      [stdoutString appendString:[NSString stringWithFormat:@"\n--------------- %@ ---------------\n%@\n",
                                                            NSLocalizedString(@"processing dvipdf", @"processing dvipdf"),
                                                            [dvipdfTask commandLine]]];
      [dvipdfTask launch];
      [dvipdfTask waitUntilExit];
      NSData* stdoutData = [[stdoutPipe2 fileHandleForReading] availableData];
      NSData* stderrData = [[stderrPipe2 fileHandleForReading] availableData];
      NSString* tmp = nil;
      tmp = stdoutData ? [[[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] autorelease] : nil;
      if (tmp)
        [stdoutString appendString:tmp];
      tmp = stderrData ? [[[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] autorelease] : nil;
      if (tmp)
        [stderrString appendString:tmp];
      failed = ([dvipdfTask terminationStatus] != 0);
    }
    @catch(NSException* e)
    {
      failed = YES;
      [stdoutString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", [e name], [e reason]]];
    }
    @finally
    {
      [dvipdfTask release];
    }
    
    if (failed)
      [stdoutString appendString:[NSString stringWithFormat:@"\n--------------- %@ ---------------\n",
                                 NSLocalizedString(@"error while processing dvipdf", @"error while processing dvipdf")]];

  }//end of dvipdf call
  
  if (stdoutLog)
    *stdoutLog = stdoutString;
  if (stderrLog)
    *stderrLog = stderrString;
  
  if (!failed && [[NSFileManager defaultManager] fileExistsAtPath:pdfFile])
    pdfData = [NSData dataWithContentsOfFile:pdfFile];

  return pdfData;
}

//latexise and returns the pdf result, cropped, magnified, coloured, with pdf meta-data
-(NSData*) latexiseWithPreamble:(NSString*)preamble body:(NSString*)body color:(NSColor*)color mode:(latex_mode_t)mode 
                  magnification:(double)magnification
{
  NSData* pdfData = nil;

  //this function is rather long, because it is not quite easy to get a tight image (well cropped)
  //and magnification.
  //The principle used is the following one :
  //  -first, we compute a very simple latex file, without cropping or magnification. If there are no syntax errors
  //   from the user, it will be ok. Otherwise, it will be useful to report errors to the user.
  //  -second, we must crop and magnify. There is a very fast an efficient method, using boxes that will automagically
  //   know their size, and even compute the *baseline* (what is the baseline ? it is the line on which your equation should be
  //   aligned to fit well inside some text. For instance, a fraction would be shifted down, thanks to a negative baseline)
  //   The problem is that, this fast and efficient method may fail with certain kinds of equations (especially multi-lines)
  //   So it is just a try; if it works, that's great, we keep the result. Otherwise, we will use a heavy but more robust method
  //  -third; in case that the second step failed, there is as a last resort a heavy and robust method to compute a bounding box
  //   (to crop), and magnify the document. We compute the bounding box by calling gs (GhostScript) on the result of the first step.
  //   Then, we use the latex template of the second step, with the magical boxes, but its body will just be the pdf image generated
  //   during the first step ! So it can be cropped and magnify.
  //
  //All these steps need many intermediate files, so don't be surprised if you feel a little lost
  
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  int compositionMode = [userDefaults integerForKey:CompositionModeKey];
  compositionMode = (compositionMode == 0) ? ComposeUsingPdfLatex : ComposeUsingLatexAndDvipdf;

  //prepare file names
  NSString* directory      = NSTemporaryDirectory();
  NSString* filePrefix     = [NSString stringWithFormat:@"latexit-%u", uniqueId]; //file name, related to the current document

  //latex files for step 1 (simple latex file useful to report errors, log file and pdf result)
  NSString* latexFile             = [NSString stringWithFormat:@"%@.tex", filePrefix];
  NSString* latexFilePath         = [directory stringByAppendingPathComponent:latexFile];
  NSString* latexAuxFile          = [NSString stringWithFormat:@"%@.aux", filePrefix];
  NSString* latexAuxFilePath      = [directory stringByAppendingPathComponent:latexAuxFile];
  NSString* pdfFile               = [NSString stringWithFormat:@"%@.pdf", filePrefix];
  NSString* pdfFilePath           = [directory stringByAppendingPathComponent:pdfFile];
  
  //the files useful for step 2 (tex file with magical boxes, pdf result, and a file summarizing the bounding box and baseline)
  NSString* latexBaselineFile        = [NSString stringWithFormat:@"%@-baseline.tex", filePrefix];
  NSString* latexBaselineFilePath    = [directory stringByAppendingPathComponent:latexBaselineFile];
  NSString* latexAuxBaselineFile     = [NSString stringWithFormat:@"%@-baseline.aux", filePrefix];
  NSString* latexAuxBaselineFilePath = [directory stringByAppendingPathComponent:latexAuxBaselineFile];
  NSString* pdfBaselineFile          = [NSString stringWithFormat:@"%@-baseline.pdf", filePrefix];
  NSString* pdfBaselineFilePath      = [directory stringByAppendingPathComponent:pdfBaselineFile];
  NSString* sizesFile                = [NSString stringWithFormat:@"%@-baseline.sizes", filePrefix];
  NSString* sizesFilePath            = [directory stringByAppendingPathComponent:sizesFile];
  
  //the files useful for step 3 (tex file with magical boxes encapsulating the image generated during step 1), and pdf result
  NSString* latexFile2        = [NSString stringWithFormat:@"%@-2.tex", filePrefix];
  NSString* latexFilePath2    = [directory stringByAppendingPathComponent:latexFile2];
  NSString* latexAuxFile2     = [NSString stringWithFormat:@"%@-2.aux", filePrefix];
  NSString* latexAuxFilePath2 = [directory stringByAppendingPathComponent:latexAuxFile2];
  NSString* pdfFile2          = [NSString stringWithFormat:@"%@-2.pdf", filePrefix];
  NSString* pdfFilePath2      = [directory stringByAppendingPathComponent:pdfFile2];

  //trash old files
  NSFileManager* fileManager = [NSFileManager defaultManager];
  [fileManager removeFileAtPath:latexFilePath            handler:nil];
  [fileManager removeFileAtPath:latexAuxFilePath         handler:nil];
  [fileManager removeFileAtPath:latexFilePath2           handler:nil];
  [fileManager removeFileAtPath:latexAuxFilePath2        handler:nil];
  [fileManager removeFileAtPath:pdfFilePath              handler:nil];
  [fileManager removeFileAtPath:pdfFilePath2             handler:nil];
  [fileManager removeFileAtPath:latexBaselineFilePath    handler:nil];
  [fileManager removeFileAtPath:latexAuxBaselineFilePath handler:nil];
  [fileManager removeFileAtPath:pdfBaselineFilePath      handler:nil];
  [fileManager removeFileAtPath:sizesFilePath            handler:nil];

  //some tuning due to parameters; note that \[...\] is replaced by $\displaystyle because of
  //incompatibilities with the magical boxes
  NSString* addSymbolLeft  = (mode == DISPLAY) ? @"$\\displaystyle " : (mode == INLINE) ? @"$" : @"";
  NSString* addSymbolRight = (mode == DISPLAY) ? @"$" : (mode == INLINE) ? @"$" : @"";
  NSString* colouredPreamble = [[AppController appController] insertColorInPreamble:preamble color:color];
  
  NSMutableString* fullLog = [NSMutableString string];

  //STEP 1
  //first, creates simple latex source text to compile and report errors (if there are any)
  NSString* normalSourceToCompile =
    [NSString stringWithFormat:
      @"%@\n\\pagestyle{empty} "\
       "\\begin{document}"\
       "%@%@%@"\
       "\\end{document}", [self _replaceYenSymbol:colouredPreamble], addSymbolLeft, [self _replaceYenSymbol:body], addSymbolRight];

  //creates the corresponding latex file
  NSData* latexData = [normalSourceToCompile dataUsingEncoding:NSUTF8StringEncoding];
  BOOL failed = ![latexData writeToFile:latexFilePath atomically:NO];
  
  NSString* stdoutLog = nil;
  NSString* stderrLog = nil;
  failed |= ![self _composeLaTeX:latexFilePath stdoutLog:&stdoutLog stderrLog:&stderrLog options:compositionMode];
  if (stdoutLog)
    [fullLog appendString:stdoutLog];
  [logTextView setString:fullLog];

  NSArray* errors = [self _filterLatexErrors:[stdoutLog stringByAppendingString:stderrLog]];
  [self _analyzeErrors:errors];
  //STEP 1 is over. If it has failed, it is the fault of the user, and syntax errors will be reported
  
  //STEP 2
  BOOL shouldTryStep2 = (mode != TEXT) && (compositionMode != ComposeUsingLatexAndDvipdf);
  //But if the latex file passed this first latexisation, it is time to start step 2 and perform cropping and magnification.
  if (!failed)
  {
    if (shouldTryStep2) //we do not even try step 2 in TEXT mode, since we will perform step 3 to allow line breakings
    {
      //this magical template uses boxes that scales and automagically find their own geometry
      //But it may fail for some kinds of equation, especially multi-lines equations. However, we try it because it is fast
      //and efficient. This will even generated a baseline if it works !
      NSString* magicSourceToFindBaseLine =
        [NSString stringWithFormat:
          @"%@\n"
          "\\pagestyle{empty}\n"\
          "\\usepackage{geometry}\n"\
          "\\usepackage{graphicx}\n"\
          "\\newsavebox{\\latexitbox}\n"\
          "\\newcommand{\\latexitscalefactor}{%f}\n"\
          "\\newlength{\\latexitwidth}\n\\newlength{\\latexitheight}\n\\newlength{\\latexitdepth}\n"\
          "\\setlength{\\topskip}{0pt}\n\\setlength{\\parindent}{0pt}\n\\setlength{\\abovedisplayskip}{0pt}\n"\
          "\\setlength{\\belowdisplayskip}{0pt}\n"\
          "\\normalfont\n"\
          "\\begin{lrbox}{\\latexitbox}\n"\
          "%@%@%@\n"\
          "\\end{lrbox}\n"\
          "\\settowidth{\\latexitwidth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"\
          "\\settoheight{\\latexitheight}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"\
          "\\settodepth{\\latexitdepth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"\
          "\\newwrite\\foo \\immediate\\openout\\foo=\\jobname.sizes \\immediate\\write\\foo{\\the\\latexitdepth (Depth)}\n"\
          "\\immediate\\write\\foo{\\the\\latexitheight (Height)}\n"\
          "\\addtolength{\\latexitheight}{\\latexitdepth}\n"\
          "\\addtolength{\\latexitheight}{%f pt}\n"\
          "\\addtolength{\\latexitheight}{%f pt}\n"\
          "\\addtolength{\\latexitwidth}{%f pt}\n"\
          "\\immediate\\write\\foo{\\the\\latexitheight (TotalHeight)} \\immediate\\write\\foo{\\the\\latexitwidth (Width)}\n"\
          "\\closeout\\foo \\geometry{paperwidth=\\latexitwidth,paperheight=\\latexitheight,margin=0pt,left=%f pt,top=%f pt}\n"\
          "\\begin{document}\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}\\end{document}\n",
          [self _replaceYenSymbol:colouredPreamble], magnification/10.0,
          addSymbolLeft, [self _replaceYenSymbol:body], addSymbolRight,
          200*magnification/10000,
          [MarginController topMargin]+[MarginController bottomMargin],[MarginController leftMargin]+[MarginController rightMargin],
          [MarginController leftMargin],[MarginController topMargin]
          ];
      
      //try to latexise that file
      NSData* latexData = [magicSourceToFindBaseLine dataUsingEncoding:NSUTF8StringEncoding];  
      failed |= ![latexData writeToFile:latexBaselineFilePath atomically:NO];
      
      if (!failed)
        pdfData = [self _composeLaTeX:latexBaselineFilePath stdoutLog:&stdoutLog stderrLog:&stderrLog options:compositionMode];
      failed |= !pdfData;
    }//end of step 2
    
    //Now, step 2 may have failed. We check it. If it has not failed, that's great, the pdf result is the one we wanted !
    float baseline = 0;
    if (!failed && shouldTryStep2)
    {
      //try to read the baseline in the "sizes" file magically generated
      NSString* sizes = [NSString stringWithContentsOfFile:sizesFilePath];
      NSScanner* scanner = [NSScanner scannerWithString:sizes];
      [scanner scanFloat:&baseline];
      //Step 2 is over, it has worked, so step 3 is useless.
    }
    //STEP 3
    else //if step 2 failed, we must use the heavy method of step 3
    {
      failed = NO; //since step 3 is a resort, step 2 is not a real failure, so we reset <failed> to NO
      pdfData = nil;
      NSRect boundingBox = [self _computeBoundingBox:pdfFilePath]; //compute the bounding box of the pdf file generated during step 1
      boundingBox.origin.x    -= [MarginController leftMargin]/(magnification/10);
      boundingBox.origin.y    -= [MarginController bottomMargin]/(magnification/10);
      boundingBox.size.width  += [MarginController rightMargin]/(magnification/10);
      boundingBox.size.height += [MarginController topMargin]/(magnification/10);

      //then use the bounding box and the magnification in the magic-box-template, the body of which will be a mere \includegraphics
      //of the pdf file of step 1
      NSString* magicSourceToProducePDF =
        [NSString stringWithFormat:
          @"%@\n"
          "\\pagestyle{empty}\n"\
          "\\usepackage{geometry}\n"\
          "\\usepackage{graphicx}\n"\
          "\\newsavebox{\\latexitbox}\n"\
          "\\newcommand{\\latexitscalefactor}{%f}\n"\
          "\\newlength{\\latexitwidth}\n\\newlength{\\latexitheight}\n\\newlength{\\latexitdepth}\n"\
          "\\setlength{\\topskip}{0pt}\n\\setlength{\\parindent}{0pt}\n\\setlength{\\abovedisplayskip}{0pt}\n"\
          "\\setlength{\\belowdisplayskip}{0pt}\n"\
          "\\normalfont\n"\
          "\\begin{lrbox}{\\latexitbox}\n"\
          "\\includegraphics[viewport = %f %f %f %f]{%@}\n"\
          "\\end{lrbox}\n"\
          "\\settowidth{\\latexitwidth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"\
          "\\settoheight{\\latexitheight}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"\
          "\\settodepth{\\latexitdepth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"\
          "\\newwrite\\foo \\immediate\\openout\\foo=\\jobname.sizes \\immediate\\write\\foo{\\the\\latexitdepth (Depth)}\n"\
          "\\immediate\\write\\foo{\\the\\latexitheight (Height)}\n"\
          "\\addtolength{\\latexitheight}{\\latexitdepth}\n"\
          "\\addtolength{\\latexitheight}{%f pt}\n"\
          "\\immediate\\write\\foo{\\the\\latexitheight (TotalHeight)} \\immediate\\write\\foo{\\the\\latexitwidth (Width)}\n"\
          "\\closeout\\foo \\geometry{paperwidth=\\latexitwidth,paperheight=\\latexitheight,margin=0pt}\n"\
          "\\begin{document}\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}\\end{document}\n", 
          [self _replaceYenSymbol:colouredPreamble], magnification/10.0,
          boundingBox.origin.x, boundingBox.origin.y, boundingBox.size.width, boundingBox.size.height,
          pdfFile, 200*magnification/10000];

      //Latexisation of step 3. Should never fail. Always performed in ComposeUsingPdfLatex mode
      NSData* latexData = [magicSourceToProducePDF dataUsingEncoding:NSUTF8StringEncoding];  
      failed |= ![latexData writeToFile:latexFilePath2 atomically:NO];
      if (!failed)
        pdfData = [self _composeLaTeX:latexFilePath2 stdoutLog:&stdoutLog stderrLog:&stderrLog options:ComposeUsingPdfLatex];
      failed |= !pdfData;
    }//end STEP 3
    
    //the baseline is affected by the bottom margin
    baseline += [MarginController bottomMargin];

    //Now that we are here, either step 2 passed, or step 3 passed. (But if step 2 failed, step 3 should not have failed)
    //pdfData should contain the cropped/magnified/coloured wanted image
    #ifndef PANTHER
    NSString* colorAsString = [color rgbaString];
    NSString* bkColorAsString = [imageView backgroundColor] ? [[imageView backgroundColor] rgbaString] : [[NSColor whiteColor] rgbaString];
    if (pdfData)
    {
      //in the meta-data of the PDF we store as much info as we can : preamble, body, size, color, mode, baseline...
      PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
      NSDictionary* attributes =
        [NSDictionary dictionaryWithObjectsAndKeys:
           [NSArray arrayWithObjects:
             preamble ? preamble : [NSString string],
             body ? body : [NSString string],
             colorAsString,
             [NSString stringWithFormat:@"%f", magnification],
             [NSString stringWithFormat:@"%d", mode],
             [NSString stringWithFormat:@"%f", baseline],
             bkColorAsString,
             nil], PDFDocumentKeywordsAttribute,
           [NSApp applicationName], PDFDocumentCreatorAttribute, nil];
      [pdfDocument setDocumentAttributes:attributes];
      pdfData = [pdfDocument dataRepresentation];
      [pdfDocument release];
    }
    #endif

    //adds some meta-data to be compatible with Latex Equation Editor
    if (pdfData)
      pdfData = [[AppController appController]
                  annotatePdfDataInLEEFormat:pdfData preamble:preamble source:body color:color
                                        mode:mode magnification:magnification baseline:baseline backgroundColor:[imageView backgroundColor]];

    [pdfData writeToFile:pdfFilePath atomically:NO];//Recreates the document with the new meta-data
  }//end if latex source could be compiled
  
  //returns the cropped/magnified/coloured image if possible; nil if it has failed. 
  return pdfData;
}

//returns an array of the errors. Each case will contain an error string
-(NSArray*) _filterLatexErrors:(NSString*)fullErrorLog
{
  NSArray* errorsNotFiltered = [fullErrorLog componentsSeparatedByString:@"\n"];
  NSMutableArray* filteredErrors = [NSMutableArray arrayWithCapacity:[errorsNotFiltered count]];
  NSEnumerator* enumerator = [errorsNotFiltered objectEnumerator];
  NSString* line = [enumerator nextObject];
  while(line)
  {
    NSArray* components = [line componentsSeparatedByString:@":"];
    if ((([components count] >= 3) && [[components objectAtIndex:1] intValue]) ||
        ([line rangeOfString:@"! LaTeX Error:"].location != NSNotFound))
    {
      NSMutableString* fullError = [NSMutableString stringWithString:line];
      while([line length] && ([line characterAtIndex:[line length]-1] != '.'))
      {
        line = [enumerator nextObject];
        [fullError appendString:line];
      }
      [filteredErrors addObject:fullError];
    }
    line = [enumerator nextObject];
  }
  return filteredErrors;
}

//This will update the error tableview, filling it with the filtered log obtained during the latexisation, and add error markers
//in the rulertextviews
-(void) _analyzeErrors:(NSArray*)errors
{
  [logTableView setErrors:errors];
  
  [preambleTextView clearErrors];
  [sourceTextView clearErrors];
  int numberOfRows = [logTableView numberOfRows];
  int i = 0;
  for(i = 0 ; i<numberOfRows ; ++i)
  {
    NSNumber* lineNumber = [logTableView tableView:logTableView
                            objectValueForTableColumn:[logTableView tableColumnWithIdentifier:@"line"] row:i];
    NSString* message = [logTableView tableView:logTableView
                      objectValueForTableColumn:[logTableView tableColumnWithIdentifier:@"message"] row:i];
    int line = [lineNumber intValue];
    int nbLinesInUserPreamble = [preambleTextView nbLines];
    if (line <= nbLinesInUserPreamble)
      [preambleTextView setErrorAtLine:line message:message];
    else
      [sourceTextView setErrorAtLine:line message:message];
  }
}

-(BOOL) hasImage
{
  return ([imageView image] != nil);
}

-(BOOL) isHistoryVisible
{
  int state = [historyDrawer state];
  return (state == NSDrawerOpenState) || (state == NSDrawerOpeningState);
}

//manages conflict when the historyDrawer and the libraryDrawer want to open on the same edge
-(void) setHistoryVisible:(BOOL)visible
{
  if (!visible)
    [historyDrawer close];
  else
  {
    [historyDrawer open];
    if ([self isLibraryVisible] && ([libraryDrawer edge] == [historyDrawer edge]))
      [libraryDrawer close];
  }
}

-(BOOL) isLibraryVisible
{
  int state = [libraryDrawer state];
  return (state == NSDrawerOpenState) || (state == NSDrawerOpeningState);
}

//manage conflict when the historyDrawer and the libraryDrawer want to open on the same edge
-(void) setLibraryVisible:(BOOL)visible
{
  if (!visible)
    [libraryDrawer close];
  else
  {
    [libraryDrawer open];
    if ([self isHistoryVisible] && ([libraryDrawer edge] == [historyDrawer edge]))
      [historyDrawer close];
  }
}

-(BOOL) isPreambleVisible
{
  //[[preambleTextView superview] superview] is a scrollview that is a subView of splitView
  return ([[[preambleTextView superview] superview] frame].size.height > 0);
}

-(void) setPreambleVisible:(BOOL)visible
{
  if (!(visible && [self isPreambleVisible])) //if preamble is already visible and visible is YES, do nothing
  {
    //[[preambleTextView superview] superview] and [[sourceTextView superview] superview] are scrollviews that are subViews of splitView
    NSView* preambleView = [[preambleTextView superview] superview];
    NSView* sourceView   = [[sourceTextView superview] superview];
    NSRect preambleFrame = [preambleView frame];
    NSRect sourceFrame = [sourceView frame];
    const float height = preambleFrame.size.height + sourceFrame.size.height;
    const float newPreambleHeight = visible ? height/2 : 0;
    const float newSourceHeight   = visible ? height/2 : height;
    int i = 0;
    for(i = 0 ; i<=10 ; ++i)
    {
      const float factor = i/10.0f;
      NSRect newPreambleFrame = preambleFrame;
      NSRect newSourceFrame = sourceFrame;
      newPreambleFrame.size.height = (1-factor)*newPreambleFrame.size.height + factor*newPreambleHeight;
      newSourceFrame.size.height   = (1-factor)*newSourceFrame.size.height   + factor*newSourceHeight;
      [preambleView setFrame:newPreambleFrame]; 
      [sourceView setFrame: newSourceFrame]; 
      [splitView adjustSubviews]; 
      [splitView displayIfNeeded];
      [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1/100.0f]];
    }
  }//end if there is something to change
}

-(void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
  //if the splitView has been collapsed, we should reconsider the menu bar to affect the show/hide preamble item
  [[AppController appController] menuNeedsUpdate:nil];
}

-(IBAction) clearHistory:(id)sender
{
  NSBeginAlertSheet(NSLocalizedString(@"Clear History",@"Clear History"),
                    NSLocalizedString(@"Clear History",@"Clear History"),
                    NSLocalizedString(@"Cancel", @"Cancel"),
                    nil, [self windowForSheet], self,
                    @selector(_clearHistorySheetDidEnd:returnCode:contextInfo:), nil, NULL,
                    NSLocalizedString(@"Are you sure you want to clear the whole history ?\nThis operation is irreversible.",
                                      @"Are you sure you want to clear the whole history ?\nThis operation is irreversible."));
}

-(void) _clearHistorySheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
  if (returnCode == NSAlertDefaultReturn)
    [[HistoryManager sharedManager] clearAll];
}

-(IBAction) removeHistoryEntries:(id)sender
{
  [historyView deleteBackward:sender];
}

//creates an historyItem summarizing the current document state
-(HistoryItem*) historyItemWithCurrentState;
{
  int selectedSegment = [typeOfTextControl selectedSegment];
  int tag = [[typeOfTextControl cell] tagForSegment:selectedSegment];
  latex_mode_t mode = (latex_mode_t) tag;
  return [HistoryItem historyItemWithPdfData:[imageView pdfData]  preamble:[preambleTextView textStorage]
                                  sourceText:[sourceTextView textStorage] color:[colorWell color]
                                   pointSize:[sizeText doubleValue] date:[NSDate date] mode:mode backgroundColor:[imageView backgroundColor]];
}

-(void) applyPdfData:(NSData*)pdfData
{
  BOOL needsToCheckLEEAnnotations = YES;
  #ifndef PANTHER
  PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
  NSString* creator  = pdfDocument ? [[pdfDocument documentAttributes] objectForKey:PDFDocumentCreatorAttribute]  : nil;
  NSArray*  keywords = pdfDocument ? [[pdfDocument documentAttributes] objectForKey:PDFDocumentKeywordsAttribute] : nil;
  //if the meta-data tells that the creator is LaTeXiT, then use it !
  needsToCheckLEEAnnotations = !(creator && [creator isEqual:[NSApp applicationName]] && keywords && ([keywords count] >= 7));
  if (!needsToCheckLEEAnnotations)
  {
    [self _setLogTableViewVisible:NO];
    [imageView setPdfData:pdfData cachedImage:nil];
    [self setPreamble:[[[NSAttributedString alloc] initWithString:[keywords objectAtIndex:0]] autorelease]];
    [self setSourceText:[[[NSAttributedString alloc] initWithString:[keywords objectAtIndex:1]] autorelease]];
    NSString* colorAsString = [keywords objectAtIndex:2];
    [colorWell setColor:[NSColor colorWithRgbaString:colorAsString]];
    [sizeText setDoubleValue:[[keywords objectAtIndex:3] doubleValue]];
    [typeOfTextControl selectSegmentWithTag:(latex_mode_t)[[keywords objectAtIndex:4] intValue]];
    //[keywords objectAtIndex:5] is the baseline
    NSString* bkColorAsString = [keywords objectAtIndex:6];
    [imageView setBackgroundColor:[NSColor colorWithRgbaString:bkColorAsString]];
  }
  [pdfDocument release];
  #endif

  if (needsToCheckLEEAnnotations) //either we are on panther, or we failed to find meta-data keywords
  {
    NSString* dataAsString = [[[NSString alloc] initWithData:pdfData encoding:NSASCIIStringEncoding] autorelease];
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray*  testArray    = nil;

    NSData* defaultPrambleData = [userDefaults objectForKey:DefaultPreambleAttributedKey];
    NSAttributedString* defaultPrambleAttributedString =
      [[[NSAttributedString alloc] initWithRTF:defaultPrambleData documentAttributes:NULL] autorelease];
    NSMutableString* preamble = [NSMutableString stringWithString:[defaultPrambleAttributedString string]];
    testArray = [dataAsString componentsSeparatedByString:@"/Preamble (ESannop"];
    if (testArray && ([testArray count] >= 2))
    {
      [preamble setString:[testArray objectAtIndex:1]];
      NSRange range = [preamble rangeOfString:@"ESannopend"];
      range.length = (range.location != NSNotFound) ? [preamble length]-range.location : 0;
      [preamble deleteCharactersInRange:range];
      [preamble replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, [preamble length])];
      [preamble replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, [preamble length])];
      [preamble replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, [preamble length])];
      [preamble replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, [preamble length])];
    }

    NSMutableString* source = [NSMutableString string];
    testArray = [dataAsString componentsSeparatedByString:@"/Subject (ESannot"];
    if (testArray && ([testArray count] >= 2))
    {
      [source appendString:[testArray objectAtIndex:1]];
      NSRange range = [source rangeOfString:@"ESannotend"];
      range.length = (range.location != NSNotFound) ? [source length]-range.location : 0;
      [source deleteCharactersInRange:range];
      [source replaceOccurrencesOfString:@"ESslash"      withString:@"\\" options:0 range:NSMakeRange(0, [source length])];
      [source replaceOccurrencesOfString:@"ESleftbrack"  withString:@"{"  options:0 range:NSMakeRange(0, [source length])];
      [source replaceOccurrencesOfString:@"ESrightbrack" withString:@"}"  options:0 range:NSMakeRange(0, [source length])];
      [source replaceOccurrencesOfString:@"ESdollar"     withString:@"$"  options:0 range:NSMakeRange(0, [source length])];
    }

    NSMutableString* pointSizeAsString = [NSMutableString stringWithString:[[userDefaults objectForKey:DefaultPointSizeKey] stringValue]];
    testArray = [dataAsString componentsSeparatedByString:@"/Magnification (EEmag"];
    if (testArray && ([testArray count] >= 2))
    {
      [pointSizeAsString setString:[testArray objectAtIndex:1]];
      NSRange range = [pointSizeAsString rangeOfString:@"EEmagend"];
      range.length  = (range.location != NSNotFound) ? [pointSizeAsString length]-range.location : 0;
      [pointSizeAsString deleteCharactersInRange:range];
    }

    NSMutableString* modeAsString = [NSMutableString stringWithString:[[userDefaults objectForKey:DefaultModeKey] stringValue]];
    testArray = [dataAsString componentsSeparatedByString:@"/Type (EEtype"];
    if (testArray && ([testArray count] >= 2))
    {
      [modeAsString setString:[testArray objectAtIndex:1]];
      NSRange range = [modeAsString rangeOfString:@"EEtypeend"];
      range.length = (range.location != NSNotFound) ? [modeAsString length]-range.location : 0;
      [modeAsString deleteCharactersInRange:range];
    }

    NSColor* defaultColor = [NSColor colorWithData:[userDefaults objectForKey:DefaultColorKey]];
    NSMutableString* colorAsString = [NSMutableString stringWithString:[defaultColor rgbaString]];
    testArray = [dataAsString componentsSeparatedByString:@"/Color (EEcol"];
    if (testArray && ([testArray count] >= 2))
    {
      [colorAsString setString:[testArray objectAtIndex:1]];
      NSRange range = [colorAsString rangeOfString:@"EEcolend"];
      range.length = (range.location != NSNotFound) ? [colorAsString length]-range.location : 0;
      [colorAsString deleteCharactersInRange:range];
    }

    NSMutableString* bkColorAsString = nil;
    testArray = [dataAsString componentsSeparatedByString:@"/BKColor (EEbkc"];
    if (testArray && ([testArray count] >= 2))
    {
      bkColorAsString = [NSMutableString stringWithString:[testArray objectAtIndex:1]];
      NSRange range = [bkColorAsString rangeOfString:@"EEbkcend"];
      range.length = (range.location != NSNotFound) ? [bkColorAsString length]-range.location : 0;
      [bkColorAsString deleteCharactersInRange:range];
    }

    [self _setLogTableViewVisible:NO];
    [imageView setPdfData:pdfData cachedImage:nil];
    [self setPreamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]];
    [self setSourceText:[[[NSAttributedString alloc] initWithString:source] autorelease]];
    [colorWell setColor:[NSColor colorWithRgbaString:colorAsString]];
    [sizeText setDoubleValue:[pointSizeAsString doubleValue]];
    [typeOfTextControl selectSegmentWithTag:(latex_mode_t)[modeAsString intValue]];
    [imageView setBackgroundColor:[NSColor colorWithRgbaString:bkColorAsString]];
  }
}

//sets the state of the document according to the given history item
-(void) applyHistoryItem:(HistoryItem*)historyItem
{
  if (historyItem)
  {
    [self _setLogTableViewVisible:NO];
    [imageView setPdfData:[historyItem pdfData] cachedImage:[historyItem pdfImage]];
    [self setPreamble:[historyItem preamble]];
    [self setSourceText:[historyItem sourceText]];
    [colorWell setColor:[historyItem color]];
    [sizeText setDoubleValue:[historyItem pointSize]];
    [typeOfTextControl selectSegmentWithTag:[historyItem mode]];
    [imageView setBackgroundColor:[historyItem backgroundColor]];
  }
}

//if a selection is made either in the history or in the library, updates the document state
-(void) _selectionDidChange:(NSNotification*)aNotification
{
  NSTableView* sender = [aNotification object];
  if (sender == historyView)
  {
    [self _historySelectionDidChange];
  }
  else if (sender == libraryView)
  {
    [self _librarySelectionDidChange];
  }
}

//if a selection is made in the history, updates the document state
-(void) _historySelectionDidChange
{
  int selectedRow = [historyView selectedRow];
  HistoryItem* historyItem = [[HistoryManager sharedManager] itemAtIndex:selectedRow tableView:historyView];
  [self applyHistoryItem:historyItem];
}

//if a selection is made in the library, updates the document state
-(void) _librarySelectionDidChange
{
  LibraryItem* libraryItem = [libraryView itemAtRow:[libraryView selectedRow]];
  if ([libraryItem isKindOfClass:[LibraryFile class]])
    [self applyHistoryItem:[(LibraryFile*) libraryItem value]];
}

//updates the clear History button when history is available/unavailable
-(void) _historyDidChange:(NSNotification*)aNotification
{
  [clearHistoryButton setEnabled:([[[HistoryManager sharedManager] historyItems] count] > 0)];
}

-(NSArray*) selectedLibraryItems
{
  return [self isLibraryVisible] ? [libraryView selectedItems] : [NSArray array];
}

-(NSArray*) selectedHistoryItems
{
  return [self isHistoryVisible] ? [historyView selectedItems] : [NSArray array];
}

//action coming from menu through appcontroller
-(IBAction) addCurrentEquationToLibrary:(id)sender
{
  [libraryDrawer importCurrent:sender];
}

//action coming from menu through appcontroller
-(IBAction) newLibraryFolder:(id)sender
{
  [libraryDrawer newFolder:sender];
}

//action coming from menu through appcontroller
-(IBAction) removeLibraryItems:(id)sender
{
  [libraryDrawer removeItem:sender];
}

//action coming from menu through appcontroller
-(IBAction) refreshLibraryItems:(id)sender
{
  [libraryDrawer refreshItem:sender];
}

-(void) deselectItems
{
  [historyView deselectAll:self];
  [libraryView deselectAll:self];
}

//calls the log window
-(IBAction) displayLastLog:(id)sender
{
  [logWindow makeKeyAndOrderFront:self];
}

//when a drawer has been drawn to 0, it is not automatically marked as closed, so I make it by hand
-(NSSize) drawerWillResizeContents:(NSDrawer *)sender toSize:(NSSize)contentSize
{
  if (sender == historyDrawer)
  {
    NSRect rect = [clearHistoryButton frame];
    rect.origin.x = (contentSize.width-rect.size.width)/2;
    [clearHistoryButton setFrame:rect];
    if (!contentSize.width || !contentSize.height)
    {
      [self setHistoryVisible:NO];
      [[AppController appController] menuNeedsUpdate:nil];
    }
  }
  else if (sender == libraryDrawer)
  {
    if (!contentSize.width || !contentSize.height)
    {
      [self setLibraryVisible:NO];
      [[AppController appController] menuNeedsUpdate:nil];
    }
  }
  return contentSize;
}

//overloaded to avoid document saving
-(void) updateChangeCount:(NSDocumentChangeType)changeType
{
}

//image exporting
-(IBAction) openOptions:(id)sender
{
  [jpegQualitySlider setFloatValue:jpegQuality];
  [jpegQualityTextField setFloatValue:[jpegQualitySlider floatValue]];
  [jpegColorWell setColor:jpegColor];
  [NSApp runModalForWindow:saveAccessoryViewOptionsPane];
}

//close option pane of the image export
-(IBAction) closeOptionsPane:(id)sender
{
  if ([sender tag] == 0) //OK
  {
    jpegQuality = [jpegQualitySlider floatValue];
    jpegColor   = [jpegColorWell     color];
  }
  [NSApp stopModal];
  [saveAccessoryViewOptionsPane orderOut:self];
}

-(IBAction) jpegQualitySliderDidChange:(id)sender
{
  [jpegQualityTextField setFloatValue:[sender floatValue]];
}

//the accessory view holds the "option" button of image export
-(IBAction) saveAccessoryViewPopupFormatDidChange:(id)sender
{
  BOOL allowOptions = NO;
  NSString* format = [[sender titleOfSelectedItem] lowercaseString];
  NSArray* components = [format componentsSeparatedByString:@" "];
  format = [components count] ? [components objectAtIndex:0] : @"";
  if ([format isEqualToString:@"jpeg"])
  {
    allowOptions = YES;
    [currentSavePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"jpg", @"jpeg", nil]];
    [saveAccessoryViewJpegWarning setHidden:NO];
  }
  else
  {
    [saveAccessoryViewJpegWarning setHidden:YES];
    [currentSavePanel setRequiredFileType:format];
    allowOptions = NO;
  }
  
  [saveAccessoryViewOptionsButton setEnabled:allowOptions];
}

//asks for a filename and format to export
-(IBAction) exportImage:(id)sender
{
  currentSavePanel = [NSSavePanel savePanel];
  [self saveAccessoryViewPopupFormatDidChange:saveAccessoryViewPopupFormat];
  [currentSavePanel setCanSelectHiddenExtension:YES];
  [currentSavePanel setCanCreateDirectories:YES];
  [currentSavePanel setAccessoryView:saveAccessoryView];
  [currentSavePanel setExtensionHidden:NO];
  [currentSavePanel beginSheetForDirectory:nil file:NSLocalizedString(@"Untitled", @"Untitled")
                            modalForWindow:[self windowForSheet] modalDelegate:self
                            didEndSelector:@selector(exportChooseFileDidEnd:returnCode:contextInfo:)
                               contextInfo:NULL];
}

-(void) exportChooseFileDidEnd:(NSSavePanel*)sheet returnCode:(int)code contextInfo:(void*)contextInfo
{  
  if ((code == NSOKButton) && [imageView image])
  {
    NSData*  pdfData = [imageView pdfData];
    NSString* format = [[saveAccessoryViewPopupFormat titleOfSelectedItem] lowercaseString];
    NSData*   data   = [[AppController appController] dataForType:format pdfData:pdfData jpegColor:[jpegColorWell color] jpegQuality:jpegQuality/100];
    if (data)
    {
      NSString* filePath = [sheet filename];
      [data writeToFile:filePath atomically:YES];

      [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt']
                                                    forKey:NSFileHFSCreatorCode] atPath:filePath];    
      unsigned int options = 0;
      #ifndef PANTHER
      options = NSExclude10_4ElementsIconCreationOption;
      #endif
      NSColor* backgroundColor = [format isEqualTo:@"jpeg"] ? [jpegColorWell color] : nil;
      [[NSWorkspace sharedWorkspace] setIcon:[[AppController appController] makeIconForData:pdfData backgroundColor:backgroundColor]
                                     forFile:filePath options:options];
    }
  }//end if save
  currentSavePanel = nil;
}

-(NSString*) selectedText
{
  NSString* text = [NSString string];
  NSResponder* firstResponder = [[self windowForSheet] firstResponder];
  if ((firstResponder == sourceTextView) || (firstResponder == preambleTextView))
  {
    NSTextView* textView = (NSTextView*) firstResponder;
    text = [[textView string] substringWithRange:[textView selectedRange]];
  }
  return text;
}

-(void) insertText:(NSString*)text
{
  NSResponder* firstResponder = [[self windowForSheet] firstResponder];
  if ((firstResponder == sourceTextView) || (firstResponder == preambleTextView))
    [firstResponder insertText:text];
}

-(BOOL) isBusy
{
  return isBusy;
}

//teleportation to the faulty lines of the latex code when the user clicks a line in the error tableview
-(void) _clickErrorLine:(NSNotification*)aNotification
{
  NSTableView* tableView = (NSTableView*) [aNotification object];
  if (tableView == logTableView)
  {
    NSNumber* number = (NSNumber*) [[aNotification userInfo] objectForKey:@"lineError"];
    if (!number)
      [self displayLastLog:self];
    else
    {
      int row = [number intValue];
      if ([preambleTextView gotoLine:row])
        [self setPreambleVisible:YES];
      else
        [sourceTextView gotoLine:row];
    }
  }
}

//hides/display the error log table view
-(void) _setLogTableViewVisible:(BOOL)status
{
  NSScrollView* scrollView = (NSScrollView*) [[logTableView superview] superview];
  [scrollView setHidden:!status];
  [scrollView setNeedsDisplay:YES];
}

//returns the linkBack link
-(LinkBack*) linkBackLink
{
  return linkBackLink;
}

//sets up a new linkBack link
-(void) setLinkBackLink:(LinkBack*)newLinkBackLink
{
  [self closeLinkBackLink:linkBackLink];
  linkBackLink = newLinkBackLink;
}

//if current linkBack link is aLink, then close it. Also close if aLink = nil
-(void) closeLinkBackLink:(LinkBack*)aLink
{
  if (!aLink || (linkBackLink == aLink))
  {
    [linkBackLink closeLink];
    linkBackLink = nil;
    [self setDocumentTitle:nil];
  }
}

@end
