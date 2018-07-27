//  MyDocument.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright Pierre Chatelier 2005, 2006, 2007, 2008 . All rights reserved.

// The main document of LaTeXiT. There is much to say !

#import "MyDocument.h"

#import "AdditionalFilesController.h"
#import "AppController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LatexProcessor.h"
#import "LibraryFile.h"
#import "LineCountTextView.h"
#import "LogTableView.h"
#import "MyImageView.h"
#import "NotifyingScrollView.h"
#import "NSApplicationExtended.h"
#import "NSColorExtended.h"
#import "NSDictionaryExtended.h"
#import "NSFileManagerExtended.h"
#import "NSFontExtended.h"
#import "NSPopUpButtonExtended.h"
#import "NSSegmentedControlExtended.h"
#import "NSStringExtended.h"
#import "NSTaskExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "SMLSyntaxColouring.h"
#import "SystemTask.h"
#import "Utils.h"

#ifdef PANTHER
#import <LinkBack-panther/LinkBack.h>
#else
#import <LinkBack/LinkBack.h>
#endif

#ifndef PANTHER
#import <Quartz/Quartz.h>
#endif

#import <OgreKit/OgreKit.h>

//useful to assign a unique id to each document
static unsigned long firstFreeId = 1; //increases when documents are created

//if a document is closed, its id becomes free, and we should consider reusing it instead of increasing firstFreeId
static NSMutableArray* freeIds = nil;

double yaxb(double x, double x0, double y0, double x1, double y1);
double yaxb(double x, double x0, double y0, double x1, double y1)
{
  double a = (y1-y0)/(x1-x0);
  double b = y0-a*x0;
  return a*x+b; 
}
//end yaxb()

@interface MyDocument (PrivateAPI)

+(unsigned long) _giveId; //returns a free id and marks it as used
+(void) _releaseId:(unsigned long)anId; //releases an id

//updates the logTableView to report the errors
-(void) _analyzeErrors:(NSArray*)errors;

-(void) _lineCountDidChange:(NSNotification*)aNotification;
-(void) _clickErrorLine:(NSNotification*)aNotification;

-(void) _setLogTableViewVisible:(BOOL)status;

-(NSImage*) _checkEasterEgg;//may return an easter egg image

-(void) _updateTextField:(NSTimer*)timer; //to fix a refresh bug
-(void) closeSheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;//for doc closing

-(NSString*) descriptionForScript:(NSDictionary*)script;
-(void) _decomposeString:(NSString*)string preamble:(NSString**)preamble body:(NSString**)body;

-(void) exportImageWithData:(NSData*)pdfData format:(export_format_t)format scaleAsPercent:(float)scaleAsPercent
                  jpegColor:(NSColor*)jpegColor jpegQuality:(float)jpegQuality filePath:(NSString*)filePath;
@end

@implementation MyDocument

+(void) initialize
{
  if (!freeIds)
    freeIds = [[NSMutableArray alloc] init];
}
//end initialize

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
  
  NSImage*  image = [NSImage imageNamed:@"button-menu"];
  [changePreambleButton setImage:image];
  [changePreambleButton setAlternateImage:image];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(popUpButtonWillPopUp:) name:NSPopUpButtonCellWillPopUpNotification object:[changePreambleButton cell]];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(scrollViewDidScroll:) name:NotifyingScrollViewDidScrollNotification object:[[preambleTextView superview] superview]];

  [self setReducedTextArea:([[NSUserDefaults standardUserDefaults] integerForKey:ReducedTextAreaStateKey] == NSOnState)];

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
  NSMutableDictionary* typingAttributes = [NSMutableDictionary dictionaryWithDictionary:[preambleTextView typingAttributes]];
  [typingAttributes setObject:defaultFont forKey:NSFontAttributeName];
  [preambleTextView setTypingAttributes:typingAttributes];
  [sourceTextView   setTypingAttributes:typingAttributes];

  NSMutableParagraphStyle* paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
  NSArray* arrayOfTabs = [paragraphStyle tabStops];
  float defaultTabInterval =
    ([arrayOfTabs count] >= 2) ? [(NSTextTab*)[arrayOfTabs objectAtIndex:1] location]-[(NSTextTab*)[arrayOfTabs objectAtIndex:0] location] :
    [paragraphStyle defaultTabInterval];
  [paragraphStyle setDefaultTabInterval:defaultTabInterval];
  [paragraphStyle setTabStops:[NSArray array]];
  [preambleTextView setDefaultParagraphStyle:paragraphStyle];
  [sourceTextView   setDefaultParagraphStyle:paragraphStyle];
  
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
    [self setPreamble:[[AppController appController] preambleForLatexisation]];
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
//end windowControllerDidLoadNib:

//set the document title that will be displayed as window title. There is no represented file associated
-(void) setDocumentTitle:(NSString*)title
{
  [title retain];
  [documentTitle release];
  documentTitle = title;
  [[[self windowForSheet] windowController] synchronizeWindowTitleWithDocumentName];
}
//end setDocumentTitle:

-(void) scrollViewDidScroll:(NSNotification*)notification
{
  [[preambleTextView lineCountRulerView] setNeedsDisplay:YES];
  [changePreambleButton setNeedsDisplay:YES];
}
//end scrollViewDidScroll:

//some accessors useful sometimes
-(LineCountTextView*) sourceTextView
{
  return sourceTextView;
}
//end sourceTextView:

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
  if ([self fileURL])
    title = [super displayName];
  else if (!title)
    title = [NSString stringWithFormat:@"%@-%u", [NSApp applicationName], uniqueId];
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
  if ([aType isEqualToString:@"LatexPalette"])
  {
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
      [self _decomposeString:string preamble:&initialPreamble body:&initialBody];
    }//end if plain text
  }//end if (text document)
  return ok;
}
//end readFromFile:ofType

-(void) _decomposeString:(NSString*)string preamble:(NSString**)preamble body:(NSString**)body
{
  //if a text document is opened, try to split it into preamble+body
  if (string)
  {
    NSRange beginDocument = [string rangeOfString:@"\\begin{document}" options:NSCaseInsensitiveSearch];
    NSRange endDocument   = [string rangeOfString:@"\\end{document}" options:NSCaseInsensitiveSearch];
    *preamble = (beginDocument.location == NSNotFound) ? nil :
                   [string substringWithRange:NSMakeRange(0, beginDocument.location)];
    *body = (beginDocument.location == NSNotFound) ? string :
               (endDocument.location == NSNotFound) ?
                 [string substringWithRange:
                    NSMakeRange(beginDocument.location+beginDocument.length,
                                [string length]-(beginDocument.location+beginDocument.length))] :
                 [string substringWithRange:
                    NSMakeRange(beginDocument.location+beginDocument.length,
                                endDocument.location-(beginDocument.location+beginDocument.length))];
  }//end if string
}
//end _decomposeString:preamble:body:

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
    if ([[NSUserDefaults standardUserDefaults] boolForKey:ShowWhiteColorWarningKey] &&
        [[colorWell color] isRGBEqualTo:[NSColor whiteColor]])
    {
      [[[AppController appController] whiteColorWarningWindow] center];
      int result = [NSApp runModalForWindow:[[AppController appController] whiteColorWarningWindow]];
      if (result == NSCancelButton)
        mustProcess = NO;
    }
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
    NSArray* errors = nil;
    NSData* pdfData = nil;
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL useLoginShell = [userDefaults boolForKey:UseLoginShellKey];
    NSString* workingDirectory = [AppController latexitTemporaryPath];
    NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-%u", uniqueId];
    NSDictionary* fullEnvironment  = [AppController fullEnvironmentDict];
    NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
    int compositionConfigurationIndex = [userDefaults integerForKey:CurrentCompositionConfigurationIndexKey];
    NSDictionary* configuration = ((compositionConfigurationIndex<0) ||
                                   ((unsigned)compositionConfigurationIndex >= [compositionConfigurations count])) ? nil :
                                  [compositionConfigurations objectAtIndex:compositionConfigurationIndex];
    composition_mode_t compositionMode =
      [[configuration objectForKey:CompositionConfigurationCompositionModeKey] intValue];
    NSString* pdfLatexPath = [configuration objectForKey:CompositionConfigurationPdfLatexPathKey];
    NSString* xeLatexPath = [configuration objectForKey:CompositionConfigurationXeLatexPathKey];
    NSString* latexPath = [configuration objectForKey:CompositionConfigurationLatexPathKey];
    NSString* dviPdfPath = [configuration objectForKey:CompositionConfigurationDvipdfPathKey];
    NSString* gsPath = [configuration objectForKey:CompositionConfigurationGsPathKey];
    NSString* ps2PdfPath = [configuration objectForKey:CompositionConfigurationPs2PdfPathKey];
    NSDictionary* additionalProcessingScripts = [configuration objectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];
    float leftMargin   = [[AppController appController] marginControllerLeftMargin];
    float rightMargin  = [[AppController appController] marginControllerRightMargin];
    float bottomMargin = [[AppController appController] marginControllerBottomMargin];
    float topMargin    = [[AppController appController] marginControllerTopMargin];
    NSString* outFullLog = nil;
    [LatexProcessor latexiseWithPreamble:preamble body:body color:color mode:mode magnification:[sizeText doubleValue]
                       compositionMode:compositionMode workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
                       additionalFilepaths:nil fullEnvironment:fullEnvironment useLoginShell:useLoginShell
                              pdfLatexPath:pdfLatexPath xeLatexPath:xeLatexPath latexPath:latexPath
                                dviPdfPath:dviPdfPath gsPath:gsPath ps2PdfPath:ps2PdfPath
                                leftMargin:leftMargin rightMargin:rightMargin
                                 topMargin:topMargin bottomMargin:bottomMargin
                           backgroundColor:[imageView backgroundColor] additionalProcessingScripts:additionalProcessingScripts
                               outFullLog:&outFullLog outErrors:&errors outPdfData:&pdfData];
    [logTextView setString:outFullLog];
    [self _analyzeErrors:errors];

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

