//  MyDocument.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright Pierre Chatelier 2005, 2006, 2007 . All rights reserved.

// The main document of LaTeXiT. There is much to say !

#import "MyDocument.h"

#import "AppController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LibraryFile.h"
#import "LineCountTextView.h"
#import "LogTableView.h"
#import "MyImageView.h"
#import "NSApplicationExtended.h"
#import "NSColorExtended.h"
#import "NSFontExtended.h"
#import "NSPopUpButtonExtended.h"
#import "NSSegmentedControlExtended.h"
#import "NSStringExtended.h"
#import "NSTaskExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "SMLSyntaxColouring.h"
#import "SystemTask.h"

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

@interface MyDocument (PrivateAPI)

+(unsigned long) _giveId; //returns a free id and marks it as used
+(void) _releaseId:(unsigned long)anId; //releases an id

//compose latex and returns pdf data. the options may specify to use pdflatex or latex+dvipdf
-(NSData*) _composeLaTeX:(NSString*)filePath customLog:(NSString**)customLog stdoutLog:(NSString**)stdoutLog stderrLog:(NSString**)stderrLog
                                       compositionMode:(composition_mode_t)compositionMode;

//returns an array of the errors. Each case will contain an error string
-(NSArray*) _filterLatexErrors:(NSString*)fullErrorLog shiftLinesBy:(int)errorLineShift;

//updates the logTableView to report the errors
-(void) _analyzeErrors:(NSArray*)errors;

//computes the tight bounding box of a pdfFile
-(NSRect) _computeBoundingBox:(NSString*)pdfFilePath;

-(void) _lineCountDidChange:(NSNotification*)aNotification;
-(void) _clickErrorLine:(NSNotification*)aNotification;

-(void) _setLogTableViewVisible:(BOOL)status;

-(NSString*) _replaceYenSymbol:(NSString*)string; //in Japanese environment, we should replace the Yen symbol by a backslash

-(NSImage*) _checkEasterEgg;//may return an easter egg image

-(void) _updateTextField:(NSTimer*)timer; //to fix a refresh bug
-(void) closeSheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;//for doc closing

-(NSString*) descriptionForScript:(NSDictionary*)script;
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
+(void) _releaseId:(unsigned long)anId
{
  @synchronized(freeIds)
  {
    [freeIds addObject:[NSNumber numberWithUnsignedLong:anId]];
  }
}
//end _releaseId:

-(id) init
{
  if (![super init])
    return nil;
  uniqueId = [MyDocument _giveId];
  jpegQuality = 90;
  jpegColor = [[NSColor whiteColor] retain];
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [MyDocument _releaseId:uniqueId];
  [saveAccessoryView release];
  [jpegColor release];
  [self closeLinkBackLink:linkBackLink];
  [progressIndicator release];
  [lastAppliedLibraryFile release];
  [super dealloc];
}
//end dealloc

-(void) setNullId//useful for dummy document of AppController
{
  [MyDocument _releaseId:uniqueId];
  uniqueId = 0;
}
//end setNullId

-(NSString*) windowNibName
{
    //Override returning the nib file name of the document
    //If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers,
    //you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}
//end windowNibName

-(void) windowControllerDidLoadNib:(NSWindowController *) aController
{
  [super windowControllerDidLoadNib:aController];
  
  [[self windowForSheet] setFrameAutosaveName:[NSString stringWithFormat:@"LaTeXiT-window-%u", uniqueId]];

  //to paste rich LaTeXiT data, we must tune the responder chain  
  [sourceTextView setNextResponder:imageView];

  //useful to avoid conflicts between mouse clicks on imageView and the progressIndicator
  [progressIndicator setNextResponder:imageView];
  [progressIndicator retain];
  [progressIndicator removeFromSuperview];
  
  [saveAccessoryView retain]; //to avoid unwanted deallocation when save panel is closed

  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];  
  [saveAccessoryViewScaleAsPercentTextField setFloatValue:[userDefaults floatForKey:DragExportScaleAsPercentKey]];

  [[typeOfTextControl cell] setTag:LATEX_MODE_EQNARRAY forSegment:0];
  [[typeOfTextControl cell] setTag:LATEX_MODE_DISPLAY forSegment:1];
  [[typeOfTextControl cell] setTag:LATEX_MODE_INLINE  forSegment:2];
  [[typeOfTextControl cell] setTag:LATEX_MODE_TEXT  forSegment:3];
  [typeOfTextControl selectSegmentWithTag:[userDefaults integerForKey:DefaultModeKey]];
  
  [sizeText setDoubleValue:[userDefaults floatForKey:DefaultPointSizeKey]];

  NSColor* initialColor = [[AppController appController] isColorStyAvailable] ?
                              [NSColor colorWithData:[userDefaults dataForKey:DefaultColorKey]] : [NSColor blackColor];
  [colorWell setColor:initialColor];

  NSFont* defaultFont = [NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]];
  [preambleTextView setTypingAttributes:[NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName]];
  [sourceTextView   setTypingAttributes:[NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName]];
  
  [imageView setBackgroundColor:[NSColor colorWithData:[[NSUserDefaults standardUserDefaults] objectForKey:DefaultImageViewBackgroundKey]]
              updateHistoryItem:NO];
              
  //connect contextual copy As menu to imageView
  NSMenuItem* menuItem = [copyAsContextualMenuItem itemAtIndex:0];
  NSArray* items = [[menuItem submenu] itemArray];
  unsigned int count = items ? [items count] : 0;
  while(count--)
  {
    NSMenuItem* item = [items objectAtIndex:count];
    [item setTarget:imageView];
    [item setAction:@selector(copy:)];
  }

  //the initial... variables has been set into a readFromFile
  if (initialPreamble)
  {
    //try to insert usepackage{color} inside the preamble
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
    [typeOfTextControl setSelectedSegment:[[typeOfTextControl cell] tagForSegment:LATEX_MODE_TEXT]];
    [self setSourceText:[[[NSAttributedString alloc] initWithString:initialBody] autorelease]];
    initialBody = nil;
  }
  
  if (initialPdfData)
  {
    [self applyPdfData:initialPdfData];
    initialPdfData = nil;
  }

  [self updateAvailabilities:nil]; //updates interface to allow latexisation or not, according to current configuration

  [self _lineCountDidChange:nil];//to "shift" the line counter of sourceTextView
  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(_lineCountDidChange:)
                             name:LineCountDidChangeNotification object:preambleTextView];
  [notificationCenter addObserver:self selector:@selector(_clickErrorLine:)
                             name:ClickErrorLineNotification object:logTableView];
  [notificationCenter addObserver:self selector:@selector(updateAvailabilities:)
                             name:SomePathDidChangeNotification object:nil];
  [notificationCenter addObserver:self selector:@selector(updateAvailabilities:)
                             name:CompositionModeDidChangeNotification object:nil];
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

-(MyImageView*) imageView
{
  return imageView;
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

-(void) startMessageProgress:(NSString*)message
{
  [progressMessageProgressIndicator setHidden:NO];
  [progressMessageProgressIndicator startAnimation:self];
  [progressMessageProgressIndicator setNeedsDisplay:YES];
  [progressMessageTextField setStringValue:message];
  [progressMessageTextField setNeedsDisplay:YES];
  [[progressMessageProgressIndicator superview] display];
}

-(void) stopMessageProgress
{
  [progressMessageTextField setStringValue:@""];
  [progressMessageTextField setNeedsDisplay:YES];
  [progressMessageProgressIndicator stopAnimation:self];
  [progressMessageProgressIndicator setHidden:YES];
  [progressMessageProgressIndicator setNeedsDisplay:YES];
  [[progressMessageProgressIndicator superview] display];
}

//updates interface to allow latexisation or not, according to current configuration
//may be triggered by a notification
-(void) updateAvailabilities:(NSNotification*)notification
{
  AppController* appController = [AppController appController];
  composition_mode_t compositionMode =
    (composition_mode_t) [[PreferencesController currentCompositionConfigurationObjectForKey:
                            CompositionConfigurationCompositionModeKey] intValue];
  BOOL makeLatexButtonEnabled =
    (compositionMode == COMPOSITION_MODE_PDFLATEX) ? [appController isPdfLatexAvailable] && [appController isGsAvailable] :
    (compositionMode == COMPOSITION_MODE_XELATEX)  ? [appController isPdfLatexAvailable] && [appController isXeLatexAvailable] && [appController isGsAvailable] :
    (compositionMode == COMPOSITION_MODE_LATEXDVIPDF) ? [appController isLatexAvailable] && [appController isDvipdfAvailable] && [appController isGsAvailable] :
    NO;    
  [makeLatexButton setEnabled:makeLatexButtonEnabled];
  [makeLatexButton setNeedsDisplay:YES];
  if (makeLatexButtonEnabled)
    [makeLatexButton setToolTip:nil];
  else if (![makeLatexButton toolTip])
    [makeLatexButton setToolTip:
      NSLocalizedString(@"pdflatex, latex, dvipdf, xelatex or gs (depending to the current configuration) seems unavailable in your system. Please check their installation.",
                        @"pdflatex, latex, dvipdf, xelatex or gs (depending to the current configuration) seems unavailable in your system. Please check their installation.")];
  
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
  BOOL ok = YES;
  //You can also choose to override -loadFileWrapperRepresentation:ofType: or -readFromFile:ofType: instead.
  NSLog(@"readFromFile");
  if ([aType isEqualToString:@"LatexPalette"])
  {
     NSLog(@"LatexPalette");
    [[AppController appController] installLatexPalette:file];
    ok = YES;
  }
  else
  {
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
  }
  return ok;
}
//end readFromFile:ofType

//in Japanese environment, we should replace the Yen symbol by a backslash
//You can read http://www.xs4all.nl/~msneep/articles/japanese.html to know more about that problem
-(NSString*) _replaceYenSymbol:(NSString*)stringWithYen; 
{
  NSMutableString* stringWithBackslash = [NSMutableString stringWithString:stringWithYen];
  [stringWithBackslash replaceOccurrencesOfString:yenString withString:@"\\"
                                          options:NSLiteralSearch range:NSMakeRange(0, [stringWithBackslash length])];
  return stringWithBackslash;
}

//when the linecount changes in the preamble view, the numerotation must change in the body view
-(void) _lineCountDidChange:(NSNotification*)aNotification
{
  //registered only for preambleTextView
  [sourceTextView setLineShift:[[preambleTextView lineRanges] count]];
}

-(void) setFont:(NSFont*)font//changes the font of both preamble and sourceText views
{
  [[preambleTextView textStorage] setFont:font];
  [[sourceTextView textStorage] setFont:font];
}

-(void) resetSyntaxColoring
{
  [[preambleTextView syntaxColouring] setColours];
  [[preambleTextView syntaxColouring] recolourCompleteDocument];
  [preambleTextView setNeedsDisplay:YES];
  [[sourceTextView syntaxColouring] setColours];
  [[sourceTextView syntaxColouring] recolourCompleteDocument];
  [sourceTextView setNeedsDisplay:YES];
}

-(void) setPreamble:(NSAttributedString*)aString
{
  [preambleTextView clearErrors];
  [[preambleTextView textStorage] setAttributedString:aString];
  [[preambleTextView syntaxColouring] recolourCompleteDocument];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:preambleTextView];
  [preambleTextView setNeedsDisplay:YES];
}

-(void) setSourceText:(NSAttributedString*)aString
{
  [sourceTextView clearErrors];
  [[sourceTextView textStorage] setAttributedString:aString];
  [[sourceTextView syntaxColouring] recolourCompleteDocument];
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
                      defaultButton:NSLocalizedString(@"Process anyway", @"Process anyway")
                    alternateButton:NSLocalizedString(@"Cancel", @"Cancel")
                        otherButton:nil
          informativeTextWithFormat:NSLocalizedString(@"You did not type any text in the body. The result will certainly be empty.",
                                                      @"You did not type any text in the body. The result will certainly be empty.")];
     int result = [alert runModal];
     mustProcess = (result == NSAlertDefaultReturn);
  }
  
  if (mustProcess)
  {
    [imageView setPDFData:nil cachedImage:nil];       //clears current image
    if ([[NSUserDefaults standardUserDefaults] boolForKey:DefaultAutomaticHighContrastedPreviewBackgroundKey])
      [imageView setBackgroundColor:nil updateHistoryItem:NO];
    [imageView setNeedsDisplay:YES];
    [imageView displayIfNeeded];      //refresh it
    NSRect imageViewFrame = [imageView frame];
    NSSize progressIndicatorSize = [progressIndicator frame].size;
    [progressIndicator setFrameOrigin:NSMakePoint((imageViewFrame.size.width-progressIndicatorSize.width)/2,
                                                  (imageViewFrame.size.height-progressIndicatorSize.height)/2)];
    [imageView addSubview:progressIndicator];
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
    if (failed)
    {
      if (![logTableView numberOfRows] ) //unexpected error...
        [logTableView setErrors:
          [NSArray arrayWithObject:
            [NSString stringWithFormat:@"::%@",
              NSLocalizedString(@"unexpected error, please see \"LaTeX > Display last log\"",
                                @"unexpected error, please see \"LaTeX > Display last log\"")]]];
    }
    else
    {
      //if it is ok, updates the image view
      [imageView setPDFData:pdfData cachedImage:[self _checkEasterEgg]];

      //and insert a new element into the history
      HistoryItem* newHistoryItem = [self historyItemWithCurrentState];
      [imageView setBackgroundColor:[newHistoryItem backgroundColor] updateHistoryItem:NO];
      [[HistoryManager sharedManager] addItem:newHistoryItem];
      [[[AppController appController] historyController] deselectAll:0];
      
      //updates the pasteboard content for a live Linkback link, and triggers a sendEdit
      [imageView updateLinkBackLink:linkBackLink];
    }
    
    //hides progress indicator
    [progressIndicator stopAnimation:self];
    [progressIndicator setHidden:YES];
    [progressIndicator removeFromSuperview];
    
    //hides/how the error view
    [self _setLogTableViewVisible:[logTableView numberOfRows]];
    
    //not busy any more
    isBusy = NO;
  }//end if mustProcess
}  

//computes the tight bounding box of a pdfFile
-(NSRect) _computeBoundingBox:(NSString*)pdfFilePath
{
  NSRect boundingBoxRect = NSZeroRect;
  
  //We will rely on GhostScript (gs) to compute the bounding box
  NSFileManager* fileManager = [NSFileManager defaultManager];
  if ([fileManager fileExistsAtPath:pdfFilePath])
  {
    NSString* directory      = [AppController latexitTemporaryPath];

    NSTask* boundingBoxTask  = [[NSTask alloc] init];
    NSPipe* gs2awkPipe       = [NSPipe pipe];
    NSPipe* outPipe          = [NSPipe pipe];
    NSFileHandle* nullDevice = [NSFileHandle fileHandleWithNullDevice];
    [boundingBoxTask setCurrentDirectoryPath:directory];
    [boundingBoxTask setEnvironment:[AppController environmentDict]];
    [boundingBoxTask setLaunchPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey]];
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
    NSRect tmpRect = NSZeroRect;
    [scanner scanFloat:&tmpRect.origin.x];
    [scanner scanFloat:&tmpRect.origin.y];
    [scanner scanFloat:&tmpRect.size.width];//in fact, we read the right corner, not the width
    [scanner scanFloat:&tmpRect.size.height];//idem for height
    tmpRect.size.width  -= tmpRect.origin.x;//so we correct here
    tmpRect.size.height -= tmpRect.origin.y;
    
    boundingBoxRect = tmpRect; //I have used a tmpRect because gcc version 4.0.0 (Apple Computer, Inc. build 5026) issues a strange warning
    //it considers <boundingBoxRect> to be const when the try/catch/finally above is here. If you just comment try/catch/finally, the
    //warning would disappear
  }
  return boundingBoxRect;
}