-(IBAction) makeLatexAndExport:(id)sender
{
  [self makeLatex:sender];
  if ([self canReexport])
    [self reexportImage:sender];
}
//end makeLatexAndExport:

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
  //NSString* errFile   = [[filePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"err"];
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
  SystemTask* systemTask = [[[SystemTask alloc] initWithWorkingDirectory:[AppController latexitTemporaryPath]] autorelease];
  [systemTask setUsingLoginShell:[[NSUserDefaults standardUserDefaults] boolForKey:UseLoginShellKey]];
  [systemTask setCurrentDirectoryPath:directory];
  [systemTask setLaunchPath:executablePath];
  [systemTask setArguments:[NSArray arrayWithObjects:@"-file-line-error", @"-interaction", @"nonstopmode", texFile, nil]];
  [systemTask setEnvironment:[AppController fullEnvironmentDict]];
  [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n%@\n",
                                                        NSLocalizedString(@"processing", @"processing"),
                                                        [executablePath lastPathComponent],
                                                        [systemTask equivalentLaunchCommand]]];
  [systemTask launch];
  BOOL failed = ([systemTask terminationStatus] != 0) && ![fileManager fileExistsAtPath:pdfFile];
  NSString* errors = [[[NSString alloc] initWithData:[systemTask dataForStdOutput] encoding:NSUTF8StringEncoding] autorelease];
  [customString appendString:errors ? errors : @""];
  [stdoutString appendString:errors ? errors : @""];
  
  if (failed)
    [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n",
                               NSLocalizedString(@"error while processing", @"error while processing"),
                               [executablePath lastPathComponent]]];

  //if !failed and must call dvipdf...
  if (!failed && (compositionMode == COMPOSITION_MODE_LATEXDVIPDF))
  {
    SystemTask* dvipdfTask = [[SystemTask alloc] initWithWorkingDirectory:[AppController latexitTemporaryPath]];
    [dvipdfTask setUsingLoginShell:[[NSUserDefaults standardUserDefaults] boolForKey:UseLoginShellKey]];
    [dvipdfTask setCurrentDirectoryPath:directory];
    [dvipdfTask setEnvironment:[AppController extraEnvironmentDict]];
    [dvipdfTask setLaunchPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationDvipdfPathKey]];
    [dvipdfTask setArguments:[NSArray arrayWithObject:dviFile]];
    NSString* executablePath = [[dvipdfTask launchPath] lastPathComponent];
    @try
    {
      [customString appendString:[NSString stringWithFormat:@"\n--------------- %@ %@ ---------------\n%@\n",
                                                            NSLocalizedString(@"processing", @"processing"),
                                                            [[dvipdfTask launchPath] lastPathComponent],
                                                            [dvipdfTask commandLine]]];
      [dvipdfTask launch];
      [dvipdfTask waitUntilExit];
      NSData* stdoutData = [dvipdfTask dataForStdOutput];
      NSData* stderrData = [dvipdfTask dataForStdError];
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
                                 executablePath]];

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
//end _composeLaTeX:customLog:stdoutLog:stderrLog:compositionMode:

-(void) setLatexMode:(latex_mode_t)mode
{
  [typeOfTextControl selectSegmentWithTag:mode];
}
//end setLatexMode:

-(void) setColor:(NSColor*)color
{
  [colorWell setColor:color];
}
//end setColor:

-(void) setMagnification:(float)magnification
{
  [sizeText setFloatValue:magnification];
}
//end setMagnification:

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
//end _analyzeErrors:

-(BOOL) hasImage
{
  return ([imageView image] != nil);
}
//end hasImage

-(BOOL) isPreambleVisible
{
  //[[preambleTextView superview] superview] is a scrollview that is a subView of splitView
  return ([[[preambleTextView superview] superview] frame].size.height > 0);
}
//end isPreambleVisible

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
//end setPreambleVisible:

//creates an historyItem summarizing the current document state
-(HistoryItem*) historyItemWithCurrentState
{
  int selectedSegment = [typeOfTextControl selectedSegment];
  int tag = [[typeOfTextControl cell] tagForSegment:selectedSegment];
  latex_mode_t mode = (latex_mode_t) tag;
  BOOL automaticHighContrastedPreviewBackground =
    [[NSUserDefaults standardUserDefaults] boolForKey:DefaultAutomaticHighContrastedPreviewBackgroundKey];
  NSColor* backgroundColor = automaticHighContrastedPreviewBackground ? nil : [imageView backgroundColor];
  #warning preparing migration to Core Data
  #ifdef USE_COREDATA
  [[HistoryManager sharedManager]
    addItemWithPDFData:[imageView pdfData] preamble:[preambleTextView textStorage]
            sourceText:[sourceTextView textStorage] color:[colorWell color] pointSize:[sizeText doubleValue] date:[NSDate date]
                  mode:mode backgroundColor:backgroundColor];
  #endif
  return [HistoryItem historyItemWithPDFData:[imageView pdfData]  preamble:[preambleTextView textStorage]
                                  sourceText:[sourceTextView textStorage] color:[colorWell color]
                                   pointSize:[sizeText doubleValue] date:[NSDate date] mode:mode backgroundColor:backgroundColor];
}
//end historyItemWithCurrentState

-(BOOL) applyPdfData:(NSData*)pdfData
{
  BOOL ok = NO;
  HistoryItem* historyItem = [HistoryItem historyItemWithPDFData:pdfData useDefaults:YES];
  if (historyItem)
  {
    ok = YES;
    [self applyHistoryItem:historyItem];
  }
  else
  {
    PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
    NSString* string = [pdfDocument string];
    ok = string && ![string isEqualToString:@""];
    if (ok)
      [self applyString:string];
    [pdfDocument release];
  }
  return ok;
}
//end applyPdfData:

-(void) applyString:(NSString*)string
{
  NSString* preamble = nil;
  NSString* body     = nil;
  [self _decomposeString:string preamble:&preamble body:&body];
  if (preamble)
    [self setPreamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]];
  if (body)
    [self setSourceText:[[[NSAttributedString alloc] initWithString:body] autorelease]];
}
//end applyString:

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

    NSParagraphStyle* paragraphStyle = [preambleTextView defaultParagraphStyle];
    [self setPreamble:[historyItem preamble]];
    [self setSourceText:[historyItem sourceText]];
    [[preambleTextView textStorage] addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [[preambleTextView textStorage] length])];
    [[sourceTextView textStorage]   addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [[sourceTextView textStorage] length])];

    [colorWell setColor:[historyItem color]];
    [sizeText setDoubleValue:[historyItem pointSize]];
    [typeOfTextControl selectSegmentWithTag:[historyItem mode]];
    NSColor* historyItemBackgroundColor = [historyItem backgroundColor];
    NSColor* greyLevelHistoryItemBackgroundColor = historyItemBackgroundColor ? [historyItemBackgroundColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] : [NSColor whiteColor];
    historyItemBackgroundColor = ([greyLevelHistoryItemBackgroundColor whiteComponent] == 1.0f) ? nil : historyItemBackgroundColor;
    NSColor* colorFromUserDefaults = [NSColor colorWithData:[[NSUserDefaults standardUserDefaults] dataForKey:DefaultImageViewBackgroundKey]];
    if (!historyItemBackgroundColor)
      historyItemBackgroundColor = colorFromUserDefaults;
    //at this step, the background color to be used is either the history item (if any) or the default one
    //but if the background must be contrasted, we must take it in account
    if ([[NSUserDefaults standardUserDefaults] boolForKey:DefaultAutomaticHighContrastedPreviewBackgroundKey])
    {
      float grayLevelOfBackgroundColorToApply = [historyItemBackgroundColor grayLevel];
      float grayLevelOfTextColor              = [[historyItem color] grayLevel];
      if ((grayLevelOfBackgroundColorToApply < .5) && (grayLevelOfTextColor < .5))
        historyItemBackgroundColor = [NSColor whiteColor];
      else if ((grayLevelOfBackgroundColorToApply > .5) && (grayLevelOfTextColor > .5))
        historyItemBackgroundColor = [NSColor blackColor];
    }
    [imageView setBackgroundColor:historyItemBackgroundColor updateHistoryItem:NO];
  }
  else
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [self _setLogTableViewVisible:NO];
    [imageView setPDFData:nil cachedImage:nil];
    NSFont* defaultFont = [NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]];

    NSParagraphStyle* paragraphStyle = [preambleTextView defaultParagraphStyle];
    [[preambleTextView textStorage] addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [[preambleTextView textStorage] length])];
    [[sourceTextView textStorage]   addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [[sourceTextView textStorage] length])];

    NSMutableDictionary* typingAttributes = [NSMutableDictionary dictionaryWithDictionary:[preambleTextView typingAttributes]];
    [typingAttributes setObject:defaultFont forKey:NSFontAttributeName];
    [preambleTextView setTypingAttributes:typingAttributes];
    [sourceTextView   setTypingAttributes:typingAttributes];
    [self setPreamble:[[AppController appController] preambleForLatexisation]];
    [self setSourceText:[[[NSAttributedString alloc ] init] autorelease]];
    [[preambleTextView textStorage] addAttributes:typingAttributes range:NSMakeRange(0, [[preambleTextView textStorage] length])];
    [[sourceTextView textStorage]   addAttributes:typingAttributes range:NSMakeRange(0, [[sourceTextView textStorage] length])];
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
  if ([sender menu] == [[changePreambleButton cell] menu])
    ok = ([sender action] != nil) && ([sender action] != @selector(nullAction:));
  else if ([sender tag] == EXPORT_FORMAT_EPS)
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
  NSString* directory = nil;
  NSString* file = NSLocalizedString(@"Untitled", @"Untitled");
  NSString* currentFilePath = [[self fileURL] path];
  if (currentFilePath)
  {
    directory = [currentFilePath stringByDeletingLastPathComponent];
    file = [currentFilePath lastPathComponent];
  }
  [currentSavePanel beginSheetForDirectory:directory file:file
                            modalForWindow:[self windowForSheet] modalDelegate:self
                            didEndSelector:@selector(exportChooseFileDidEnd:returnCode:contextInfo:)
                               contextInfo:NULL];
}