//compose latex and returns pdf data. the options may specify to use pdflatex or latex+dvipdf
-(NSData*) _composeLaTeX:(NSString*)filePath customLog:(NSString**)customLog
                                           stdoutLog:(NSString**)stdoutLog stderrLog:(NSString**)stderrLog
                                       compositionMode:(composition_mode_t)compositionMode
{
  NSData* pdfData = nil;
  
  NSString* directory = [filePath stringByDeletingLastPathComponent];
  NSString* texFile   = filePath;
  NSString* dviFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"dvi"];
  NSString* pdfFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"pdf"];
  NSString* errFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"err"];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  [fileManager removeFileAtPath:dviFile handler:nil];
  [fileManager removeFileAtPath:pdfFile handler:nil];
  
  NSMutableString* customString = [NSMutableString string];
  NSMutableString* stdoutString = [NSMutableString string];
  NSMutableString* stderrString = [NSMutableString string];

  NSStringEncoding encoding = NSUTF8StringEncoding;
  NSError* error = nil;
  NSString* source = [NSString stringWithContentsOfFile:texFile guessEncoding:&encoding error:&error];
  [customString appendString:[NSString stringWithFormat:@"Source :\n%@\n", source ? source : @""]];

  //it happens that the NSTask fails for some strange reason (fflush problem...), so I will use a simple and ugly system() call
  NSString* executablePath =
     (compositionMode == COMPOSITION_MODE_XELATEX)
       ? [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationXeLatexPathKey]
       : (compositionMode == COMPOSITION_MODE_PDFLATEX)
         ? [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPdfLatexPathKey]
         : [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationLatexPathKey];
  NSString* systemCall = [NSString stringWithFormat:@"cd %@ && %@ -file-line-error -interaction nonstopmode %@ 1> %@ 2>%@", 
                          directory, executablePath, texFile, errFile, errFile];
  [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n%@\n",
                                                        NSLocalizedString(@"processing", @"processing"),
                                                        [executablePath lastPathComponent],
                                                        systemCall]];
  BOOL failed = (system([systemCall UTF8String]) != 0) && ![fileManager fileExistsAtPath:pdfFile];
  encoding = NSUTF8StringEncoding;
  error = nil;
  NSString* errors = [NSString stringWithContentsOfFile:errFile guessEncoding:&encoding error:&error];
  [customString appendString:errors ? errors : @""];
  [stdoutString appendString:errors ? errors : @""];
  
  if (failed)
    [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n",
                               NSLocalizedString(@"error while processing", @"error while processing"),
                               [executablePath lastPathComponent]]];

  //if !failed and must call dvipdf...
  if (!failed && (compositionMode == COMPOSITION_MODE_LATEXDVIPDF))
  {
    NSTask* dvipdfTask = [[NSTask alloc] init];
    [dvipdfTask setCurrentDirectoryPath:directory];
    [dvipdfTask setEnvironment:[AppController environmentDict]];
    [dvipdfTask setLaunchPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationDvipdfPathKey]];
    [dvipdfTask setArguments:[NSArray arrayWithObject:dviFile]];
    NSPipe* stdoutPipe2 = [NSPipe pipe];
    NSPipe* stderrPipe2 = [NSPipe pipe];
    [dvipdfTask setStandardOutput:stdoutPipe2];
    [dvipdfTask setStandardError:stderrPipe2];

    @try
    {
      [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n%@\n",
                                                            NSLocalizedString(@"processing", @"processing"),
                                                            [[dvipdfTask launchPath] lastPathComponent],
                                                            [dvipdfTask commandLine]]];
      [dvipdfTask launch];
      [dvipdfTask waitUntilExit];
      NSData* stdoutData = [[stdoutPipe2 fileHandleForReading] availableData];
      NSData* stderrData = [[stderrPipe2 fileHandleForReading] availableData];
      NSString* tmp = nil;
      tmp = stdoutData ? [[[NSString alloc] initWithData:stdoutData encoding:NSUTF8StringEncoding] autorelease] : nil;
      if (tmp)
      {
        [customString appendString:tmp];
        [stdoutString appendString:tmp];
      }
      tmp = stderrData ? [[[NSString alloc] initWithData:stderrData encoding:NSUTF8StringEncoding] autorelease] : nil;
      if (tmp)
      {
        [customString appendString:tmp];
        [stderrString appendString:tmp];
      }
      failed = ([dvipdfTask terminationStatus] != 0);
    }
    @catch(NSException* e)
    {
      failed = YES;
      [customString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", [e name], [e reason]]];
    }
    @finally
    {
      [dvipdfTask release];
    }
    
    if (failed)
      [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n",
                                 NSLocalizedString(@"error while processing", @"error while processing"),
                                 [[dvipdfTask launchPath] lastPathComponent]]];

  }//end of dvipdf call
  
  if (customLog)
    *customLog = customString;
  if (stdoutLog)
    *stdoutLog = stdoutString;
  if (stderrLog)
    *stderrLog = stderrString;
  
  if (!failed && [[NSFileManager defaultManager] fileExistsAtPath:pdfFile])
    pdfData = [NSData dataWithContentsOfFile:pdfFile];

  return pdfData;
}

-(void) setLatexMode:(latex_mode_t)mode
{
  [typeOfTextControl selectSegmentWithTag:mode];
}

-(void) setColor:(NSColor*)color
{
  [colorWell setColor:color];
}

-(void) setMagnification:(float)magnification
{
  [sizeText setFloatValue:magnification];
}

//latexise and returns the pdf result, cropped, magnified, coloured, with pdf meta-data
-(NSData*) latexiseWithPreamble:(NSString*)preamble body:(NSString*)body color:(NSColor*)color mode:(latex_mode_t)latexMode 
                  magnification:(double)magnification
{
  NSData* pdfData = nil;

  preamble = [preamble filteredStringForLatex];
  body     = [body filteredStringForLatex];

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
  composition_mode_t compositionMode =
    (composition_mode_t) [[PreferencesController currentCompositionConfigurationObjectForKey:
                            CompositionConfigurationCompositionModeKey] intValue];

  //prepare file names
  NSString* directory      = [AppController latexitTemporaryPath];
  NSString* filePrefix     = [NSString stringWithFormat:@"latexit-%u", uniqueId]; //file name, related to the current document

  //latex files for step 1 (simple latex file useful to report errors, log file and pdf result)
  NSString* latexFile             = [NSString stringWithFormat:@"%@.tex", filePrefix];
  NSString* latexFilePath         = [directory stringByAppendingPathComponent:latexFile];
  NSString* latexAuxFile          = [NSString stringWithFormat:@"%@.aux", filePrefix];
  NSString* latexAuxFilePath      = [directory stringByAppendingPathComponent:latexAuxFile];
  NSString* pdfFile               = [NSString stringWithFormat:@"%@.pdf", filePrefix];
  NSString* pdfFilePath           = [directory stringByAppendingPathComponent:pdfFile];
  NSString* dviFile               = [NSString stringWithFormat:@"%@.dvi", filePrefix];
  NSString* dviFilePath           = [directory stringByAppendingPathComponent:dviFile];
  
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
  [fileManager removeFileAtPath:dviFilePath              handler:nil];
  [fileManager removeFileAtPath:pdfFilePath2             handler:nil];
  [fileManager removeFileAtPath:latexBaselineFilePath    handler:nil];
  [fileManager removeFileAtPath:latexAuxBaselineFilePath handler:nil];
  [fileManager removeFileAtPath:pdfBaselineFilePath      handler:nil];
  [fileManager removeFileAtPath:sizesFilePath            handler:nil];
  //trash *.*pk, *.mf, *.tfm, *.mp, *.script
  NSArray* files = [fileManager directoryContentsAtPath:directory];
  NSEnumerator* enumerator = [files objectEnumerator];
  NSString* file = nil;
  while((file = [enumerator nextObject]))
  {
    file = [directory stringByAppendingPathComponent:file];
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:file isDirectory:&isDirectory] && !isDirectory)
    {
      NSString* extension = [[file pathExtension] lowercaseString];
      BOOL mustDelete = [extension isEqualToString:@"mf"] ||  [extension isEqualToString:@"mp"] ||
                        [extension isEqualToString:@"tfm"] || [extension endsWith:@"pk" options:NSCaseInsensitiveSearch] ||
                        [extension isEqualToString:@"script"];
      if (mustDelete)
        [fileManager removeFileAtPath:file handler:NULL];
    }
  }

  //some tuning due to parameters; note that \[...\] is replaced by $\displaystyle because of
  //incompatibilities with the magical boxes
  NSString* addSymbolLeft  = (latexMode == LATEX_MODE_EQNARRAY) ? @"\\begin{eqnarray*}" :
                             (latexMode == LATEX_MODE_DISPLAY) ? @"$\\displaystyle " :
                             (latexMode == LATEX_MODE_INLINE) ? @"$" : @"";
  NSString* addSymbolRight = (latexMode == LATEX_MODE_EQNARRAY) ? @"\\end{eqnarray*}" :
                             (latexMode == LATEX_MODE_DISPLAY) ? @"$" :
                             (latexMode == LATEX_MODE_INLINE) ? @"$" : @"";
  NSString* colouredPreamble = [[AppController appController] insertColorInPreamble:preamble color:color];
  
  NSMutableString* fullLog = [NSMutableString string];
  
  
  //STEP 1
  //first, creates simple latex source text to compile and report errors (if there are any)
  
  //the body is trimmed to avoid some latex problems (sometimes, a newline at the end of the equation makes it fail!)
  NSString* trimmedBody = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  //the problem is that now, the error lines must be shifted ! How many new lines have been removed ?
  NSString* firstChar = [trimmedBody length] ? [trimmedBody substringWithRange:NSMakeRange(0, 1)] : @"";
  NSRange firstCharLocation = [body rangeOfString:firstChar];
  NSRange rangeOfTrimmedHeader = NSMakeRange(0, (firstCharLocation.location != NSNotFound) ? firstCharLocation.location : 0);
  NSString* trimmedHeader = [body substringWithRange:rangeOfTrimmedHeader];
  unsigned int nbNewLinesInTrimmedHeader = MAX(1U, [[trimmedHeader componentsSeparatedByString:@"\n"] count]);
  int errorLineShift = MAX((int)0, (int)nbNewLinesInTrimmedHeader-1);
  
  //xelatex requires to insert the color in the body, so we compute the color as string...
  color = [(color ? color : [NSColor blackColor]) colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  float rgba[4] = {0, 0, 0, 0};
  [color getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
  NSString* colorString = [NSString stringWithFormat:@"\\color[rgb]{%1.3f,%1.3f,%1.3f}", rgba[0], rgba[1], rgba[2]];
  NSString* normalSourceToCompile =
    [NSString stringWithFormat:
      @"%@\n\\pagestyle{empty} "\
       "\\begin{document}"\
       "%@%@%@%@\n"\
       "\\end{document}",
       [self _replaceYenSymbol:colouredPreamble], addSymbolLeft,
       ([[PreferencesController currentCompositionConfigurationObjectForKey:
            CompositionConfigurationCompositionModeKey] intValue] == COMPOSITION_MODE_XELATEX) ? colorString : @"",
       [self _replaceYenSymbol:trimmedBody],
       addSymbolRight];

  //creates the corresponding latex file
  NSData* latexData = [normalSourceToCompile dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
  BOOL failed = ![latexData writeToFile:latexFilePath atomically:NO];
  
  if (!failed)
    [fullLog appendFormat:@"Source :\n%@\n", normalSourceToCompile];
      
  //PREPROCESSING
  NSDictionary* sharedEnvironment = [AppController environmentDict];
  NSDictionary* extraEnvironment =
    [NSDictionary dictionaryWithObjectsAndKeys:[latexFilePath stringByDeletingLastPathComponent], @"CURRENTDIRECTORY",
                                                [latexFilePath stringByDeletingPathExtension], @"INPUTFILE",
                                                latexFilePath, @"INPUTTEXFILE",
                                                pdfFilePath2, @"OUTPUTPDFFILE",
                                                (compositionMode == COMPOSITION_MODE_LATEXDVIPDF)
                                                  ? dviFilePath : nil, @"OUTPUTDVIFILE",
                                                nil];
  NSMutableDictionary* environment1 = [NSMutableDictionary dictionaryWithDictionary:sharedEnvironment];
  [environment1 addEntriesFromDictionary:extraEnvironment];
  NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
  NSDictionary* compositionConfiguration = [compositionConfigurations objectAtIndex:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];
  NSDictionary* additionalProcessingScripts = [compositionConfiguration objectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];
  NSDictionary* script = [additionalProcessingScripts objectForKey:[NSString stringWithFormat:@"%d",SCRIPT_PLACE_PREPROCESSING]];
  if (script && [[script objectForKey:ScriptEnabledKey] boolValue])
  {
    [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Pre-processing", @"Pre-processing")];
    [fullLog appendFormat:@"%@\n", [self descriptionForScript:script]];
    [self executeScript:script setEnvironment:environment1 logString:fullLog];
    [logTextView setString:fullLog];
  }

  NSString* customLog = nil;
  NSString* stdoutLog = nil;
  NSString* stderrLog = nil;
  failed |= ![self _composeLaTeX:latexFilePath customLog:&customLog stdoutLog:&stdoutLog stderrLog:&stderrLog
                 compositionMode:compositionMode];
  if (customLog)
    [fullLog appendString:customLog];
  [logTextView setString:fullLog];

  NSArray* errors = [self _filterLatexErrors:[stdoutLog stringByAppendingString:stderrLog] shiftLinesBy:errorLineShift];
  [self _analyzeErrors:errors];
  BOOL isDirectory = NO;
  failed |= errors && [errors count] && (![fileManager fileExistsAtPath:pdfFilePath isDirectory:&isDirectory] || !isDirectory);
  //STEP 1 is over. If it has failed, it is the fault of the user, and syntax errors will be reported

  //Middle-Processing
  if (!failed)
  {
    NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
    NSDictionary* compositionConfiguration = [compositionConfigurations objectAtIndex:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];
    NSDictionary* additionalProcessingScripts = [compositionConfiguration objectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];
    NSDictionary* script = [additionalProcessingScripts objectForKey:[NSString stringWithFormat:@"%d",SCRIPT_PLACE_MIDDLEPROCESSING]];
    if (script && [[script objectForKey:ScriptEnabledKey] boolValue])
    {
      [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Middle-processing", @"Middle-processing")];
      [fullLog appendFormat:@"%@\n", [self descriptionForScript:script]];
      [self executeScript:script setEnvironment:environment1 logString:fullLog];
      [logTextView setString:fullLog];
    }
  }

  //STEP 2
  BOOL shouldTryStep2 = (latexMode != LATEX_MODE_TEXT) && (latexMode != LATEX_MODE_EQNARRAY) &&
                         (compositionMode != COMPOSITION_MODE_LATEXDVIPDF) &&
                         (compositionMode != COMPOSITION_MODE_XELATEX);
  //But if the latex file passed this first latexisation, it is time to start step 2 and perform cropping and magnification.
  if (!failed)
  {
    if (shouldTryStep2) //we do not even try step 2 in TEXT mode, since we will perform step 3 to allow line breakings
    {
      AppController* appController = [AppController appController];
      //this magical template uses boxes that scales and automagically find their own geometry
      //But it may fail for some kinds of equation, especially multi-lines equations. However, we try it because it is fast
      //and efficient. This will even generated a baseline if it works !
      NSString* magicSourceToFindBaseLine =
        [NSString stringWithFormat:
          @"%@\n" //preamble
          "\\pagestyle{empty}\n"
          "\\usepackage{geometry}\n"
          "\\usepackage{graphicx}\n"
          "\\newsavebox{\\latexitbox}\n"
          "\\newcommand{\\latexitscalefactor}{%f}\n" //magnification
          "\\newlength{\\latexitwidth}\n\\newlength{\\latexitheight}\n\\newlength{\\latexitdepth}\n"
          "\\setlength{\\topskip}{0pt}\n\\setlength{\\parindent}{0pt}\n\\setlength{\\abovedisplayskip}{0pt}\n"
          "\\setlength{\\belowdisplayskip}{0pt}\n"
          "\\normalfont\n"
          "\\begin{lrbox}{\\latexitbox}\n"
          "%@%@%@\n" //source text
          "\\end{lrbox}\n"
          "\\settowidth{\\latexitwidth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"
          "\\settoheight{\\latexitheight}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"
          "\\settodepth{\\latexitdepth}{\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}}\n"
          "\\newwrite\\foo \\immediate\\openout\\foo=\\jobname.sizes \\immediate\\write\\foo{\\the\\latexitdepth (Depth)}\n"
          "\\immediate\\write\\foo{\\the\\latexitheight (Height)}\n"
          "\\addtolength{\\latexitheight}{\\latexitdepth}\n"
          "\\addtolength{\\latexitheight}{%f pt}\n" //little correction
          "\\addtolength{\\latexitheight}{%f pt}\n" //top margin
          "\\addtolength{\\latexitwidth}{%f pt}\n" //right margin
          "\\immediate\\write\\foo{\\the\\latexitheight (TotalHeight)} \\immediate\\write\\foo{\\the\\latexitwidth (Width)}\n"
          "\\closeout\\foo \\geometry{paperwidth=\\latexitwidth,paperheight=\\latexitheight,margin=0pt,left=%f pt,top=%f pt}\n"
          "\\begin{document}\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}\\end{document}\n",
          [self _replaceYenSymbol:colouredPreamble], //preamble
          magnification/10.0, //latexitscalefactor = magnification
          addSymbolLeft, [self _replaceYenSymbol:body], addSymbolRight, //source text
          800*magnification/10000, //little correction to avoid cropping errors (empirically found)
          [appController marginControllerTopMargin]+[appController marginControllerBottomMargin],//top margin
          [appController marginControllerLeftMargin]+[appController marginControllerRightMargin],//right margin
          [appController marginControllerLeftMargin],400*magnification/10000+[appController marginControllerTopMargin]//for geometry
          ];
      
      //try to latexise that file
      NSData* latexData = [magicSourceToFindBaseLine dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];  
      failed |= ![latexData writeToFile:latexBaselineFilePath atomically:NO];
      if (!failed)
        pdfData = [self _composeLaTeX:latexBaselineFilePath customLog:&customLog stdoutLog:&stdoutLog stderrLog:&stderrLog
                      compositionMode:compositionMode];
      failed |= !pdfData;
    }//end of step 2
    
    //Now, step 2 may have failed. We check it. If it has not failed, that's great, the pdf result is the one we wanted !
    float baseline = 0;
    if (!failed && shouldTryStep2)
    {
      NSStringEncoding encoding = NSUTF8StringEncoding;
      NSError* error = nil;
      //try to read the baseline in the "sizes" file magically generated
      NSString* sizes = [NSString stringWithContentsOfFile:sizesFilePath guessEncoding:&encoding error:&error];
      NSScanner* scanner = [NSScanner scannerWithString:sizes];
      [scanner scanFloat:&baseline];
      //Step 2 is over, it has worked, so step 3 is useless.
    }
    //STEP 3
    else //if step 2 failed, we must use the heavy method of step 3
    {
      AppController* appController = [AppController appController];
      failed = NO; //since step 3 is a resort, step 2 is not a real failure, so we reset <failed> to NO
      pdfData = nil;
      NSRect boundingBox = [self _computeBoundingBox:pdfFilePath]; //compute the bounding box of the pdf file generated during step 1
      boundingBox.origin.x    -= [appController marginControllerLeftMargin]/(magnification/10);
      boundingBox.origin.y    -= [appController marginControllerBottomMargin]/(magnification/10);
      boundingBox.size.width  += ([appController marginControllerRightMargin]+[appController marginControllerLeftMargin])/(magnification/10);
      boundingBox.size.height += ([appController marginControllerBottomMargin]+[appController marginControllerTopMargin])/(magnification/10);

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
          "\\addtolength{\\latexitheight}{%f pt}\n" //little correction
          "\\immediate\\write\\foo{\\the\\latexitheight (TotalHeight)} \\immediate\\write\\foo{\\the\\latexitwidth (Width)}\n"\
          "\\closeout\\foo \\geometry{paperwidth=\\latexitwidth,paperheight=\\latexitheight,margin=0pt}\n"\
          "\\begin{document}\\scalebox{\\latexitscalefactor}{\\usebox{\\latexitbox}}\\end{document}\n", 
          //[self _replaceYenSymbol:colouredPreamble],
	  @"\\documentclass[10pt]{article}\n",//minimal preamble
	  magnification/10.0,
          boundingBox.origin.x, boundingBox.origin.y,
          boundingBox.origin.x+boundingBox.size.width, boundingBox.origin.y+boundingBox.size.height,
          pdfFile,
          400*magnification/10000]; //little correction to avoid cropping errors (empirically found)

      //Latexisation of step 3. Should never fail. Should always be performed in PDFLatexMode to get a proper bounding box
      NSData* latexData = [magicSourceToProducePDF dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];  
      failed |= ![latexData writeToFile:latexFilePath2 atomically:NO];
      if (!failed)
        pdfData = [self _composeLaTeX:latexFilePath2 customLog:&customLog stdoutLog:&stdoutLog stderrLog:&stderrLog
                      compositionMode:COMPOSITION_MODE_PDFLATEX];
      failed |= !pdfData;
    }//end STEP 3
    
    //the baseline is affected by the bottom margin
    baseline += [[AppController appController] marginControllerBottomMargin];

    //Now that we are here, either step 2 passed, or step 3 passed. (But if step 2 failed, step 3 should not have failed)
    //pdfData should contain the cropped/magnified/coloured wanted image
    #ifndef PANTHER
    if (pdfData)
    {
      //in the meta-data of the PDF we store as much info as we can : preamble, body, size, color, mode, baseline...
      PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
      NSDictionary* attributes =
        [NSDictionary dictionaryWithObjectsAndKeys:
           [NSApp applicationName], PDFDocumentCreatorAttribute, nil];
      [pdfDocument setDocumentAttributes:attributes];
      pdfData = [pdfDocument dataRepresentation];
      [pdfDocument release];
    }
    #endif

    if (pdfData)
    {
      //POSTPROCESSING
      NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
      NSDictionary* compositionConfiguration = [compositionConfigurations objectAtIndex:[userDefaults integerForKey:CurrentCompositionConfigurationIndexKey]];
      NSDictionary* additionalProcessingScripts = [compositionConfiguration objectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];
      NSDictionary* script = [additionalProcessingScripts objectForKey:[NSString stringWithFormat:@"%d",SCRIPT_PLACE_POSTPROCESSING]];
      if (script && [[script objectForKey:ScriptEnabledKey] boolValue])
      {
        [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Post-processing", @"Post-processing")];
        [fullLog appendFormat:@"%@\n", [self descriptionForScript:script]];
        [self executeScript:script setEnvironment:environment1 logString:fullLog];
        [logTextView setString:fullLog];
      }
    }

    //adds some meta-data to be compatible with Latex Equation Editor
    if (pdfData)
      pdfData = [[AppController appController]
                  annotatePdfDataInLEEFormat:pdfData preamble:preamble source:body color:color
                                        mode:latexMode magnification:magnification baseline:baseline
                             backgroundColor:[imageView backgroundColor] title:nil];

    [pdfData writeToFile:pdfFilePath atomically:NO];//Recreates the document with the new meta-data
    
  }//end if latex source could be compiled
  
  //returns the cropped/magnified/coloured image if possible; nil if it has failed. 
  return pdfData;
}

//returns an array of the errors. Each case will contain an error string
-(NSArray*) _filterLatexErrors:(NSString*)fullErrorLog shiftLinesBy:(int)errorLineShift
{
  NSArray* errorsNotFiltered = [fullErrorLog componentsSeparatedByString:@"\n"];
  NSMutableArray* filteredErrors = [NSMutableArray arrayWithCapacity:[errorsNotFiltered count]];
  NSEnumerator* enumerator = [errorsNotFiltered objectEnumerator];
  NSString* line = [enumerator nextObject];
  while(line)
  {
    NSArray* components = [line componentsSeparatedByString:@":"];
    if ([components count] >= 3) 
    {
      NSString* fileComponent  = [components objectAtIndex:0];
      NSString* lineComponent  = [components objectAtIndex:1];
      BOOL      lineComponentIsANumber = ![lineComponent isEqualToString:@""] && 
        [[lineComponent stringByTrimmingCharactersInSet:[NSCharacterSet decimalDigitCharacterSet]] isEqualToString:@""];
      NSString* errorComponent = [[components subarrayWithRange:NSMakeRange(2, [components count]-2)] componentsJoinedByString:@":"];
      if (lineComponentIsANumber)
        lineComponent = [[NSNumber numberWithInt:[lineComponent intValue]+errorLineShift] stringValue];
      if (lineComponentIsANumber || ([line rangeOfString:@"! LaTeX Error:"].location != NSNotFound))
      {
        NSArray* fixedErrorComponents = [NSArray arrayWithObjects:fileComponent, lineComponent, errorComponent, nil];
        NSString* fixedError = [fixedErrorComponents componentsJoinedByString:@":"];
        NSMutableString* fullError = [NSMutableString stringWithString:fixedError];
        while([line length] && ([line characterAtIndex:[line length]-1] != '.'))
        {
          line = [enumerator nextObject];
          [fullError appendString:line];
        }//end if error message on multiple lines
        [filteredErrors addObject:fullError];
      }//end if error seems ok
    }//end if >=3 components
    else if ([components count] > 1) //if 1 < < 3 components
    {
      if ([line rangeOfString:@"! LaTeX Error:"].location != NSNotFound)
      {
        NSString* fileComponent = @"";
        NSString* lineComponent = @"";
        NSString* errorComponent = [[components subarrayWithRange:NSMakeRange(1, [components count]-1)] componentsJoinedByString:@":"];
        NSArray* fixedErrorComponents = [NSArray arrayWithObjects:fileComponent, lineComponent, errorComponent, nil];
        NSString* fixedError = [fixedErrorComponents componentsJoinedByString:@":"];
        NSMutableString* fullError = [NSMutableString stringWithString:fixedError];
        while([line length] && ([line characterAtIndex:[line length]-1] != '.'))
        {
          line = [enumerator nextObject];
          [fullError appendString:line];
        }//end if error message on multiple lines
        [filteredErrors addObject:fullError];
      }//end if error seems ok
    }//end if > 1 component
    line = [enumerator nextObject];
  }//end while line
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
      newPreambleFrame.size.height = (1-factor)*preambleFrame.size.height + factor*newPreambleHeight;
      newSourceFrame.size.height   = (1-factor)*sourceFrame.size.height   + factor*newSourceHeight;
      [preambleView setFrame:newPreambleFrame]; 
      [sourceView setFrame: newSourceFrame]; 
      [splitView adjustSubviews]; 
      [splitView displayIfNeeded];
      [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1/100.0f]];
    }
  }//end if there is something to change
}

//creates an historyItem summarizing the current document state
-(HistoryItem*) historyItemWithCurrentState
{
  int selectedSegment = [typeOfTextControl selectedSegment];
  int tag = [[typeOfTextControl cell] tagForSegment:selectedSegment];
  latex_mode_t mode = (latex_mode_t) tag;
  BOOL automaticHighContrastedPreviewBackground =
    [[NSUserDefaults standardUserDefaults] boolForKey:DefaultAutomaticHighContrastedPreviewBackgroundKey];
  NSColor* backgroundColor = automaticHighContrastedPreviewBackground ? nil : [imageView backgroundColor];
  return [HistoryItem historyItemWithPDFData:[imageView pdfData]  preamble:[preambleTextView textStorage]
                                  sourceText:[sourceTextView textStorage] color:[colorWell color]
                                   pointSize:[sizeText doubleValue] date:[NSDate date] mode:mode backgroundColor:backgroundColor];
}
//end historyItemWithCurrentState

-(void) applyPdfData:(NSData*)pdfData
{
  [self applyHistoryItem:[HistoryItem historyItemWithPDFData:pdfData useDefaults:YES]];
}
//end applyPdfData:

-(LibraryFile*) lastAppliedLibraryFile
{
  return lastAppliedLibraryFile;
}
//end lastAppliedLibraryFile

-(void) setLastAppliedLibraryFile:(LibraryFile*)libraryFile
{
  [libraryFile retain];
  [lastAppliedLibraryFile release];
  lastAppliedLibraryFile = libraryFile;
}
//end setLastAppliedLibraryFile:

//updates the document according to the given library file
-(void) applyLibraryFile:(LibraryFile*)libraryFile
{
  [self applyHistoryItem:[libraryFile value]]; //sets lastAppliedLibraryFile to nil
  [self setLastAppliedLibraryFile:libraryFile];
}
//end applyLibraryFile:

//sets the state of the document according to the given history item
-(void) applyHistoryItem:(HistoryItem*)historyItem
{
  [[[self undoManager] prepareWithInvocationTarget:self] applyHistoryItem:[self historyItemWithCurrentState]];
  [[[self undoManager] prepareWithInvocationTarget:self] setLastAppliedLibraryFile:[self lastAppliedLibraryFile]];
  [self setLastAppliedLibraryFile:nil];
  if (historyItem)
  {
    [self _setLogTableViewVisible:NO];
    [imageView setPDFData:[historyItem pdfData] cachedImage:[historyItem pdfImage]];
    [self setPreamble:[historyItem preamble]];
    [self setSourceText:[historyItem sourceText]];
    [colorWell setColor:[historyItem color]];
    [sizeText setDoubleValue:[historyItem pointSize]];
    [typeOfTextControl selectSegmentWithTag:[historyItem mode]];
    [imageView setBackgroundColor:[historyItem backgroundColor] updateHistoryItem:NO];
  }
  else
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [self _setLogTableViewVisible:NO];
    [imageView setPDFData:nil cachedImage:nil];
    NSFont* defaultFont = [NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]];
    [preambleTextView setTypingAttributes:[NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName]];
    [sourceTextView   setTypingAttributes:[NSDictionary dictionaryWithObject:defaultFont forKey:NSFontAttributeName]];
    [self setPreamble:[[AppController appController] preamble]];
    [self setSourceText:[[[NSAttributedString alloc ] init] autorelease]];
    [colorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:DefaultColorKey]]];
    [sizeText setDoubleValue:[userDefaults floatForKey:DefaultPointSizeKey]];
    [typeOfTextControl selectSegmentWithTag:[userDefaults integerForKey:DefaultModeKey]];
    [imageView setBackgroundColor:[NSColor colorWithData:[[NSUserDefaults standardUserDefaults] objectForKey:DefaultImageViewBackgroundKey]]
                updateHistoryItem:NO];
  }
}