-(BOOL) canReexport
{
  return [[self fileURL] path] && [imageView image];
}
//end canReexport

//asks for a filename and format to export
-(IBAction) reexportImage:(id)sender
{
  if (![self canReexport])
    [self exportImage:sender];
  else
  {
    //first, disables PDF_NOT_EMBEDDED_FONTS if needed
    if (([saveAccessoryViewPopupFormat selectedTag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) &&
        (![[AppController appController] isGsAvailable] || ![[AppController appController] isPs2PdfAvailable]))
      [saveAccessoryViewPopupFormat selectItemWithTag:EXPORT_FORMAT_PDF];
    [self exportImageWithData:[imageView pdfData] format:[saveAccessoryViewPopupFormat selectedTag]
               scaleAsPercent:[saveAccessoryViewScaleAsPercentTextField floatValue] jpegColor:[jpegColorWell color]
                  jpegQuality:jpegQuality filePath:[[self fileURL] path]];
  }//end if ([can reexport])
}
//end reexportImage:

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
    [self exportImageWithData:[imageView pdfData] format:[saveAccessoryViewPopupFormat selectedTag]
               scaleAsPercent:[saveAccessoryViewScaleAsPercentTextField floatValue]
                    jpegColor:[jpegColorWell color] jpegQuality:jpegQuality filePath:[sheet filename]];
  }//end if save
  currentSavePanel = nil;
}
//end exportChooseFileDidEnd:returnCode:contextInfo:

-(void) exportImageWithData:(NSData*)pdfData format:(export_format_t)format scaleAsPercent:(float)scaleAsPercent
                  jpegColor:(NSColor*)aJpegColor jpegQuality:(float)aJpegQuality filePath:(NSString*)filePath
{
  NSData* data = [[AppController appController] dataForType:format pdfData:pdfData jpegColor:aJpegColor
                                                jpegQuality:aJpegQuality/100 scaleAsPercent:scaleAsPercent];
  if (data)
  {
    [data writeToFile:filePath atomically:YES];
    [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt']
                                                  forKey:NSFileHFSCreatorCode] atPath:filePath];    
    unsigned int options = 0;
    #ifndef PANTHER
    options = NSExclude10_4ElementsIconCreationOption;
    #endif
    NSColor* backgroundColor = (format == EXPORT_FORMAT_JPEG) ? aJpegColor : nil;
    [[NSWorkspace sharedWorkspace] setIcon:[LatexProcessor makeIconForData:pdfData backgroundColor:backgroundColor]
                                   forFile:filePath options:options];
  }//end if save
}
//end exportImageWithData:format:scaleAsPercent:jpegColor:jpegQuality:filePath:

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

    SystemTask* task = [[[SystemTask alloc] initWithWorkingDirectory:[AppController latexitTemporaryPath]] autorelease];
    [task setUsingLoginShell:[[NSUserDefaults standardUserDefaults] boolForKey:UseLoginShellKey]];
    [task setCurrentDirectoryPath:directory];
    [task setEnvironment:environment];
    [task setLaunchPath:scriptShell];
    [task setArguments:[NSArray arrayWithObjects:@"-c", latexScriptPath, nil]];
    [task setCurrentDirectoryPath:[latexScriptPath stringByDeletingLastPathComponent]];

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
        NSString* outputLog = [[[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding] autorelease];
        [logString appendFormat:@"%@\n----------------------------------------------------\n", outputLog];
      }
      else
      {
        NSString* outputLog = [[[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding] autorelease];
        [logString appendFormat:@"\n%@\n----------------------------------------------------\n", outputLog];
      }
    }//end try task
    @catch(NSException* e) {
        [logString appendFormat:@"\n%@ :\n", NSLocalizedString(@"Script failed", @"Script failed")];
        NSString* outputLog = [[[NSString alloc] initWithData:[task dataForStdOutput] encoding:encoding] autorelease];
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

-(BOOL) isReducedTextArea
{
  return isReducedTextArea;
}
//end isReducedTextArea

-(void) setReducedTextArea:(BOOL)reduce
{
  if ((reduce != isReducedTextArea) && upperBox && lowerBox)
  {
    NSRect oldUpFrame  = [upperBox frame];
    NSRect oldLowFrame = [lowerBox frame];
    float margin = reduce ? [splitView frame].size.height/2 : -[splitView frame].size.height;
    NSRect newUpFrame  = NSMakeRect(oldUpFrame.origin.x, oldUpFrame.origin.y-margin, oldUpFrame.size.width, oldUpFrame.size.height+margin);
    NSRect newLowFrame = NSMakeRect(oldLowFrame.origin.x, oldLowFrame.origin.y, oldLowFrame.size.width, oldLowFrame.size.height-margin);
    #ifdef PANTHER
    [upperBox setFrame:newUpFrame];
    [lowerBox setFrame:newLowFrame];
    #else
    NSViewAnimation* viewAnimation =
      [[[NSViewAnimation alloc] initWithViewAnimations:
        [NSArray arrayWithObjects:
          [NSDictionary dictionaryWithObjectsAndKeys:upperBox, NSViewAnimationTargetKey,
                                                     [NSValue valueWithRect:oldUpFrame], NSViewAnimationStartFrameKey,
                                                     [NSValue valueWithRect:newUpFrame], NSViewAnimationEndFrameKey,
                                                     nil],
          [NSDictionary dictionaryWithObjectsAndKeys:lowerBox, NSViewAnimationTargetKey,
                                                     [NSValue valueWithRect:oldLowFrame], NSViewAnimationStartFrameKey,
                                                     [NSValue valueWithRect:newLowFrame], NSViewAnimationEndFrameKey,
                                                     nil],
          nil]] autorelease];
    [viewAnimation setDuration:.5];
    [viewAnimation setAnimationBlockingMode:NSAnimationNonblocking];
    [viewAnimation startAnimation];
    #endif
    isReducedTextArea = reduce;
  }
}
//setReducedTextAreaState:

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
  [changePreambleButton setHidden:![self isPreambleVisible] ||
                                  ([[preambleTextView superview] frame].size.height < [changePreambleButton frame].size.height)];
}
//end splitViewDidResizeSubviews:

-(void) popUpButtonWillPopUp:(NSNotification*)notification
{
  NSPopUpButtonCell* changePreambleButtonCell = [changePreambleButton cell];
  if ([notification object] == changePreambleButtonCell)
  {
    [changePreambleButtonCell removeAllItems];
    NSMenu* menu = [changePreambleButtonCell menu];
    [menu addItemWithTitle:@"" action:@selector(nullAction:) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Preambles", @"Preambles") action:@selector(nullAction:) keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    NSArray* preambles = [[PreferencesController sharedController] preambles];
    NSEnumerator* enumerator = [preambles objectEnumerator];
    NSDictionary* preamble = nil;
    while((preamble = [enumerator nextObject]))
      [[menu addItemWithTitle:[preamble objectForKey:@"name"] action:@selector(changePreamble:) keyEquivalent:@""] setRepresentedObject:preamble];
    [menu setDelegate:self];
  }
}

-(IBAction) changePreamble:(id)sender
{
  NSDictionary* preamble = [sender representedObject];
  if (preamble)
    [self setPreamble:[preamble objectForKey:@"value"]];
}
//end changePreamble:

-(IBAction) nullAction:(id)sender
{
}
//end nullAction:

@end