//calls the log window
-(IBAction) displayLastLog:(id)sender
{
  [logWindow makeKeyAndOrderFront:self];
}

-(void) updateChangeCount:(NSDocumentChangeType)changeType
{
  //does nothing (prevents dirty flag)
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
  export_format_t exportFormat = [sender selectedTag];
  NSString* extension = nil;
  switch(exportFormat)
  {
    case EXPORT_FORMAT_PDF:
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
      extension = @"pdf";
      break;
    case EXPORT_FORMAT_EPS:
      extension = @"eps";
      break;
    case EXPORT_FORMAT_TIFF:
      extension = @"tiff";
      break;
    case EXPORT_FORMAT_PNG:
      extension = @"png";
      break;
    case EXPORT_FORMAT_JPEG:
      extension = @"jpeg";
      break;
  }

  if (exportFormat == EXPORT_FORMAT_JPEG)
  {
    allowOptions = YES;
    [currentSavePanel setAllowedFileTypes:[NSArray arrayWithObjects:@"jpg", @"jpeg", nil]];
    [saveAccessoryViewJpegWarning setHidden:NO];
  }
  else
  {
    [saveAccessoryViewJpegWarning setHidden:YES];
    [currentSavePanel setRequiredFileType:extension];
    allowOptions = NO;
  }

  [saveAccessoryViewOptionsButton setEnabled:allowOptions];
}

//enables or disables some exports
-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok  = YES;
  if ([sender tag] == EXPORT_FORMAT_EPS)
    ok = [[AppController appController] isGsAvailable];
  else if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [[AppController appController] isGsAvailable] && [[AppController appController] isPs2PdfAvailable];
  return ok;
}

//asks for a filename and format to export
-(IBAction) exportImage:(id)sender
{
  //first, disables PDF_NOT_EMBEDDED_FONTS if needed
  if (([saveAccessoryViewPopupFormat selectedTag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) &&
      (![[AppController appController] isGsAvailable] || ![[AppController appController] isPs2PdfAvailable]))
    [saveAccessoryViewPopupFormat selectItemWithTag:EXPORT_FORMAT_PDF];

  currentSavePanel = [NSSavePanel savePanel];
  [self saveAccessoryViewPopupFormatDidChange:saveAccessoryViewPopupFormat];
  [currentSavePanel setCanSelectHiddenExtension:YES];
  [currentSavePanel setCanCreateDirectories:YES];
  [currentSavePanel setAccessoryView:saveAccessoryView];
  [currentSavePanel setExtensionHidden:NO];
  [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(_updateTextField:)
                                 userInfo:saveAccessoryViewScaleAsPercentTextField repeats:NO];
  [currentSavePanel beginSheetForDirectory:nil file:NSLocalizedString(@"Untitled", @"Untitled")
                            modalForWindow:[self windowForSheet] modalDelegate:self
                            didEndSelector:@selector(exportChooseFileDidEnd:returnCode:contextInfo:)
                               contextInfo:NULL];
}

-(void) controlTextDidEndEditing:(NSNotification *)aNotification
{
  if ([aNotification object] == saveAccessoryViewScaleAsPercentTextField);
    [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(_updateTextField:)
                                   userInfo:saveAccessoryViewScaleAsPercentTextField repeats:NO];
}

-(void) _updateTextField:(NSTimer*)timer
{
  NSTextField* textField = [timer userInfo];
  [textField drawCellInside:[textField cell]];
}
//end _updateTextField:

-(void) exportChooseFileDidEnd:(NSSavePanel*)sheet returnCode:(int)code contextInfo:(void*)contextInfo
{
  if ((code == NSOKButton) && [imageView image])
  {
    NSData*  pdfData = [imageView pdfData];
    export_format_t format = [saveAccessoryViewPopupFormat selectedTag];
    float scaleAsPercent = [saveAccessoryViewScaleAsPercentTextField floatValue];
    NSData*   data   = [[AppController appController] dataForType:format pdfData:pdfData jpegColor:[jpegColorWell color]
                                                      jpegQuality:jpegQuality/100 scaleAsPercent:scaleAsPercent];
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
      NSColor* backgroundColor = (format == EXPORT_FORMAT_JPEG) ? [jpegColorWell color] : nil;
      [[NSWorkspace sharedWorkspace] setIcon:[[AppController appController] makeIconForData:pdfData backgroundColor:backgroundColor]
                                     forFile:filePath options:options];
    }
  }//end if save
  currentSavePanel = nil;
}
//end exportChooseFileDidEnd:returnCode:contextInfo:

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
//end selectedText

-(void) insertText:(NSString*)text
{
  NSResponder* firstResponder = [[self windowForSheet] firstResponder];
  if ((firstResponder == sourceTextView) || (firstResponder == preambleTextView))
    [firstResponder insertText:text];
}
//end insertText:

-(BOOL) isBusy
{
  return isBusy;
}
//end isBusy

//teleportation to the faulty lines of the latex code when the user clicks a line in the error tableview
-(void) _clickErrorLine:(NSNotification*)aNotification
{
  //registered only for logTableView
  NSNumber* number = (NSNumber*) [[aNotification userInfo] objectForKey:@"lineError"];
  if (!number)
  {
    [self displayLastLog:self];
    NSString* message = [[aNotification userInfo] objectForKey:@"message"];
    if (!message)
      message = @"";
    NSString* logText = [logTextView string];
    NSRange errorRange = [logText rangeOfString:message options:NSCaseInsensitiveSearch];
    if (errorRange.location != NSNotFound)
    {
      [logTextView setSelectedRange:errorRange];
      [logTextView scrollRangeToVisible:errorRange];
    }
  }
  else
  {
    int row = [number intValue];
    if ([preambleTextView gotoLine:row])
      [self setPreambleVisible:YES];
    else
      [sourceTextView gotoLine:row];
  }
}
//end _clickErrorLine:

//hides/display the error log table view
-(void) _setLogTableViewVisible:(BOOL)status
{
  NSScrollView* scrollView = (NSScrollView*) [[logTableView superview] superview];
  [scrollView setHidden:!status];
  [scrollView setNeedsDisplay:YES];
}
//end _setLogTableViewVisible:

//returns the linkBack link
-(LinkBack*) linkBackLink
{
  return linkBackLink;
}
//end linkBackLink

//sets up a new linkBack link
-(void) setLinkBackLink:(LinkBack*)newLinkBackLink
{
  [self closeLinkBackLink:linkBackLink];
  linkBackLink = newLinkBackLink;
}
//end setLinkBackLink:

//if current linkBack link is aLink, then close it. Also close if aLink = nil
-(void) closeLinkBackLink:(LinkBack*)aLink
{
  if (!aLink || (linkBackLink == aLink))
  {
    aLink = linkBackLink;
    linkBackLink = nil;
    [aLink closeLink];
    [self setDocumentTitle:nil];
  }
}
//end closeLinkBackLink:

-(NSImage*) _checkEasterEgg
{
  NSImage* easterEggImage = nil;
  
  NSCalendarDate* now = [NSCalendarDate date];
  NSString* easterEggString = nil;
  if (([now monthOfYear] == 4) && ([now dayOfMonth] == 1))
    easterEggString = @"aprilfish";
    
  if (easterEggString)
  {
    NSDictionary* resources = [NSDictionary dictionaryWithObjectsAndKeys:@"poisson.pdf", @"aprilfish", nil];
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSData* dataFromUserDefaults = [userDefaults dataForKey:LastEasterEggsDatesKey];
    NSMutableDictionary* easterEggLastDates = dataFromUserDefaults ?
      [NSMutableDictionary dictionaryWithDictionary:[NSUnarchiver unarchiveObjectWithData:dataFromUserDefaults]] :
      [NSMutableDictionary dictionary];
    if (!easterEggLastDates)
      easterEggLastDates = [NSMutableDictionary dictionary];
    NSCalendarDate* easterEggLastDate = [easterEggLastDates objectForKey:easterEggString];
    if ((!easterEggLastDate) || [now isLessThan:easterEggLastDate] || ([now yearOfCommonEra] != [easterEggLastDate yearOfCommonEra]))
    {
      NSString* resource = [resources objectForKey:easterEggString];
      NSString* filePath = resource ? [[NSBundle mainBundle] pathForResource:[resource stringByDeletingPathExtension]
                                                                      ofType:[resource pathExtension]] : nil;
      if (resource && filePath)
        easterEggImage = [[[NSImage alloc] initWithContentsOfFile:filePath] autorelease];
      [easterEggLastDates setObject:[NSCalendarDate date] forKey:easterEggString];
    }
    [userDefaults setObject:[NSArchiver archivedDataWithRootObject:easterEggLastDates] forKey:LastEasterEggsDatesKey];
  }
  return easterEggImage;
}
//end _checkEasterEgg:

-(void) executeScript:(NSDictionary*)script setEnvironment:(NSDictionary*)environment logString:(NSMutableString*)logString
{
  if (script && [[script objectForKey:ScriptEnabledKey] boolValue])
  {
    NSString* directory       = [AppController latexitTemporaryPath];
    NSString* filePrefix      = [NSString stringWithFormat:@"latexit-%u", uniqueId]; //file name, related to the current document
    NSString* latexScript     = [NSString stringWithFormat:@"%@.script", filePrefix];
    NSString* latexScriptPath = [directory stringByAppendingPathComponent:latexScript];
    NSString* logScript       = [NSString stringWithFormat:@"%@.script.log", filePrefix];
    NSString* logScriptPath   = [directory stringByAppendingPathComponent:logScript];

    NSFileManager* fileManager = [NSFileManager defaultManager];
    [fileManager removeFileAtPath:latexScriptPath handler:NULL];
    [fileManager removeFileAtPath:logScriptPath   handler:NULL];
    
    NSString* scriptBody = nil;

    NSNumber* scriptType = [script objectForKey:ScriptSourceTypeKey];
    script_source_t source = scriptType ? [scriptType intValue] : SCRIPT_SOURCE_STRING;

    NSStringEncoding encoding = NSUTF8StringEncoding;
    NSError* error = nil;
    switch(source)
    {
      case SCRIPT_SOURCE_STRING: scriptBody = [script objectForKey:ScriptBodyKey];break;
      case SCRIPT_SOURCE_FILE: scriptBody = [NSString stringWithContentsOfFile:[script objectForKey:ScriptFileKey] guessEncoding:&encoding error:&error]; break;
    }
    
    NSData* scriptData = [scriptBody dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    [scriptData writeToFile:latexScriptPath atomically:NO];

    NSMutableDictionary* fileAttributes =
      [NSMutableDictionary dictionaryWithDictionary:[fileManager fileSystemAttributesAtPath:latexScriptPath]];
    NSNumber* posixPermissions = [fileAttributes objectForKey:NSFilePosixPermissions];
    posixPermissions = [NSNumber numberWithUnsignedLong:[posixPermissions unsignedLongValue] | 0700];//add rwx flag
    [fileAttributes setObject:posixPermissions forKey:NSFilePosixPermissions];
    [fileManager changeFileAttributes:fileAttributes atPath:latexScriptPath];

    NSString* scriptShell = nil;
    switch(source)
    {
      case SCRIPT_SOURCE_STRING: scriptShell = [script objectForKey:ScriptShellKey]; break;
      case SCRIPT_SOURCE_FILE: scriptShell = @"/bin/sh"; break;
    }

    NSPipe* pipeForOutput = [NSPipe pipe];
    SystemTask* task = [[[SystemTask alloc] init] autorelease];
    [task setCurrentDirectoryPath:directory];
    [task setEnvironment:environment];
    [task setLaunchPath:scriptShell];
    [task setArguments:[NSArray arrayWithObjects:@"-c", latexScriptPath, nil]];
    [task setCurrentDirectoryPath:[latexScriptPath stringByDeletingLastPathComponent]];
    [task setStandardOutput:pipeForOutput];
    [task setStandardError:pipeForOutput];

    [logString appendFormat:@"----------------- %@ script -----------------\n", NSLocalizedString(@"executing", @"executing")];
    [logString appendFormat:@"%@\n", [task equivalentLaunchCommand]];

    @try {
      [task setTimeOut:30];
      [task launch];
      [task waitUntilExit];
      if ([task hasReachedTimeout])
        [logString appendFormat:@"\n%@\n\n", NSLocalizedString(@"Script too long : timeout reached",
                                                               @"Script too long : timeout reached")];
      else if ([task terminationStatus])
      {
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"Script failed")];
        NSString* outputLog = [[[NSString alloc] initWithData:[[pipeForOutput fileHandleForReading] availableData]
                                                     encoding:encoding] autorelease];
        [logString appendFormat:@"%@\n----------------------------------------------------\n", outputLog];
      }
      else
      {
        NSString* outputLog = [[[NSString alloc] initWithData:[[pipeForOutput fileHandleForReading] availableData]
                                                     encoding:encoding] autorelease];
        [logString appendFormat:@"\n%@\n----------------------------------------------------\n", outputLog];
      }
    }//end try task
    @catch(NSException* e) {
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"Script failed")];
        NSString* outputLog = [[[NSString alloc] initWithData:[[pipeForOutput fileHandleForReading] availableData]
                                                     encoding:encoding] autorelease];
        [logString appendFormat:@"%@\n----------------------------------------------------\n", outputLog];
    }
  }//end if (source != SCRIPT_SOURCE_NONE)
}
//end executeScript:setEnvironment:logString:

-(NSString*) descriptionForScript:(NSDictionary*)script
{
  NSMutableString* description = [NSMutableString string];
  if (script)
  {
    switch([[script objectForKey:ScriptSourceTypeKey] intValue])
    {
      case SCRIPT_SOURCE_STRING :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"Shell", @"Shell"),
          [script objectForKey:ScriptShellKey],
          NSLocalizedString(@"Body", @"Body"),
          [script objectForKey:ScriptBodyKey]];
        break;
      case SCRIPT_SOURCE_FILE :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"File", @"File"),
          [script objectForKey:ScriptShellKey],
          NSLocalizedString(@"Content", @"Content"),
          [script objectForKey:ScriptFileKey]];
        break;
    }//end switch
  }//end if script
  return description;
}
//end descriptionForScript:

-(IBAction) nullAction:(id)sender
{
}
//end nullAction:

@end
