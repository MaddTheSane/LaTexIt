//  MyDocument.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.

// The main document of LaTeXiT. There is much to say !

#import "MyDocument.h"

#import "AdditionalFilesWindowController.h"
#import "AppController.h"
#import "CGPDFExtras.h"
#import "DocumentExtraPanelsController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "ImagePopupButton.h"
#import "LatexitEquation.h"
#import "LaTeXProcessor.h"
#import "LibraryManager.h"
#import "LibraryEquation.h"
#import "LibraryWindowController.h"
#import "LineCountTextView.h"
#import "LogTableView.h"
#import "MyImageView.h"
#import "MySplitView.h"
#import "NotifyingScrollView.h"
#import "NSArrayExtended.h"
#import "NSColorExtended.h"
#import "NSDictionaryCompositionConfiguration.h"
#import "NSDictionaryExtended.h"
#import "NSFileManagerExtended.h"
#import "NSFontExtended.h"
#import "NSOutlineViewExtended.h"
#import "NSSegmentedControlExtended.h"
#import "NSStringExtended.h"
#import "NSTaskExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "NSViewExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "PreferencesWindowController.h"
#import "SMLSyntaxColouring.h"
#import "SystemTask.h"
#import "Utils.h"

#import <Carbon/Carbon.h>
#import <LinkBack/LinkBack.h>
#import <Quartz/Quartz.h>
#import "RegexKitLite.h"

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

-(DocumentExtraPanelsController*) lazyDocumentExtraPanelsController;

//updates the logTableView to report the errors
-(void) _analyzeErrors:(NSArray*)errors;

-(void) _lineCountDidChange:(NSNotification*)aNotification;
-(void) _clickErrorLine:(NSNotification*)aNotification;

-(void) _setLogTableViewVisible:(BOOL)status;

-(NSImage*) _checkEasterEgg;//may return an easter egg image

-(void) closeSheetDidEnd:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;//for doc closing

-(NSString*) descriptionForScript:(NSDictionary*)script;
-(void) _decomposeString:(NSString*)string preamble:(NSString**)preamble body:(NSString**)body;

-(void) exportImageWithData:(NSData*)pdfData format:(export_format_t)exportFormat scaleAsPercent:(CGFloat)scaleAsPercent
                  jpegColor:(NSColor*)jpegColor jpegQuality:(CGFloat)jpegQuality filePath:(NSString*)filePath;
                  
-(void) latexizeCoreRunWithConfiguration:(NSDictionary*)configuration;
-(void) removeObsoleteFiles;
-(void) applicationWillTerminate:(NSNotification*)notification;

-(void) selectLibraryItemForCurrentLinkedEquation:(id)sender;
@end

@interface MyDocumentWindow : NSWindow
@end
@implementation MyDocumentWindow
-(void)toggleToolbarShown:(id)sender
{
  [(MyDocument*)[[self windowController] document] toggleDocumentStyle];
}
@end

@interface MyDocumentPanel : NSPanel
@end
@implementation MyDocumentPanel
-(void)toggleToolbarShown:(id)sender
{
  [(MyDocument*)[[self windowController] document] toggleDocumentStyle];
}
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
//end _giveId

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
  if ((!(self = [super init])))
    return nil;
  self->uniqueId = [MyDocument _giveId];
  self->lastExecutionLog = [[NSMutableString alloc] init];
  self->poolOfObsoleteUniqueIds = [[NSMutableArray alloc] init];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(waitLatexizationDidEnd:)
                                               name:LatexizationDidEndNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                               name:NSApplicationWillTerminateNotification object:nil];
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [MyDocument _releaseId:self->uniqueId];
  [self->documentExtraPanelsController release];
  [self closeLinkBackLink:self->linkBackLink];
  [self closeLinkedLibraryEquation:self->linkedLibraryEquation];
  [self->upperBoxProgressIndicator release];
  [self->lastAppliedLibraryEquation release];
  [self->lastExecutionLog release];
  [self->lastRequestedBodyTemplate release];
  [self->poolOfObsoleteUniqueIds release];
  [self->busyIdentifier release];
  [self->initialUTI release];
  [self->initialData release];
  [self->initialBody release];
  [self->initialPreamble release];
  [super dealloc];
}
//end dealloc

-(void) close
{
  @synchronized(self)
  {
    if (self->nbBackgroundLatexizations > 0)
    {
      self->isClosed = YES;
      [self retain];
    }//end if (self->nbBackgroundLatexizations > 0)
  }
  [super close];
}
//end close

-(DocumentExtraPanelsController*) lazyDocumentExtraPanelsController
{
  DocumentExtraPanelsController* result = self->documentExtraPanelsController;
  if (!result)
  {
    self->documentExtraPanelsController = [[DocumentExtraPanelsController alloc] initWithLoadingFromNib];
    result = self->documentExtraPanelsController;
  }//end if (!result)
  return result;
}
//end lazyDocumentExtraPanelsController

-(void) setNullId//useful for dummy document of AppController
{
  [MyDocument _releaseId:self->uniqueId];
  self->uniqueId = 0;
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

-(void) windowControllerDidLoadNib:(NSWindowController*)aController
{
  [super windowControllerDidLoadNib:aController];
  
  NSWindow* window = [self windowForSheet];
  
  [window setDelegate:(id)self];
  [window setFrameAutosaveName:[NSString stringWithFormat:@"LaTeXiT-window-%u", uniqueId]];
  [window setTitle:[self displayName]];
  self->lowerBoxControlsBoxLatexModeSegmentedControlMinimumSize = [self->lowerBoxControlsBoxLatexModeSegmentedControl frame].size;
  self->documentNormalMinimumSize = [window minSize];
  self->documentMiniMinimumSize = NSMakeSize(320, 150);
  self->documentFrameSaved = [window frame];
  
  PreferencesController* preferencesController = [PreferencesController sharedController];
  [[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] setTag:LATEX_MODE_ALIGN   forSegment:0];
  [[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] setTag:LATEX_MODE_DISPLAY forSegment:1];
  [[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] setTag:LATEX_MODE_INLINE  forSegment:2];
  [[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] setTag:LATEX_MODE_TEXT    forSegment:3];
  [[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] setLabel:NSLocalizedString(@"Align", @"Align") forSegment:0];
  [[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] setLabel:NSLocalizedString(@"Text", @"Text") forSegment:3];
  [self->lowerBoxControlsBoxLatexModeSegmentedControl selectSegmentWithTag:[preferencesController latexisationLaTeXMode]];
  
  [self->lowerBoxControlsBoxFontSizeLabel setStringValue:NSLocalizedString(@"Font size :", @"Font size :")];
  [self->lowerBoxControlsBoxFontSizeTextField setDoubleValue:[preferencesController latexisationFontSize]];

  [self->lowerBoxControlsBoxFontColorLabel setStringValue:NSLocalizedString(@"Color :", @"Color :")];
  NSColor* initialColor = [[AppController appController] isColorStyAvailable] ?
                              [preferencesController latexisationFontColor] : [NSColor blackColor];
  [self->lowerBoxControlsBoxFontColorWell setColor:initialColor];
  
  [self->lowerBoxLatexizeButton setTitle:NSLocalizedString(@"LaTeX it!", @"LaTeX it!")];

  NSFont* defaultFont = [preferencesController editionFont];
  NSMutableDictionary* typingAttributes = [NSMutableDictionary dictionaryWithDictionary:[self->lowerBoxPreambleTextView typingAttributes]];
  [typingAttributes setObject:defaultFont forKey:NSFontAttributeName];
  [self->lowerBoxPreambleTextView setTypingAttributes:typingAttributes];
  [self->lowerBoxSourceTextView   setTypingAttributes:typingAttributes];

  [self bind:@"reducedTextArea" toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:ReducedTextAreaStateKey] options:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:window];

  self->documentStyle = DOCUMENT_STYLE_UNDEFINED;//will force change
  document_style_t preferredDocumentStyle = [preferencesController documentStyle];
  [self setDocumentStyle:DOCUMENT_STYLE_NORMAL];
  [self windowDidResize:nil];//force colorwell resize

  NSImage*  image = [NSImage imageNamed:@"button-menu"];
  [self->lowerBoxChangePreambleButton setImage:image];
  [self->lowerBoxChangePreambleButton setAlternateImage:image];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(popUpButtonWillPopUp:) name:NSPopUpButtonCellWillPopUpNotification object:[self->lowerBoxChangePreambleButton cell]];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(scrollViewDidScroll:) name:NotifyingScrollViewDidScrollNotification object:[[self->lowerBoxPreambleTextView superview] superview]];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(scrollViewDidScroll:) name:NotifyingScrollViewDidScrollNotification object:[[self->lowerBoxSourceTextView superview] superview]];
  [self->lowerBoxChangeBodyTemplateButton setImage:image];
  [self->lowerBoxChangeBodyTemplateButton setAlternateImage:image];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(popUpButtonWillPopUp:) name:NSPopUpButtonCellWillPopUpNotification object:[self->lowerBoxChangeBodyTemplateButton cell]];

  [self setReducedTextArea:[preferencesController documentIsReducedTextArea]];

  //to paste rich LaTeXiT data, we must tune the responder chain  
  [self->lowerBoxSourceTextView setNextResponder:self->upperBoxImageView];
  
  [[[self->upperBoxLogTableView tableColumnWithIdentifier:@"line"] headerCell]
    setStringValue:NSLocalizedString(@"line", @"line")];
  [[[self->upperBoxLogTableView tableColumnWithIdentifier:@"message"] headerCell]
    setStringValue:[NSLocalizedString(@"Error message", @"Error message") lowercaseString]];

  //useful to avoid conflicts between mouse clicks on imageView and the progressIndicator
  [self->upperBoxProgressIndicator setNextResponder:self->upperBoxImageView];
  [self->upperBoxProgressIndicator retain];
  [self->upperBoxProgressIndicator removeFromSuperview];
  
  [window makeKeyAndOrderFront:self];

  NSMutableParagraphStyle* paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
  NSArray* arrayOfTabs = [paragraphStyle tabStops];
  CGFloat defaultTabInterval =
    ([arrayOfTabs count] >= 2) ? [(NSTextTab*)[arrayOfTabs objectAtIndex:1] location]-[(NSTextTab*)[arrayOfTabs objectAtIndex:0] location] :
    [paragraphStyle defaultTabInterval];
  [paragraphStyle setDefaultTabInterval:defaultTabInterval];
  [paragraphStyle setTabStops:[NSArray array]];
  [self->lowerBoxPreambleTextView setDefaultParagraphStyle:paragraphStyle];
  [self->lowerBoxSourceTextView   setDefaultParagraphStyle:paragraphStyle];
  
  [self->upperBoxImageView setBackgroundColor:[preferencesController documentImageViewBackgroundColor] updateHistoryItem:NO];
  [self->upperBoxZoomBoxSlider bind:NSEnabledBinding toObject:self->upperBoxImageView withKeyPath:@"image" options:
    [NSDictionary dictionaryWithObjectsAndKeys:NSIsNotNilTransformerName, NSValueTransformerNameBindingOption, nil]];
  [self->upperBoxZoomBoxSlider bind:NSValueBinding toObject:self->upperBoxImageView withKeyPath:@"zoomLevel" options:
    [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSContinuouslyUpdatesValueBindingOption, nil]];

  //the initial... variables has been set into a readFromFile
  if (self->initialPreamble)
  {
    //try to insert usepackage{color} inside the preamble
    [self setPreamble:[[[NSAttributedString alloc] initWithString:self->initialPreamble] autorelease]];
    [self->initialPreamble release];
    self->initialPreamble = nil;
  }//end if (self->initialPreamble)
  else//if (!self->initialPreamble)
  {
    [self->lowerBoxPreambleTextView setForbiddenLine:0 forbidden:YES];
    [self->lowerBoxPreambleTextView setForbiddenLine:1 forbidden:YES];
    [self setPreamble:[[AppController appController] preambleLatexisationAttributedString]];
  }//end if (!self->initialPreamble)
  
  if (self->initialBody)
  {
    [self->lowerBoxControlsBoxLatexModeSegmentedControl setSelectedSegment:[[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] tagForSegment:LATEX_MODE_TEXT]];
    [self setSourceText:[[[NSAttributedString alloc] initWithString:self->initialBody] autorelease]];
    [self->initialBody release];
    self->initialBody = nil;
  }//end if (self->initialBody)
  else//if (!self->initialBody)
  {
    [self setBodyTemplate:[[PreferencesController sharedController] bodyTemplateDocumentDictionary] moveCursor:YES];
  }//end if (!self->initialBody)
  
  if (self->initialData)
  {
    [self applyData:self->initialData sourceUTI:self->initialUTI];
    [self->initialData release];
    self->initialData = nil;
    [self->initialUTI release];
    self->initialUTI = nil;
  }//end if (self->initialData)

  [self updateGUIfromSystemAvailabilities]; //updates interface to allow latexisation or not, according to current configuration

  [self _lineCountDidChange:nil];//to "shift" the line counter of sourceTextView
  NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
  [notificationCenter addObserver:self selector:@selector(_lineCountDidChange:)  name:LineCountDidChangeNotification object:self->lowerBoxPreambleTextView];
  [notificationCenter addObserver:self selector:@selector(_clickErrorLine:)      name:ClickErrorLineNotification object:self->upperBoxLogTableView];

  [self splitViewDidResizeSubviews:nil];  
  [window makeFirstResponder:[self preferredFirstResponder]];
  [self setDocumentStyle:preferredDocumentStyle];
}
//end windowControllerDidLoadNib:

-(void) windowDidResize:(NSNotification*)notification
{
  if (self->documentStyle == DOCUMENT_STYLE_NORMAL)
  {
    NSRect colorWellFrame = [self->lowerBoxControlsBoxFontColorWell frame];
    colorWellFrame.size.width = MIN(52, [self->lowerBoxLatexizeButton frame].origin.x-4-colorWellFrame.origin.x);
    [self->lowerBoxControlsBoxFontColorWell setFrame:colorWellFrame];
  }//end if (self->documentStyle == DOCUMENT_STYLE_NORMAL)
}
//end windowDidResize:

-(MyImageView*) imageView                {return self->upperBoxImageView;}
-(NSButton*)    lowerBoxLatexizeButton   {return self->lowerBoxLatexizeButton;}
-(NSResponder*) preferredFirstResponder  {return self->lowerBoxSourceTextView;}
-(NSResponder*) previousFirstResponder
{
  NSResponder* result = self->lastFirstResponder;
  if (!result)
    result = [self preferredFirstResponder];
  if (!result)
    result = [[self windowForSheet] initialFirstResponder];
  return result;
}
//end previousFirstResponder

//set the document title that will be displayed as window title. There is no represented file associated
-(void) setDocumentTitle:(NSString*)title
{
  [title retain];
  [self->documentTitle release];
  self->documentTitle = title;
  [[[self windowForSheet] windowController] synchronizeWindowTitleWithDocumentName];
}
//end setDocumentTitle:

-(document_style_t) documentStyle
{
  return self->documentStyle;
}
//end documentStyle

-(void) setDocumentStyle:(document_style_t)value
{
  if (value != self->documentStyle)
  {
    document_style_t oldValue = self->documentStyle;
    self->documentStyle = value;
    NSWindow* window = [self windowForSheet];
    if (self->documentStyle == DOCUMENT_STYLE_MINI)
    {
      NSRect previousFrame = [window frame];
      NSRect nextFrame     = previousFrame;
      self->documentFrameSaved = previousFrame;      
      nextFrame.size = self->documentMiniMinimumSize;
      nextFrame.origin.y = previousFrame.origin.y+previousFrame.size.height-nextFrame.size.height;
      [window setShowsResizeIndicator:NO];
      [window setMinSize:self->documentMiniMinimumSize];
      [window setFrame:nextFrame display:YES animate:[window isVisible]];
      NSRect newLowerBoxFrame = [self->lowerBox frame];
      newLowerBoxFrame.size.height = [self->upperBox frame].origin.y-4;
      [self->lowerBox setFrame:newLowerBoxFrame];

      NSRect superviewFrame = [[self->upperImageBox superview] frame];
      NSRect zoomBoxFrame = [self->upperBoxZoomBox frame];
      [self->upperImageBox setFrame:NSMakeRect(0, 0, superviewFrame.size.width-zoomBoxFrame.size.width, superviewFrame.size.height)];
      [self->upperBoxZoomBox  setFrame:NSMakeRect(superviewFrame.size.width-zoomBoxFrame.size.width, 0, zoomBoxFrame.size.width, superviewFrame.size.height)];
      
      [[((NSScrollView*)[[self->upperBoxLogTableView superview] superview]) horizontalScroller] setControlSize:NSMiniControlSize];
      [[((NSScrollView*)[[self->upperBoxLogTableView superview] superview]) verticalScroller]   setControlSize:NSMiniControlSize];

      superviewFrame = [self->lowerBox frame];
      [self->lowerBoxSplitView setFrame:NSMakeRect(0,  34, superviewFrame.size.width, superviewFrame.size.height-34)];
      [self->lowerBoxSplitView setDividerThickness:0.];
      NSScrollView* sourceTextScrollView = (NSScrollView*)[[self->lowerBoxSourceTextView superview] superview];
      [[sourceTextScrollView  horizontalScroller] setControlSize:NSMiniControlSize];
      [[sourceTextScrollView  verticalScroller]   setControlSize:NSMiniControlSize];
      [self->lowerBoxChangePreambleButton setFrameOrigin:NSMakePoint(0, superviewFrame.size.height-[self->lowerBoxChangePreambleButton frame].size.height)];
      [self->lowerBoxControlsBox setFrame:NSMakeRect(0,  0, superviewFrame.size.width, 34)];

      superviewFrame = [self->lowerBoxControlsBox frame];
      [[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] setControlSize:NSMiniControlSize];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl sizeToFitWithSegmentWidth:(superviewFrame.size.width-8)/[self->lowerBoxControlsBoxLatexModeSegmentedControl segmentCount] useSameSize:YES];
      NSRect lowerBoxControlsBoxLatexModeSegmentedControlFrame = NSMakeRect(0, 18, superviewFrame.size.width, 16);
      [self->lowerBoxControlsBoxLatexModeSegmentedControl setFrame:lowerBoxControlsBoxLatexModeSegmentedControlFrame];
      [[self->lowerBoxControlsBoxFontSizeLabel cell] setControlSize:NSMiniControlSize];
      [self->lowerBoxControlsBoxFontSizeLabel setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
      [self->lowerBoxControlsBoxFontSizeLabel sizeToFit];
      [[self->lowerBoxControlsBoxFontSizeTextField cell] setControlSize:NSMiniControlSize];
      [self->lowerBoxControlsBoxFontSizeTextField setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
      [self->lowerBoxControlsBoxFontSizeTextField sizeToFit];
      [self->lowerBoxControlsBoxFontSizeLabel setFrameOrigin:NSMakePoint(0, ([self->lowerBoxControlsBoxFontSizeTextField frame].size.height-[self->lowerBoxControlsBoxFontSizeLabel frame].size.height)/2)];
      [self->lowerBoxControlsBoxFontSizeTextField setFrameOrigin:NSMakePoint(NSMaxX([self->lowerBoxControlsBoxFontSizeLabel frame])+2, 0)];
      [[self->lowerBoxControlsBoxFontColorLabel cell] setControlSize:NSMiniControlSize];
      [self->lowerBoxControlsBoxFontColorLabel setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
      [self->lowerBoxControlsBoxFontColorLabel sizeToFit];
      [[self->lowerBoxControlsBoxFontColorWell cell] setControlSize:NSMiniControlSize];
      [self->lowerBoxControlsBoxFontColorWell setFrame:NSRectChange([self->lowerBoxControlsBoxFontColorWell frame], NO, 0, YES, 0, YES, 2*[self->lowerBoxControlsBoxFontSizeTextField frame].size.height, YES, [self->lowerBoxControlsBoxFontSizeTextField frame].size.height)];
      [self->lowerBoxControlsBoxFontColorLabel setFrameOrigin:
        NSMakePoint(NSMaxX([self->lowerBoxControlsBoxFontSizeTextField frame])+2,
                    ([self->lowerBoxControlsBoxFontColorWell frame].size.height-[self->lowerBoxControlsBoxFontColorLabel frame].size.height)/2)];
      [self->lowerBoxControlsBoxFontColorWell setFrameOrigin:NSMakePoint(NSMaxX([self->lowerBoxControlsBoxFontColorLabel frame]), 0)];

      [[self->lowerBoxLatexizeButton cell] setControlSize:NSMiniControlSize];
      [self->lowerBoxLatexizeButton setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]]];
      [self->lowerBoxLatexizeButton sizeToFit];
      NSRect lowerBoxLatexizeButtonFrame = [self->lowerBoxLatexizeButton frame];
      [self->lowerBoxLatexizeButton setFrame:NSMakeRect(superviewFrame.size.width-lowerBoxLatexizeButtonFrame.size.width,
                                                 ([self->lowerBoxControlsBoxFontColorWell frame].size.height-lowerBoxLatexizeButtonFrame.size.height)/2,
                                                 lowerBoxLatexizeButtonFrame.size.width, lowerBoxLatexizeButtonFrame.size.height)];
      NSPanel* miniWindow =
        [[MyDocumentPanel alloc] initWithContentRect:[[window contentView] frame]
                                   styleMask:NSTitledWindowMask|NSUtilityWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask
                                     backing:NSBackingStoreBuffered defer:NO];
      [miniWindow setReleasedWhenClosed:YES];
      [miniWindow setDelegate:(id)self];
      [miniWindow setFrameAutosaveName:[NSString stringWithFormat:@"LaTeXiT-window-%u", uniqueId]];
      [miniWindow setFrame:[window frame] display:YES];
      [miniWindow setShowsResizeIndicator:NO];
      [miniWindow setMinSize:self->documentMiniMinimumSize];
      [miniWindow setMaxSize:self->documentMiniMinimumSize];
      [miniWindow setTitle:[self displayName]];
      NSArray* subViews = [NSArray arrayWithArray:[[window contentView] subviews]];
      NSEnumerator* enumerator = [subViews objectEnumerator];
      NSView* view = nil;
      while((view = [enumerator nextObject]))
      {
        [view retain];
        [view removeFromSuperview];
        [[miniWindow contentView] addSubview:view];
        [view release];
      }
      NSWindowController* windowController = [window windowController];
      [self retain];
      [window retain];
      [windowController setWindow:miniWindow];
      [windowController setDocument:self];
      [self release];
      [miniWindow setWindowController:windowController];
      [miniWindow makeKeyAndOrderFront:nil];
      [window close];
      [window release];
    }//end if (self->documentStyle == DOCUMENT_STYLE_MINI)
    else//if (self->documentStyle == DOCUMENT_STYLE_NORMAL)
    {
      NSRect superviewFrame = NSZeroRect;
      NSRect nextFrame      = self->documentFrameSaved;
      if (oldValue != DOCUMENT_STYLE_UNDEFINED)
      {
        NSRect previousFrame = [window frame];
        nextFrame.origin.y = previousFrame.origin.y+previousFrame.size.height-nextFrame.size.height;
        [window setShowsResizeIndicator:YES];
        [window setMinSize:self->documentNormalMinimumSize];
        [window setFrame:nextFrame display:YES animate:[window isVisible]];
        NSRect newLowerBoxFrame = [self->lowerBox frame];
        newLowerBoxFrame.size.height = [self->upperBox frame].origin.y-4;
        [self->lowerBox setFrame:newLowerBoxFrame];

        superviewFrame = [[self->upperImageBox superview] frame];
        NSRect zoomBoxFrame = [self->upperBoxZoomBox frame];
        [self->upperImageBox setFrame:NSMakeRect(20, 0, superviewFrame.size.width-20-zoomBoxFrame.size.width, superviewFrame.size.height-16)];
        [self->upperBoxZoomBox  setFrame:NSMakeRect(superviewFrame.size.width-zoomBoxFrame.size.width, 0, zoomBoxFrame.size.width, superviewFrame.size.height-16)];
        
        [[((NSScrollView*)[[self->upperBoxLogTableView superview] superview]) horizontalScroller] setControlSize:NSRegularControlSize];
        [[((NSScrollView*)[[self->upperBoxLogTableView superview] superview]) verticalScroller]   setControlSize:NSRegularControlSize];

        superviewFrame = [self->lowerBox frame];
        NSScrollView* sourceTextScrollView = (NSScrollView*)[[self->lowerBoxSourceTextView superview] superview];
        [self->lowerBoxSplitView setFrame:NSMakeRect(20,  80, superviewFrame.size.width-40, superviewFrame.size.height-80)];
        [self->lowerBoxSplitView setDividerThickness:-1];
        [[sourceTextScrollView  horizontalScroller] setControlSize:NSRegularControlSize];
        [[sourceTextScrollView  verticalScroller]   setControlSize:NSRegularControlSize];
        superviewFrame = [self->lowerBoxSplitView frame];
        [sourceTextScrollView setFrame:NSMakeRect(0, 0, superviewFrame.size.width, superviewFrame.size.height)];
        superviewFrame = [self->lowerBox frame];
        [self->lowerBoxChangePreambleButton setFrameOrigin:NSMakePoint(20, superviewFrame.size.height-[self->lowerBoxChangePreambleButton frame].size.height)];
        [self->lowerBoxSplitView setFrame:NSMakeRect(20, 80, superviewFrame.size.width-2*20, superviewFrame.size.height-80)];
        [self setPreambleVisible:NO animate:NO];
        [self->lowerBoxSplitView setHidden:NO];
        [self->lowerBoxControlsBox setFrame:NSMakeRect(0,  0, superviewFrame.size.width, 80)];
      }//end if (oldValue != DOCUMENT_STYLE_UNDEFINED)

      superviewFrame = [self->lowerBoxControlsBox frame];
      [[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] setControlSize:NSRegularControlSize];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]]];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl sizeToFitWithSegmentWidth:(self->lowerBoxControlsBoxLatexModeSegmentedControlMinimumSize.width-8)/[self->lowerBoxControlsBoxLatexModeSegmentedControl segmentCount] useSameSize:YES];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl setFrame:NSMakeRect(0, 48, [self->lowerBoxSplitView frame].size.width, 24)];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl setFrameSize:self->lowerBoxControlsBoxLatexModeSegmentedControlMinimumSize];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl centerInSuperviewHorizontally:YES vertically:NO];
      [[self->lowerBoxControlsBoxFontSizeLabel cell] setControlSize:NSRegularControlSize];
      [self->lowerBoxControlsBoxFontSizeLabel setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]]];
      [self->lowerBoxControlsBoxFontSizeLabel sizeToFit];
      [[self->lowerBoxControlsBoxFontSizeTextField cell] setControlSize:NSRegularControlSize];
      [self->lowerBoxControlsBoxFontSizeTextField setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]]];
      [self->lowerBoxControlsBoxFontSizeTextField sizeToFit];
      [self->lowerBoxControlsBoxFontSizeLabel setFrameOrigin:NSMakePoint(20, 15)];
      [self->lowerBoxControlsBoxFontSizeTextField setFrameOrigin:NSMakePoint(NSMaxX([self->lowerBoxControlsBoxFontSizeLabel frame])+4, 12)];
      [[self->lowerBoxControlsBoxFontColorLabel cell] setControlSize:NSRegularControlSize];
      [self->lowerBoxControlsBoxFontColorLabel setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]]];
      [self->lowerBoxControlsBoxFontColorLabel sizeToFit];
      [[self->lowerBoxControlsBoxFontColorWell cell] setControlSize:NSRegularControlSize];
      [self->lowerBoxControlsBoxFontColorLabel setFrameOrigin:NSMakePoint(NSMaxX([self->lowerBoxControlsBoxFontSizeTextField frame])+10, 15)];
      [self->lowerBoxControlsBoxFontColorWell setFrame:NSMakeRect(NSMaxX([self->lowerBoxControlsBoxFontColorLabel frame])+4, 10, 52, 26)];

      [[self->lowerBoxLatexizeButton cell] setControlSize:NSRegularControlSize];
      [self->lowerBoxLatexizeButton setFont:[NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]]];
      [self->lowerBoxLatexizeButton sizeToFit];
      NSRect lowerBoxLatexizeButtonFrame = [self->lowerBoxLatexizeButton frame];
      [self->lowerBoxLatexizeButton setFrame:NSMakeRect(MAX(superviewFrame.size.width-18-lowerBoxLatexizeButtonFrame.size.width,
                                                            NSMaxX([self->lowerBoxControlsBoxLatexModeSegmentedControl frame])-
                                                            lowerBoxLatexizeButtonFrame.size.width), 5,
                                                        lowerBoxLatexizeButtonFrame.size.width, lowerBoxLatexizeButtonFrame.size.height)];
      if (oldValue != DOCUMENT_STYLE_UNDEFINED)
      {
        NSWindow* normalWindow =
          [[MyDocumentWindow alloc] initWithContentRect:[window frame]
                                     styleMask:NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask
                                       backing:NSBackingStoreBuffered defer:NO];
        [normalWindow setReleasedWhenClosed:YES];
        [normalWindow setDelegate:(id)self];
        [normalWindow setFrameAutosaveName:[NSString stringWithFormat:@"LaTeXiT-window-%u", uniqueId]];
        [normalWindow setFrame:[window frame] display:YES];
        [normalWindow setShowsResizeIndicator:YES];
        [normalWindow setMinSize:self->documentNormalMinimumSize];
        [normalWindow setTitle:[self displayName]];
        NSArray* subViews = [NSArray arrayWithArray:[[window contentView] subviews]];
        NSEnumerator* enumerator = [subViews objectEnumerator];
        NSView* view = nil;
        while((view = [enumerator nextObject]))
        {
          [view retain];
          [view removeFromSuperview];
          [[normalWindow contentView] addSubview:view];
          [view release];
        }
        NSWindowController* windowController = [window windowController];
        [self retain];
        [window retain];
        [windowController setWindow:normalWindow];
        [windowController setDocument:self];
        [self release];
        [normalWindow setWindowController:windowController];
        [normalWindow makeKeyAndOrderFront:nil];
        [window close];
        [window release];
      }//end if (oldValue != DOCUMENT_STYLE_UNDEFINED)
    }//end if (self->documentStyle == DOCUMENT_STYLE_NORMAL)
    
    NSToolbar* toolbar = [[[NSToolbar alloc] initWithIdentifier:@""] autorelease];
    [toolbar setDisplayMode:NSToolbarDisplayModeLabelOnly];
    [toolbar setSizeMode:NSToolbarSizeModeSmall];
    [toolbar setVisible:NO];
    [[self windowForSheet] setToolbar:toolbar];

    
    [[PreferencesController sharedController] setDocumentStyle:self->documentStyle];
  }//end if (value != self->documentStyle)
}
//end setDocumentStyle:

-(void) toggleDocumentStyle
{
  if (self->documentStyle == DOCUMENT_STYLE_NORMAL)
    [self setDocumentStyle:DOCUMENT_STYLE_MINI];
  else
    [self setDocumentStyle:DOCUMENT_STYLE_NORMAL];
}
//end toggleDocumentStyle

-(BOOL) windowShouldZoom:(NSWindow*)window toFrame:(NSRect)proposedFrame
{
  BOOL result = NO;
  if (![window isZoomed])
    self->unzoomedFrame = [window frame];
  else
    proposedFrame = self->unzoomedFrame;
  //OOL optionIsPressed = ((GetCurrentEventKeyModifiers() & optionKey) != 0);
  if (/*optionIsPressed &&*/ (self->documentStyle == DOCUMENT_STYLE_NORMAL))
    [self setDocumentStyle:DOCUMENT_STYLE_MINI];
  else if (self->documentStyle == DOCUMENT_STYLE_MINI)
    [self setDocumentStyle:DOCUMENT_STYLE_NORMAL];
  else
    result = YES;
  return result;
}
//end windowShouldZoom:toFrame:

-(void) scrollViewDidScroll:(NSNotification*)notification
{
  id sender = [notification object];
  if (sender == [[self->lowerBoxPreambleTextView superview] superview])
  {
    [[self->lowerBoxPreambleTextView lineCountRulerView] setNeedsDisplay:YES];
    [self->lowerBoxChangePreambleButton setNeedsDisplay:YES];
  }
  else if (sender == [[self->lowerBoxSourceTextView superview] superview])
  {
    [[self->lowerBoxSourceTextView lineCountRulerView] setNeedsDisplay:YES];
    [self->lowerBoxChangeBodyTemplateButton setNeedsDisplay:YES];
  }
}
//end scrollViewDidScroll:

//automatically called by Cocoa. The name of the document has nothing to do with a represented file
-(NSString*) displayName
{
  NSString* title = documentTitle;
  if ([self fileURL])
    title = [super displayName];
  else if (!title)
    title = [NSString stringWithFormat:@"%@-%u", [[NSWorkspace sharedWorkspace] applicationName], uniqueId];
  return title;
}
//end displayName

//updates interface to allow latexisation or not, according to current configuration
-(void) updateGUIfromSystemAvailabilities
{
  AppController* appController = [AppController appController];
  composition_mode_t compositionMode = [[[PreferencesController sharedController] compositionConfigurationDocument] compositionConfigurationCompositionMode];
  BOOL lowerBoxLatexizeButtonEnabled =
    (compositionMode == COMPOSITION_MODE_PDFLATEX) ? [appController isPdfLaTeXAvailable] && [appController isGsAvailable] :
    (compositionMode == COMPOSITION_MODE_XELATEX)  ? [appController isPdfLaTeXAvailable] && [appController isXeLaTeXAvailable] && [appController isGsAvailable] :
    (compositionMode == COMPOSITION_MODE_LATEXDVIPDF) ? [appController isLaTeXAvailable] && [appController isDviPdfAvailable] && [appController isGsAvailable] :
    NO;    
  [self->lowerBoxLatexizeButton setEnabled:lowerBoxLatexizeButtonEnabled];
  [self->lowerBoxLatexizeButton setNeedsDisplay:YES];
  if (lowerBoxLatexizeButtonEnabled)
    [self->lowerBoxLatexizeButton setToolTip:nil];
  else if (![self->lowerBoxLatexizeButton toolTip])
    [self->lowerBoxLatexizeButton setToolTip:
      NSLocalizedString(@"pdflatex, latex, dvipdf, xelatex or gs (depending to the current configuration) seems unavailable in your system. Please check their installation.",
                        @"pdflatex, latex, dvipdf, xelatex or gs (depending to the current configuration) seems unavailable in your system. Please check their installation.")];
  
  BOOL colorStyEnabled = [appController isColorStyAvailable];
  [self->lowerBoxControlsBoxFontColorWell setEnabled:colorStyEnabled];
  [self->lowerBoxControlsBoxFontColorWell setNeedsDisplay:YES];
  if (colorStyEnabled)
    [self->lowerBoxControlsBoxFontColorWell setToolTip:nil];
  else if (![self->lowerBoxControlsBoxFontColorWell toolTip])
    [self->lowerBoxControlsBoxFontColorWell setToolTip:
      NSLocalizedString(@"color.sty package seems not to be present in your LaTeX installation. "\
                        @"So, color font change is disabled.",
                        @"color.sty package seems not to be present in your LaTeX installation. "\
                        @"So, color font change is disabled.")];

  [[self windowForSheet] display];
}
//end updateGUIfromSystemAvailabilities

-(NSData*) dataRepresentationOfType:(NSString *)aType
{
  return nil;
}
//end dataRepresentationOfType:

//LaTeXiT can open documents
- (BOOL)readFromURL:(NSURL*)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
  BOOL ok = NO;
  if ([typeName isEqualToString:@"LatexPalette"])
  {
    [[AppController appController] installLatexPalette:absoluteURL];
    ok = YES;
  }//end if ([typeName isEqualToString:@"LatexPalette"])
  else//if (![typeName isEqualToString:@"LatexPalette"])
  {
    self->initialUTI = [[[NSFileManager defaultManager] UTIFromURL:absoluteURL] copy];
    NSError* error = nil;
    if (error)
      DebugLog(1, @"error : %@", error);
    if (UTTypeConformsTo((CFStringRef)self->initialUTI, CFSTR("public.rtf")))
    {
      NSData* data = [NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error];
      NSString* string = [[[[NSAttributedString alloc] initWithRTF:data documentAttributes:nil] autorelease] string];
      [self _decomposeString:string preamble:&self->initialPreamble body:&self->initialBody];
    }//end if (UTTypeConformsTo((CFStringRef)self->initialUTI, CFSTR("public.rtf")))
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, CFSTR("com.adobe.pdf")))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, CFSTR("public.tiff")))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, CFSTR("public.png")))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, CFSTR("public.jpeg")))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, CFSTR("public.html")))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, CFSTR("public.svg-image")))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else //by default, we suppose that it is a plain text file
    {
      NSStringEncoding encoding = NSMacOSRomanStringEncoding;
      NSError* error = nil;
      NSString* string = [NSString stringWithContentsOfFile:[absoluteURL path] guessEncoding:&encoding error:&error];
      if (error)
        [self presentError:error];
      [self _decomposeString:string preamble:&self->initialPreamble body:&self->initialBody];
    }//end if plain text
    ok = self->initialData || self->initialPreamble || self->initialBody;
  }//end if (![typeName isEqualToString:@"LatexPalette"])
  return ok;
}
//end readFromURL:ofType:error:

-(void) _decomposeString:(NSString*)string preamble:(NSString**)preamble body:(NSString**)body
{
  //if a text document is opened, try to split it into preamble+body
  if (string)
  {
    NSRange beginDocument = [string rangeOfString:@"\\begin{document}" options:NSCaseInsensitiveSearch];
    NSRange endDocument   = [string rangeOfString:@"\\end{document}" options:NSCaseInsensitiveSearch];
    *preamble = (beginDocument.location == NSNotFound) ? nil :
                   [[string substringWithRange:NSMakeRange(0, beginDocument.location)] copy];
    *body = (beginDocument.location == NSNotFound) ? [string copy] :
               (endDocument.location == NSNotFound) ?
                 [[string substringWithRange:
                    NSMakeRange(beginDocument.location+beginDocument.length,
                                [string length]-(beginDocument.location+beginDocument.length))] copy] :
                 [[string substringWithRange:
                    NSMakeRange(beginDocument.location+beginDocument.length,
                                endDocument.location-(beginDocument.location+beginDocument.length))] copy];
  }//end if string
}
//end _decomposeString:preamble:body:

//when the linecount changes in the preamble view, the numerotation must change in the body view
-(void) _lineCountDidChange:(NSNotification*)aNotification
{
  //registered only for preambleTextView
  [self->lowerBoxSourceTextView setLineShift:[[self->lowerBoxPreambleTextView lineRanges] count]];
}
//end _lineCountDidChange:

-(void) setFont:(NSFont*)font//changes the font of both preamble and sourceText views
{
  [[self->lowerBoxPreambleTextView textStorage] setFont:font];
  [[self->lowerBoxSourceTextView textStorage] setFont:font];
}
//end setFont:

-(void) setPreamble:(NSAttributedString*)aString
{
  [self->lowerBoxPreambleTextView clearErrors];
  [[self->lowerBoxPreambleTextView textStorage] setAttributedString:aString];
  [[self->lowerBoxPreambleTextView syntaxColouring] recolourCompleteDocument];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:self->lowerBoxPreambleTextView];
  [self->lowerBoxPreambleTextView setNeedsDisplay:YES];
}
//end setPreamble:

-(void) setSourceText:(NSAttributedString*)aString
{
  [self->lowerBoxSourceTextView clearErrors];
  [[self->lowerBoxSourceTextView textStorage] setAttributedString:aString];
  [[self->lowerBoxSourceTextView syntaxColouring] recolourCompleteDocument];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:self->lowerBoxSourceTextView];
  [self->lowerBoxSourceTextView setNeedsDisplay:YES];
}
//end setSourceText:

-(void) setBodyTemplate:(NSDictionary*)bodyTemplate moveCursor:(BOOL)moveCursor
{
  //get rid of previous bodyTemplate
  NSAttributedString* currentBody = [self->lowerBoxSourceTextView textStorage];
  id rawHead = [self->lastRequestedBodyTemplate objectForKey:@"head"];
  NSAttributedString* head = [rawHead isKindOfClass:[NSAttributedString class]] ? rawHead :
                             [rawHead isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawHead] :
                             nil;
  id rawTail = [self->lastRequestedBodyTemplate objectForKey:@"tail"];
  NSAttributedString* tail = [rawTail isKindOfClass:[NSAttributedString class]] ? rawTail :
                             [rawTail isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawTail] :
                             nil;
  NSString* currentBodyString = [currentBody string];
  NSString* headString = [head string];
  NSString* tailString = [tail string];
  NSString* regexString = [NSString stringWithFormat:@"^[\\s\\n]*\\Q%@\\E[\\s\\n]*(.*)[\\s\\n]*\\Q%@\\E[\\s\\n]*$", headString, tailString];
  NSError* error = nil;
  NSString* innerBody = [currentBodyString stringByMatching:regexString options:RKLMultiline|RKLDotAll inRange:NSMakeRange(0, [currentBodyString length])
                                                    capture:1 error:&error];
  currentBodyString = !innerBody ? currentBodyString : innerBody;

   //replace current body template
  [self->lastRequestedBodyTemplate release];
  self->lastRequestedBodyTemplate = [bodyTemplate deepCopy];

  rawHead = [self->lastRequestedBodyTemplate objectForKey:@"head"];
  head    = [rawHead isKindOfClass:[NSAttributedString class]] ? rawHead :
              [rawHead isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawHead] :
              nil;
  rawTail = [self->lastRequestedBodyTemplate objectForKey:@"tail"];
  tail    = [rawTail isKindOfClass:[NSAttributedString class]] ? rawTail :
               [rawTail isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawTail] :
               nil;
  headString = [head string];
  tailString = [tail string];
  NSString* trimmedHead = [headString trim];
  NSString* trimmedTail = [tailString trim];
  NSString* trimmedCurrentBody = [currentBodyString trim];
  NSMutableAttributedString* newBody = [[[NSMutableAttributedString alloc] init] autorelease];
  if (trimmedHead && ![trimmedCurrentBody startsWith:trimmedHead options:0])
    [newBody appendAttributedString:head];
  [newBody appendAttributedString:[[[NSAttributedString alloc] initWithString:trimmedCurrentBody] autorelease]];
  if (trimmedTail && ![trimmedCurrentBody endsWith:trimmedTail options:0])
    [newBody appendAttributedString:tail];
  
  NSMutableDictionary* typingAttributes = [NSMutableDictionary dictionaryWithDictionary:[self->lowerBoxPreambleTextView typingAttributes]];
  NSFont* defaultFont = [[PreferencesController sharedController] editionFont];
  [typingAttributes setObject:defaultFont forKey:NSFontAttributeName];
  [newBody addAttributes:typingAttributes range:NSMakeRange(0, [newBody length])];
  [self setSourceText:newBody];
  if (moveCursor)
    [self->lowerBoxSourceTextView setSelectedRange:NSMakeRange([headString length], 0)];
}
//end setBodyTemplate:moveCursor:

-(void) applicationWillTerminate:(NSNotification*)notification
{
  [self removeObsoleteFiles];
}
//end applicationWillTerminate:

-(void) removeObsoleteFiles
{
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
  NSError* error = nil;
  NSArray* result = ![self->poolOfObsoleteUniqueIds count] ? nil :
    [fileManager respondsToSelector:@selector(contentsOfDirectoryAtPath:error:)] ?
      [fileManager contentsOfDirectoryAtPath:workingDirectory error:&error] :
      [fileManager directoryContentsAtPath:workingDirectory];
  unsigned int count = [result count];
  if (count)
  {
    NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
    @synchronized(self->poolOfObsoleteUniqueIds)
    {
      while(count--)
      {
        NSString* filename = [result objectAtIndex:count];
        NSEnumerator* enumerator = [self->poolOfObsoleteUniqueIds objectEnumerator];
        NSString* obsoleteUniqueId = nil;
        while((obsoleteUniqueId = [enumerator nextObject]))
        {
          if ([filename isMatchedByRegex:[NSString stringWithFormat:@"^\\Q%@\\E.*", obsoleteUniqueId]])
            [fileManager removeFileAtPath:[workingDirectory stringByAppendingPathComponent:filename] handler:nil];
        }//end for each obsoleteUniqueId
      }//end for each file
    }//end @synchronized(self->poolOfObsoleteUniqueIds)
    [ap drain];
  }//end if (count)
}
//end removeObsoleteFiles

//called by the Latexise button; will launch the latexisation
-(IBAction) latexize:(id)sender
{
  if ([self isBusy])
    [self setBusyIdentifier:nil];//will cancel result
  else//if (![self isBusy])
  {
    [self->lowerBoxControlsBoxFontSizeTextField validateEditing];
    NSDictionary* configuration =
      [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], @"runBegin", nil];
    [self latexizeCoreRunWithConfiguration:configuration];
  }//end if (![self isBusy])
}
//end latexize:

-(void) waitLatexizationDidEnd:(NSNotification*)notification
{
  NSDictionary* configuration = [notification object];
  id document = [configuration objectForKey:@"document"];
  if (self == document)
  {
    @synchronized(self){
      --self->nbBackgroundLatexizations;
    }
    NSString* previousUniqueId = [configuration objectForKey:@"uniqueIdentifier"];
    if (previousUniqueId)
    {
      @synchronized(self->poolOfObsoleteUniqueIds){
        [self->poolOfObsoleteUniqueIds addObject:previousUniqueId];
      }
    }
    if (self->isClosed)
    {
      @synchronized(self){
        if (!self->nbBackgroundLatexizations)
          [self autorelease];
      }
    }
    else//if (!self->isClosed)
    {
      @synchronized(self)
      {
        if (!previousUniqueId || [self->busyIdentifier isEqualToString:previousUniqueId])
        {
          NSMutableDictionary* configuration2 = [[configuration mutableCopy] autorelease];
          [configuration2 setObject:[NSNumber numberWithBool:NO] forKey:@"runBegin"];
          [configuration2 setObject:[NSNumber numberWithBool:YES] forKey:@"runEnd"];
          [self performSelectorOnMainThread:@selector(latexizeCoreRunWithConfiguration:) withObject:configuration2 waitUntilDone:NO];
        }//end if ([self->busyIdentifier isEqualToString:previousUniqueId])
      }
    }//end if (!self->isClosed)
  }//end if (self == document)
}
//end waitLatexizationDidEnd:

-(void) latexizeCoreRunWithConfiguration:(NSDictionary*)configuration
{
  BOOL runBegin = [[configuration objectForKey:@"runBegin"] boolValue];
  BOOL runEnd   = [[configuration objectForKey:@"runEnd"] boolValue];

  NSString* body = [self->lowerBoxSourceTextView string];
  BOOL mustProcess = runEnd || (body && [body length]);

  if (runBegin && !mustProcess)
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
  }//end if (runBegin && !mustProcess)
  
  if (runBegin && mustProcess)
  {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:ShowWhiteColorWarningKey] &&
        [[self->lowerBoxControlsBoxFontColorWell color] isRGBEqualTo:[NSColor whiteColor]])
    {
      [self->lowerBoxControlsBoxFontColorWell deactivate];
      [[[AppController appController] whiteColorWarningWindow] center];
      int result = [NSApp runModalForWindow:[[AppController appController] whiteColorWarningWindow]];
      if (result == NSCancelButton)
        mustProcess = NO;
    }
  }//end if (runBegin && mustProcess)

  NSArray*  errors     = [configuration objectForKey:@"outErrors"];
  NSString* outFullLog = [configuration objectForKey:@"outFullLog"];
  NSData*   pdfData    = [configuration objectForKey:@"outPdfData"];

  NSString* uniqueIdentifier = nil;
  if (runBegin && mustProcess)
  {
    @synchronized(self){
      if (!self->nbBackgroundLatexizations)
      {
        uniqueIdentifier = [NSString stringWithFormat:@"latexit-%u", uniqueId];
      }
      else//if (self->nbBackgroundLatexizations)
      {
        @synchronized(self->poolOfObsoleteUniqueIds){
          if ([self->poolOfObsoleteUniqueIds count])
          {
            uniqueIdentifier = [[[self->poolOfObsoleteUniqueIds lastObject] retain] autorelease];
            [self->poolOfObsoleteUniqueIds removeLastObject];
          }
          else
          {
            CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
            CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuid);
            if (uuid) CFRelease(uuid);
            uniqueIdentifier = [NSString stringWithFormat:@"latexit-%u-%@", uniqueId, !uuidString ? @"" : (NSString*)uuidString];
            if (uuidString) CFRelease(uuidString);
          }
        }
      }//end if (self->isBackgroundLatexizing)
    }//end @synchronized(self)

    PreferencesController* preferencesController = [PreferencesController sharedController];
    [self->upperBoxImageView setPDFData:nil cachedImage:nil];       //clears current image
    [self->upperBoxImageView setBackgroundColor:[preferencesController documentImageViewBackgroundColor]
                              updateHistoryItem:NO];
    if ([preferencesController documentUseAutomaticHighContrastedPreviewBackground])
      [self->upperBoxImageView setBackgroundColor:nil updateHistoryItem:NO];
    [self->upperBoxImageView setNeedsDisplay:YES];
    [self->upperBoxImageView displayIfNeeded]; //refresh it
    [self setBusyIdentifier:uniqueIdentifier];
  }//end if (runBegin && mustProcess)

  if (runBegin && mustProcess)
  {
    PreferencesController* preferencesController = [PreferencesController sharedController];

    //computes the parameters thanks to the value of the GUI elements
    NSString* preamble = [[[self->lowerBoxPreambleTextView string] mutableCopy] autorelease];
    NSColor* color = [[[self->lowerBoxControlsBoxFontColorWell color] copy] autorelease];
    latex_mode_t mode = (latex_mode_t) [self->lowerBoxControlsBoxLatexModeSegmentedControl selectedSegmentTag];
    
    //perform effective latexisation

    NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
    
    [self removeObsoleteFiles];

    NSDictionary* fullEnvironment = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];
    
    CGFloat leftMargin   = [[AppController appController] marginsCurrentLeftMargin];
    CGFloat rightMargin  = [[AppController appController] marginsCurrentRightMargin];
    CGFloat bottomMargin = [[AppController appController] marginsCurrentBottomMargin];
    CGFloat topMargin    = [[AppController appController] marginsCurrentTopMargin];

    NSMutableDictionary* configuration = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:
      [NSNumber numberWithBool:YES], @"runInBackgroundThread",
      self, @"document",
      preamble, @"preamble", body, @"body", color, @"color", [NSNumber numberWithInt:mode], @"mode",
      [NSNumber numberWithDouble:[self->lowerBoxControlsBoxFontSizeTextField doubleValue]], @"magnification",
      [preferencesController compositionConfigurationDocument], @"compositionConfiguration",
      ![self->upperBoxImageView backgroundColor] ? (id)[NSNull null] : (id)[self->upperBoxImageView backgroundColor], @"backgroundColor",
      [NSNumber numberWithDouble:leftMargin], @"leftMargin",
      [NSNumber numberWithDouble:rightMargin], @"rightMargin",
      [NSNumber numberWithDouble:topMargin], @"topMargin",
      [NSNumber numberWithDouble:bottomMargin], @"bottomMargin",
      [[AppController appController] additionalFilesPaths], @"additionalFilesPaths",
      !workingDirectory ? @"" : workingDirectory, @"workingDirectory",
      !fullEnvironment ? [NSDictionary dictionary] : fullEnvironment, @"fullEnvironment",
      !uniqueIdentifier ? @"" : uniqueIdentifier, @"uniqueIdentifier",
      !outFullLog ? @"" : outFullLog, @"outFullLog",
      !errors ? [NSArray array] : errors, @"outErrors",
      !pdfData ? [NSData data] : pdfData, @"outPdfData",
      nil] autorelease];
    @synchronized(self){
      ++self->nbBackgroundLatexizations;
    }
    [[LaTeXProcessor sharedLaTeXProcessor] latexiseWithConfiguration:configuration];
  }//end if (runBegin && mustProcess)

  if (runEnd && mustProcess)
  {
    [self->lastExecutionLog setString:outFullLog];
    [self->documentExtraPanelsController setLog:self->lastExecutionLog];//self->documentExtraPanelsController may be nil
    [self _analyzeErrors:errors];

    //did it work ?
    BOOL failed = !pdfData || [self->upperBoxLogTableView numberOfRows];
    if (failed)
    {
      if (![self->upperBoxLogTableView numberOfRows] ) //unexpected error...
        [self->upperBoxLogTableView setErrors:
          [NSArray arrayWithObject:
            [NSString stringWithFormat:@"::%@",
              NSLocalizedString(@"unexpected error, please see \"LaTeX > Display last log\"",
                                @"unexpected error, please see \"LaTeX > Display last log\"")]]];
    }//end if (failed)
    else//if (!failed)
    {
      //if it is ok, updates the image view
      [self->upperBoxImageView setPDFData:pdfData cachedImage:nil];
      self->currentEquationIsARecentLatexisation = YES;

      //and insert a new element into the history
      LatexitEquation* latexitEquation = [self latexitEquationWithCurrentStateTransient:NO];
      
      PreferencesController* preferencesController = [PreferencesController sharedController];
      if ([preferencesController documentUseAutomaticHighContrastedPreviewBackground])
      {
        NSColor* latexitEquationBackgroundColor = [latexitEquation backgroundColor];
        if (!latexitEquationBackgroundColor)
          latexitEquationBackgroundColor = [NSColor whiteColor];
        CGFloat grayLevelOfBackgroundColorToApply = [latexitEquationBackgroundColor grayLevel];
        CGFloat grayLevelOfTextColor              = [[latexitEquation color] grayLevel];
        if ((grayLevelOfBackgroundColorToApply < .5) && (grayLevelOfTextColor < .5))
          latexitEquationBackgroundColor = [NSColor whiteColor];
        else if ((grayLevelOfBackgroundColorToApply > .5) && (grayLevelOfTextColor > .5))
          latexitEquationBackgroundColor = [NSColor blackColor];
        [latexitEquation setBackgroundColor:latexitEquationBackgroundColor];
      }

      if (![[PreferencesController sharedController] historySmartEnabled])
      {
        [[AppController appController] addEquationToHistory:latexitEquation];
      }
      [self->upperBoxImageView setBackgroundColor:[latexitEquation backgroundColor] updateHistoryItem:NO];
      [[[AppController appController] historyWindowController] deselectAll:0];
      [[self undoManager] disableUndoRegistration];
      [self applyLatexitEquation:latexitEquation isRecentLatexisation:YES];
      [[self undoManager] enableUndoRegistration];
      
      //reupdate for easter egg
      [self->upperBoxImageView setPDFData:[latexitEquation pdfData] cachedImage:[self _checkEasterEgg]];

      //updates the pasteboard content for a live Linkback link, and triggers a sendEdit
      [self->upperBoxImageView updateLinkBackLink:self->linkBackLink];
    }//end if (!failed)

    //not busy any more
    [self setBusyIdentifier:nil];
  }//end if (runEnd && mustProcess)
}
//end latexizeCoreRunBegin:runEnd:

-(IBAction) latexizeAndExport:(id)sender
{
  [self latexize:sender];
  if ([self canReexport])
    [self reexportImage:sender];
}
//end latexizeAndExport:

-(latex_mode_t) latexMode
{
  latex_mode_t result = (latex_mode_t)[self->lowerBoxControlsBoxLatexModeSegmentedControl selectedSegmentTag];
  return result;
}
//end latexMode

-(void) setLatexMode:(latex_mode_t)mode
{
  [self->lowerBoxControlsBoxLatexModeSegmentedControl selectSegmentWithTag:mode];
}
//end setLatexMode:

-(void) setColor:(NSColor*)color
{
  [self->lowerBoxControlsBoxFontColorWell setColor:color];
}
//end setColor:

-(void) setMagnification:(CGFloat)magnification
{
  [self->lowerBoxControlsBoxFontSizeTextField setFloatValue:magnification];
}
//end setMagnification:

//This will update the error tableview, filling it with the filtered log obtained during the latexisation, and add error markers
//in the rulertextviews
-(void) _analyzeErrors:(NSArray*)errors
{
  [self->upperBoxLogTableView setErrors:errors];
  
  [self->lowerBoxPreambleTextView clearErrors];
  [self->lowerBoxSourceTextView clearErrors];
  int numberOfRows = [self->upperBoxLogTableView numberOfRows];
  int i = 0;
  for(i = 0 ; i<numberOfRows ; ++i)
  {
    NSNumber* lineNumber = [self->upperBoxLogTableView tableView:self->upperBoxLogTableView
                            objectValueForTableColumn:[self->upperBoxLogTableView tableColumnWithIdentifier:@"line"] row:i];
    NSString* message = [self->upperBoxLogTableView tableView:self->upperBoxLogTableView
                      objectValueForTableColumn:[self->upperBoxLogTableView tableColumnWithIdentifier:@"message"] row:i];
    int line = [lineNumber intValue];
    int nbLinesInUserPreamble = [self->lowerBoxPreambleTextView nbLines];
    if (line <= nbLinesInUserPreamble)
      [self->lowerBoxPreambleTextView setErrorAtLine:line message:message];
    else
      [self->lowerBoxSourceTextView setErrorAtLine:line message:message];
  }
}
//end _analyzeErrors:

-(BOOL) hasImage
{
  return ([self->upperBoxImageView image] != nil);
}
//end hasImage

-(BOOL) isPreambleVisible
{
  //[[preambleTextView superview] superview] is a scrollview that is a subView of splitView
  return ([[[self->lowerBoxPreambleTextView superview] superview] frame].size.height > 0);
}
//end isPreambleVisible

-(void) setPreambleVisible:(BOOL)visible animate:(BOOL)animate
{
  if (!(visible && [self isPreambleVisible])) //if preamble is already visible and visible is YES, do nothing
  {
    //[[preambleTextView superview] superview] and [[sourceTextView superview] superview] are scrollviews that are subViews of splitView
    NSView* preambleView = [[self->lowerBoxPreambleTextView superview] superview];
    NSView* sourceView   = [[self->lowerBoxSourceTextView superview] superview];
    NSRect preambleFrame = [preambleView frame];
    NSRect sourceFrame = [sourceView frame];
    const CGFloat height = preambleFrame.size.height + sourceFrame.size.height;
    const CGFloat newPreambleHeight = visible ? height/2 : 0;
    const CGFloat newSourceHeight   = visible ? height/2 : height;
    int i = 0;
    for(i = animate ? 0 : 10; i<=10 ; ++i)
    {
      const CGFloat factor = i/10.0f;
      NSRect newPreambleFrame = preambleFrame;
      NSRect newSourceFrame = sourceFrame;
      newPreambleFrame.size.height = (1-factor)*preambleFrame.size.height + factor*newPreambleHeight;
      newSourceFrame.size.height   = (1-factor)*sourceFrame.size.height   + factor*newSourceHeight;
      [preambleView setFrame:newPreambleFrame]; 
      [sourceView setFrame: newSourceFrame]; 
      [self->lowerBoxSplitView adjustSubviews]; 
      [self->lowerBoxSplitView displayIfNeeded];
      if (animate)
        [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:1/100.0f]];
    }
    [self splitViewDidResizeSubviews:nil];
  }//end if there is something to change
}
//end setPreambleVisible:

-(LatexitEquation*) latexitEquationWithCurrentStateTransient:(BOOL)transient
{
  LatexitEquation* result = nil;
  /*int tag = [self->lowerBoxControlsBoxLatexModeSegmentedControl selectedSegmentTag];
  latex_mode_t mode = (latex_mode_t) tag;*/
  PreferencesController* preferencesController = [PreferencesController sharedController];
  BOOL automaticHighContrastedPreviewBackground = [preferencesController documentUseAutomaticHighContrastedPreviewBackground];
  NSColor* backgroundColor = automaticHighContrastedPreviewBackground ? nil : [self->upperBoxImageView backgroundColor];
  result = //self->linkedLibraryEquation ? [self->linkedLibraryEquation equation] :
      !transient ?
    [[[LatexitEquation alloc] initWithPDFData:[self->upperBoxImageView pdfData] useDefaults:YES] autorelease] :
    [[[LatexitEquation alloc] initWithPDFData:[self->upperBoxImageView pdfData]
                                     preamble:[[[self->lowerBoxPreambleTextView textStorage] mutableCopy] autorelease]
                                   sourceText:[[[self->lowerBoxSourceTextView textStorage] mutableCopy] autorelease]
                                        color:[self->lowerBoxControlsBoxFontColorWell color]
                                    pointSize:[self->lowerBoxControlsBoxFontSizeTextField doubleValue] date:[NSDate date]
                                         mode:[self latexMode] backgroundColor:backgroundColor] autorelease];
  if (backgroundColor)
    [result setBackgroundColor:backgroundColor];
  return result;
}
//end latexitEquationWithCurrentStateTransient:

-(BOOL) applyData:(NSData*)data sourceUTI:(NSString*)sourceUTI
{
  BOOL ok = NO;
  LatexitEquation* latexitEquation = [[LatexitEquation alloc] initWithData:data sourceUTI:sourceUTI useDefaults:YES];
  if (latexitEquation)
  {
    ok = YES;
    [self applyLatexitEquation:latexitEquation isRecentLatexisation:NO];
    [latexitEquation release];
  }//end if (latexitEquation)
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("com.adobe.pdf")))
  {
    NSString* pdfString = CGPDFDocumentCreateStringRepresentationFromData(data);
    ok = pdfString && ![pdfString isEqualToString:@""];
    if (pdfString && ![pdfString isEqualToString:@""])
      [self applyString:pdfString];
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("com.adobe.pdf")))
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.text")))
  {
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    ok = (string != nil);
    if (ok)
      [self applyString:string];
    [string release];
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.text")))
  return ok;
}
//end applyData:sourceUTI:

-(void) applyString:(NSString*)string
{
  [[[self undoManager] prepareWithInvocationTarget:self] applyLatexitEquation:[self latexitEquationWithCurrentStateTransient:YES]  isRecentLatexisation:self->currentEquationIsARecentLatexisation];
  NSString* preamble = nil;
  NSString* body     = nil;
  [self _decomposeString:string preamble:&preamble body:&body];
  if (preamble)
    [self setPreamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]];
  if (body)
    [self setSourceText:[[[NSAttributedString alloc] initWithString:body] autorelease]];
  [preamble release];
  [body release];
}
//end applyString:

-(LibraryEquation*) lastAppliedLibraryEquation
{
  return self->lastAppliedLibraryEquation;
}
//end lastAppliedLibraryEquation

-(void) setLastAppliedLibraryEquation:(LibraryEquation*)value
{
  [value retain];
  [self->lastAppliedLibraryEquation release];
  self->lastAppliedLibraryEquation = value;
}
//end setLastAppliedLibraryEquation:

//updates the document according to the given library file
-(void) applyLibraryEquation:(LibraryEquation*)libraryEquation
{
  [self applyLatexitEquation:[libraryEquation equation] isRecentLatexisation:NO]; //sets lastAppliedLibraryEquation to nil
  [self setLastAppliedLibraryEquation:libraryEquation];
}
//end applyLibraryEquation:

//sets the state of the document
-(void) applyLatexitEquation:(LatexitEquation*)latexitEquation isRecentLatexisation:(BOOL)isRecentLatexisation
{
  [[[self undoManager] prepareWithInvocationTarget:self] applyLatexitEquation:[self latexitEquationWithCurrentStateTransient:YES] isRecentLatexisation:self->currentEquationIsARecentLatexisation];
  [[[self undoManager] prepareWithInvocationTarget:self] setLastAppliedLibraryEquation:[self lastAppliedLibraryEquation]];
  [self setLastAppliedLibraryEquation:nil];
  self->currentEquationIsARecentLatexisation = isRecentLatexisation;
  if (latexitEquation)
  {
    if (self->linkedLibraryEquation && (latexitEquation != [self->linkedLibraryEquation equation]))
    {
      LatexitEquation* linkedEquation = [self->linkedLibraryEquation equation];
      [linkedEquation beginUpdate];
      [linkedEquation setPdfData:[latexitEquation pdfData]];
      [linkedEquation setPreamble:[latexitEquation preamble]];
      [linkedEquation setSourceText:[latexitEquation sourceText]];
      [linkedEquation setColor:[latexitEquation color]];
      [linkedEquation setBaseline:[latexitEquation baseline]];
      [linkedEquation setPointSize:[latexitEquation pointSize]];
      [linkedEquation setDate:[latexitEquation date]];
      [linkedEquation setMode:[latexitEquation mode]];
      [linkedEquation setBackgroundColor:[latexitEquation backgroundColor]];
      [linkedEquation setTitle:[latexitEquation title]];
      [linkedEquation endUpdate];
      latexitEquation = linkedEquation;
      LibraryWindowController* libraryWindowController = [[AppController appController] libraryWindowController];
      [libraryWindowController blink:self->linkedLibraryEquation];
    }//end if (self->linkedLibraryEquation && (latexitEquation != [self->linkedLibraryEquation equation]))

    self->lastFirstResponder = [[self windowForSheet] firstResponder];
    if ((self->lastFirstResponder != self->lowerBoxPreambleTextView) &&
        (self->lastFirstResponder != self->lowerBoxSourceTextView))
      self->lastFirstResponder = nil;
    [[self windowForSheet] makeFirstResponder:self->upperBoxImageView];

    [self _setLogTableViewVisible:NO];
    [self->upperBoxImageView setPDFData:[latexitEquation pdfData] cachedImage:[latexitEquation pdfCachedImage]];

    NSParagraphStyle* paragraphStyle = [self->lowerBoxPreambleTextView defaultParagraphStyle];
    [self setPreamble:[latexitEquation preamble]];
    [self setSourceText:[latexitEquation sourceText]];
    [[self->lowerBoxPreambleTextView textStorage] addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [[self->lowerBoxPreambleTextView textStorage] length])];
    [[self->lowerBoxSourceTextView textStorage]   addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [[self->lowerBoxSourceTextView textStorage] length])];

    [self->lowerBoxControlsBoxFontColorWell deactivate];
    [self->lowerBoxControlsBoxFontColorWell setColor:[latexitEquation color]];
    [self->lowerBoxControlsBoxFontSizeTextField setDoubleValue:[latexitEquation pointSize]];
    [self->lowerBoxControlsBoxLatexModeSegmentedControl selectSegmentWithTag:[latexitEquation mode]];
    NSColor* latexitEquationBackgroundColor = [latexitEquation backgroundColor];
    NSColor* greyLevelLatexitEquationBackgroundColor = latexitEquationBackgroundColor ? [latexitEquationBackgroundColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] : [NSColor whiteColor];
    latexitEquationBackgroundColor = ([greyLevelLatexitEquationBackgroundColor whiteComponent] == 1.0f) ? nil : latexitEquationBackgroundColor;
    NSColor* colorFromUserDefaults = [NSColor colorWithData:[[NSUserDefaults standardUserDefaults] dataForKey:DefaultImageViewBackgroundKey]];
    if (!latexitEquationBackgroundColor)
      latexitEquationBackgroundColor = colorFromUserDefaults;
    [self->upperBoxImageView setBackgroundColor:latexitEquationBackgroundColor updateHistoryItem:NO];
  }
  else
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    [self _setLogTableViewVisible:NO];
    [self->upperBoxImageView setPDFData:nil cachedImage:nil];
    NSFont* defaultFont = [NSFont fontWithData:[userDefaults dataForKey:DefaultFontKey]];

    NSParagraphStyle* paragraphStyle = [self->lowerBoxPreambleTextView defaultParagraphStyle];
    [[self->lowerBoxPreambleTextView textStorage] addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [[self->lowerBoxPreambleTextView textStorage] length])];
    [[self->lowerBoxSourceTextView textStorage]   addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, [[self->lowerBoxSourceTextView textStorage] length])];

    NSMutableDictionary* typingAttributes = [NSMutableDictionary dictionaryWithDictionary:[self->lowerBoxPreambleTextView typingAttributes]];
    [typingAttributes setObject:defaultFont forKey:NSFontAttributeName];
    [self->lowerBoxPreambleTextView setTypingAttributes:typingAttributes];
    [self->lowerBoxSourceTextView   setTypingAttributes:typingAttributes];
    [self setPreamble:[[AppController appController] preambleLatexisationAttributedString]];
    [self setSourceText:[[[NSAttributedString alloc ] init] autorelease]];
    [[self->lowerBoxPreambleTextView textStorage] addAttributes:typingAttributes range:NSMakeRange(0, [[self->lowerBoxPreambleTextView textStorage] length])];
    [[self->lowerBoxSourceTextView textStorage]   addAttributes:typingAttributes range:NSMakeRange(0, [[self->lowerBoxSourceTextView textStorage] length])];
    [self->lowerBoxControlsBoxFontColorWell deactivate];
    [self->lowerBoxControlsBoxFontColorWell setColor:[NSColor colorWithData:[userDefaults dataForKey:DefaultColorKey]]];
    [self->lowerBoxControlsBoxFontSizeTextField setDoubleValue:[userDefaults floatForKey:DefaultPointSizeKey]];
    [self->lowerBoxControlsBoxLatexModeSegmentedControl selectSegmentWithTag:[userDefaults integerForKey:DefaultModeKey]];
    [self->upperBoxImageView setBackgroundColor:[NSColor colorWithData:[[NSUserDefaults standardUserDefaults] objectForKey:DefaultImageViewBackgroundKey]]
                              updateHistoryItem:NO];
  }
}
//end applyLatexitEquation:isRecentLatexisation:

//calls the log window
-(IBAction) displayLastLog:(id)sender
{
  DocumentExtraPanelsController* controller = [self lazyDocumentExtraPanelsController];
  [controller setLog:self->lastExecutionLog];
  [[controller logWindow] makeKeyAndOrderFront:self];
}
//end displayLastLog:

-(void) updateChangeCount:(NSDocumentChangeType)changeType
{
  //does nothing (prevents dirty flag)
}
//end updateChangeCount:

//enables or disables some exports
-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok  = YES;
  if ([sender menu] == [[self->lowerBoxChangePreambleButton cell] menu])
    ok = ([sender action] != nil);
  else if ([sender menu] == [[self->lowerBoxChangeBodyTemplateButton cell] menu])
    ok = ([sender action] != nil);
  else if ([sender tag] == EXPORT_FORMAT_EPS)
    ok = [[AppController appController] isGsAvailable];
  else if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [[AppController appController] isGsAvailable] && [[AppController appController] isPsToPdfAvailable];
  else if ([sender tag] == -1)//default
  {
    export_format_t exportFormat = (export_format_t)[[NSUserDefaults standardUserDefaults] integerForKey:DragExportTypeKey];
    [sender setTitle:[NSString stringWithFormat:@"%@ (%@)",
      NSLocalizedString(@"Default Format", @"Default Format"),
      [[AppController appController] nameOfType:exportFormat]]];
  }
  return ok;
}
//end validateMenuItem:

//asks for a filename and format to export
-(IBAction) exportImage:(id)sender
{
  //first, disables PDF_NOT_EMBEDDED_FONTS if needed
  DocumentExtraPanelsController* controller = [self lazyDocumentExtraPanelsController];
  if(![controller currentSavePanel])//not already onscreen
  {
    if (([controller saveAccessoryViewExportFormat] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) &&
        (![[AppController appController] isGsAvailable] || ![[AppController appController] isPsToPdfAvailable]))
      [controller setSaveAccessoryViewExportFormat:EXPORT_FORMAT_PDF];

    NSSavePanel* currentSavePanel = [NSSavePanel savePanel];
    [controller setCurrentSavePanel:currentSavePanel];
    [currentSavePanel setCanSelectHiddenExtension:YES];
    [currentSavePanel setCanCreateDirectories:YES];
    [currentSavePanel setExtensionHidden:NO];

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
  }//end if(![controller currentSavePanel])//not already onscreen
}
//end exportImage:

-(BOOL) canReexport
{
  return [[self fileURL] path] && [self hasImage];
}
//end canReexport

//asks for a filename and format to export
-(IBAction) reexportImage:(id)sender
{
  if (![self canReexport])
    [self exportImage:sender];
  else
  {
    DocumentExtraPanelsController* controller = [self lazyDocumentExtraPanelsController];
    //first, disables PDF_NOT_EMBEDDED_FONTS if needed
    if (([controller saveAccessoryViewExportFormat] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) &&
        (![[AppController appController] isGsAvailable] || ![[AppController appController] isPsToPdfAvailable]))
      [controller setSaveAccessoryViewExportFormat:EXPORT_FORMAT_PDF];
    [self exportImageWithData:[self->upperBoxImageView pdfData] format:[controller saveAccessoryViewExportFormat]
               scaleAsPercent:[controller saveAccessoryViewOptionsJpegQualityPercent] jpegColor:[controller saveAccessoryViewOptionsJpegBackgroundColor]
                  jpegQuality:[controller saveAccessoryViewOptionsJpegQualityPercent] filePath:[[self fileURL] path]];
  }//end if ([can reexport])
}
//end reexportImage:

-(void) exportChooseFileDidEnd:(NSSavePanel*)sheet returnCode:(int)code contextInfo:(void*)contextInfo
{
  DocumentExtraPanelsController* controller = [self lazyDocumentExtraPanelsController];
  if ((code == NSOKButton) && [self->upperBoxImageView image])
  {
    [self exportImageWithData:[self->upperBoxImageView pdfData] format:[controller saveAccessoryViewExportFormat]
               scaleAsPercent:[controller saveAccessoryViewScalePercent]
                    jpegColor:[controller saveAccessoryViewOptionsJpegBackgroundColor] jpegQuality:[controller saveAccessoryViewOptionsJpegQualityPercent]
                     filePath:[sheet filename]];
  }//end if save
  [controller setCurrentSavePanel:nil];
}
//end exportChooseFileDidEnd:returnCode:contextInfo:

-(void) exportImageWithData:(NSData*)pdfData format:(export_format_t)exportFormat scaleAsPercent:(CGFloat)scaleAsPercent
                  jpegColor:(NSColor*)aJpegColor jpegQuality:(CGFloat)aJpegQuality filePath:(NSString*)filePath
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSData* data = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData jpegColor:aJpegColor
                                                jpegQuality:aJpegQuality/100 scaleAsPercent:scaleAsPercent
                                                compositionConfiguration:[preferencesController compositionConfigurationDocument]
                                                uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  if (data)
  {
    [data writeToFile:filePath atomically:YES];
    [[NSFileManager defaultManager] changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt']
                                                  forKey:NSFileHFSCreatorCode] atPath:filePath];    
    NSColor* backgroundColor = (exportFormat == EXPORT_FORMAT_JPEG) ? aJpegColor : nil;
    if ((exportFormat != EXPORT_FORMAT_PNG) &&
        (exportFormat != EXPORT_FORMAT_TIFF) &&
        (exportFormat != EXPORT_FORMAT_JPEG))
      [[NSWorkspace sharedWorkspace] setIcon:[[LaTeXProcessor sharedLaTeXProcessor] makeIconForData:pdfData backgroundColor:backgroundColor]
                                     forFile:filePath options:NSExclude10_4ElementsIconCreationOption];
    [self triggerSmartHistoryFeature];
  }//end if save
}
//end exportImageWithData:format:scaleAsPercent:jpegColor:jpegQuality:filePath:

-(void) triggerSmartHistoryFeature
{
  if (self->currentEquationIsARecentLatexisation && [[PreferencesController sharedController] historySmartEnabled])
  {
    [[AppController appController] addEquationToHistory:[self latexitEquationWithCurrentStateTransient:NO]];
    self->currentEquationIsARecentLatexisation = NO;
  }//end if (self->currentEquationIsARecentLatexisation && [[PreferencesController sharedController] historySmartEnabled])
}
//end triggerSmartHistoryFeature

-(NSString*) selectedText
{
  NSString* text = [NSString string];
  NSResponder* firstResponder = [[self windowForSheet] firstResponder];
  if ((firstResponder == self->lowerBoxPreambleTextView) || (firstResponder == self->lowerBoxSourceTextView))
  {
    NSTextView* textView = (NSTextView*) firstResponder;
    text = [[textView string] substringWithRange:[textView selectedRange]];
  }
  return text;
}
//end selectedText

-(void) insertText:(id)text
{
  NSResponder* firstResponder = [[self windowForSheet] firstResponder];
  if ((firstResponder == self->lowerBoxPreambleTextView) || (firstResponder == self->lowerBoxSourceTextView))
    [firstResponder insertText:text];
}
//end insertText:

-(BOOL) isBusy
{
  BOOL result = (self->busyIdentifier != nil);
  return result;
}
//end isBusy

-(void) setBusyIdentifier:(NSString*)value
{
  @synchronized(self)
  {
    if (![self->busyIdentifier isEqualToString:value])
    {
      [self->busyIdentifier release];
      self->busyIdentifier = [value copy];
      //[self->upperBoxImageView     setEnabled:!self->busyIdentifier];
      [self->upperBoxZoomBoxSlider setEnabled:!self->busyIdentifier];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl setEnabled:!self->busyIdentifier];
      [self->lowerBoxControlsBoxFontSizeTextField setEnabled:!self->busyIdentifier];
      [self->lowerBoxControlsBoxFontColorWell setEnabled:!self->busyIdentifier];
      [self->lowerBoxPreambleTextView setEditable:!self->busyIdentifier];
      [self->lowerBoxChangePreambleButton setEnabled:!self->busyIdentifier];
      [self->lowerBoxSourceTextView setEditable:!self->busyIdentifier];
      [self->lowerBoxChangeBodyTemplateButton setEnabled:!self->busyIdentifier];
      [self->lowerBoxLatexizeButton setTitle:
        self->busyIdentifier ? NSLocalizedString(@"Stop", @"Stop") : NSLocalizedString(@"LaTeX it!", @"LaTeX it!")];
      if (self->busyIdentifier)
      {
        [self->upperBoxImageView addSubview:self->upperBoxProgressIndicator];
        [self->upperBoxProgressIndicator centerInSuperviewHorizontally:YES vertically:YES];
        [self->upperBoxProgressIndicator setHidden:NO]; //shows the progress indicator
        [self->upperBoxProgressIndicator startAnimation:self];
      }//end if (self->isBusy)
      else
      {
        //hides progress indicator
        [self->upperBoxProgressIndicator stopAnimation:self];
        [self->upperBoxProgressIndicator setHidden:YES];
        [self->upperBoxProgressIndicator removeFromSuperview];

        //hides/how the error view
        [self _setLogTableViewVisible:([self->upperBoxLogTableView numberOfRows] > 0)];
      }
    }//end if (![self->busyIdentifier isEqualToString:value])
  }//end @synchronized(self)
}
//end setBusy:

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
    NSRange errorRange = [self->lastExecutionLog rangeOfString:message options:NSCaseInsensitiveSearch];
    if (errorRange.location != NSNotFound)
    {
      NSTextView* logTextView = [self->documentExtraPanelsController logTextView];//may be nil
      [logTextView setSelectedRange:errorRange];
      [logTextView scrollRangeToVisible:errorRange];
    }
  }
  else
    [self gotoLine:[number intValue]];
}
//end _clickErrorLine:

-(void) gotoLine:(int)row
{
  if ([self->lowerBoxPreambleTextView gotoLine:row])
    [self setPreambleVisible:YES animate:YES];
  else
    [self->lowerBoxSourceTextView gotoLine:row];
}
//end gotoLine:

//hides/display the error log table view
-(void) _setLogTableViewVisible:(BOOL)status
{
  NSScrollView* scrollView = (NSScrollView*) [[self->upperBoxLogTableView superview] superview];
  [scrollView setHidden:!status];
  [scrollView setNeedsDisplay:YES];
}
//end _setLogTableViewVisible:

//returns the linkBack link
-(LinkBack*) linkBackLink
{
  return self->linkBackLink;
}
//end linkBackLink

//sets up a new linkBack link
-(void) setLinkBackLink:(LinkBack*)newLinkBackLink
{
  if (newLinkBackLink != self->linkBackLink)
  {
    [self closeLinkBackLink:self->linkBackLink];
    self->linkBackLink = [newLinkBackLink retain];
  }//end if (newLinkBackLink != self->linkBackLink)
}
//end setLinkBackLink:

//if current linkBack link is aLink, then close it. Also close if aLink == nil
-(void) closeLinkBackLink:(LinkBack*)aLink
{
  if (!aLink || (self->linkBackLink == aLink))
  {
    aLink = self->linkBackLink;
    self->linkBackLink = nil;
    [[AppController appController] closeLinkBackLink:aLink];
    [aLink release];
    [self setDocumentTitle:nil];
  }
}
//end closeLinkBackLink:

-(LibraryEquation*) linkedLibraryEquation
{
  return self->linkedLibraryEquation;
}
//end linkedLibraryEquation

-(void) setLinkedLibraryEquation:(LibraryEquation*)libraryEquation
{
  if (libraryEquation != self->linkedLibraryEquation)
  {
    if (!self->isObservingLibrary && libraryEquation)
    {
      [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(libraryDidChangeNotification:) name:NSManagedObjectContextObjectsDidChangeNotification object:[[LibraryManager sharedManager] managedObjectContext]];
      self->isObservingLibrary = YES;
    }//end if (!self->isObservingLibrary && libraryEquation)
    [self closeLinkedLibraryEquation:self->linkedLibraryEquation];
    self->linkedLibraryEquation = [libraryEquation retain];
    if (!self->linkedLibraryEquation)
      [self setDocumentTitle:nil];
    else//if (self->linkedLibraryEquation)
    {
      [self setDocumentTitle:[libraryEquation title]];
      if (isMacOS10_5OrAbove())
        [[self windowForSheet] setRepresentedFilename:[libraryEquation title]];
    }//end if (self->linkedLibraryEquation)
  }//end if (libraryEquation != self->linkedLibraryEquation)
}
//end setLinkedLibraryEquation:

-(BOOL) window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu*)menu
{
  BOOL result = NO;
  if (self->linkedLibraryEquation)
  {
    while([menu numberOfItems])
      [menu removeItemAtIndex:0];
    NSMenuItem* menuItem =
      [menu addItemWithTitle:[self->linkedLibraryEquation title] action:@selector(selectLibraryItemForCurrentLinkedEquation:) keyEquivalent:@""];
    [menuItem setTarget:self];
    [menuItem setRepresentedObject:self->linkedLibraryEquation];
    result = YES;
  }//end if (self->linkedLibraryEquation)
  return result;
}
//end window:shouldPopUpDocumentPathMenu:

-(void) selectLibraryItemForCurrentLinkedEquation:(id)sender
{
  [[[[AppController appController] libraryWindowController] libraryView] selectItem:self->linkedLibraryEquation byExtendingSelection:NO];
}
//end selectLibraryItemForCurrentLinkedEquation:

-(void) closeLinkedLibraryEquation:(LibraryEquation*)libraryEquation
{
  if (!libraryEquation || (self->linkedLibraryEquation == libraryEquation))
  {
    libraryEquation = self->linkedLibraryEquation;
    self->linkedLibraryEquation = nil;
    [libraryEquation release];
    [self setDocumentTitle:nil];
  }
}
//end closeLinkedLibraryEquation:

-(void) libraryDidChangeNotification:(NSNotification*)notification
{
  if (self->linkedLibraryEquation)
  {
    if (![self->linkedLibraryEquation managedObjectContext] || [self->linkedLibraryEquation isDeleted])
    {
      //[[[self undoManager] prepareWithInvocationTarget:self] setLinkedLibraryEquation:self->linkedLibraryEquation];
      [self closeLinkedLibraryEquation:self->linkedLibraryEquation];
    }
    else if ([[[notification userInfo] objectForKey:NSUpdatedObjectsKey] containsObject:self->linkedLibraryEquation])
    {
      [self applyLibraryEquation:self->linkedLibraryEquation];
      [self setDocumentTitle:[self->linkedLibraryEquation title]];
      if (isMacOS10_5OrAbove())
        [[self windowForSheet] setRepresentedFilename:[self->linkedLibraryEquation title]];
    }
  }//end if (self->linkedLibraryEquation)
}
//end libraryDidChangeNotification:

-(NSImage*) _checkEasterEgg
{
  NSImage* easterEggImage = nil;
  
  BOOL forceEasterEggForDebugging = NO;
  
  NSCalendarDate* now = [NSCalendarDate date];
  NSString* easterEggString = nil;
  if (forceEasterEggForDebugging || (([now monthOfYear] == 4) && ([now dayOfMonth] == 1)))
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
    if (forceEasterEggForDebugging || (!easterEggLastDate) || [now isLessThan:easterEggLastDate] ||
        ([now yearOfCommonEra] != [easterEggLastDate yearOfCommonEra]))
    {
      NSString* resource = [resources objectForKey:easterEggString];
      NSString* filePath = resource ? [[NSBundle mainBundle] pathForResource:[resource stringByDeletingPathExtension]
                                                                      ofType:[resource pathExtension]] : nil;
      if (resource && filePath)
        easterEggImage = [[[NSImage alloc] initWithContentsOfFile:filePath] autorelease];
      [easterEggLastDates setObject:[NSCalendarDate date] forKey:easterEggString];
    }
    [userDefaults setObject:[NSArchiver archivedDataWithRootObject:easterEggLastDates] forKey:LastEasterEggsDatesKey];
  }//end if (easterEggString)
  return easterEggImage;
}
//end _checkEasterEgg:

-(NSString*) descriptionForScript:(NSDictionary*)script
{
  NSMutableString* description = [NSMutableString string];
  if (script)
  {
    switch([[script objectForKey:CompositionConfigurationAdditionalProcessingScriptTypeKey] intValue])
    {
      case SCRIPT_SOURCE_STRING :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"Shell", @"Shell"),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Body", @"Body"),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptContentKey]];
        break;
      case SCRIPT_SOURCE_FILE :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"File", @"File"),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Content", @"Content"),
          [script objectForKey:CompositionConfigurationAdditionalProcessingScriptPathKey]];
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
    NSRect oldUpFrame  = [self->upperBox frame];
    NSRect oldLowFrame = [self->lowerBox frame];
    CGFloat margin = reduce ? [self->lowerBoxSplitView frame].size.height/2 : -[self->lowerBoxSplitView frame].size.height;
    NSRect newUpFrame  = NSMakeRect(oldUpFrame.origin.x, oldUpFrame.origin.y-margin, oldUpFrame.size.width, oldUpFrame.size.height+margin);
    NSRect newLowFrame = NSMakeRect(oldLowFrame.origin.x, oldLowFrame.origin.y, oldLowFrame.size.width, oldLowFrame.size.height-margin);
    NSViewAnimation* viewAnimation =
      [[[NSViewAnimation alloc] initWithViewAnimations:
        [NSArray arrayWithObjects:
          [NSDictionary dictionaryWithObjectsAndKeys:self->upperBox, NSViewAnimationTargetKey,
                                                     [NSValue valueWithRect:oldUpFrame], NSViewAnimationStartFrameKey,
                                                     [NSValue valueWithRect:newUpFrame], NSViewAnimationEndFrameKey,
                                                     nil],
          [NSDictionary dictionaryWithObjectsAndKeys:self->lowerBox, NSViewAnimationTargetKey,
                                                     [NSValue valueWithRect:oldLowFrame], NSViewAnimationStartFrameKey,
                                                     [NSValue valueWithRect:newLowFrame], NSViewAnimationEndFrameKey,
                                                     nil],
          nil]] autorelease];
    [viewAnimation setDuration:.5];
    [viewAnimation setAnimationBlockingMode:NSAnimationNonblocking];
    [viewAnimation startAnimation];
    self->isReducedTextArea = reduce;
  }
}
//setReducedTextAreaState:

-(void) splitViewDidResizeSubviews:(NSNotification*)notification
{
  [self->lowerBoxChangePreambleButton setHidden://([self documentStyle] == DOCUMENT_STYLE_NORMAL) &&
    (![self isPreambleVisible] || ([[self->lowerBoxPreambleTextView superview] frame].size.height < [self->lowerBoxChangePreambleButton frame].size.height))];
  NSRect frame = [self->lowerBoxChangeBodyTemplateButton frame];
  frame.origin = [[[self->lowerBoxSourceTextView superview] superview] frame].origin;
  frame.origin.y = [self->lowerBoxSplitView frame].size.height-
                   [[[self->lowerBoxSourceTextView superview] superview] frame].origin.y-
                   frame.size.height;
  frame.origin.x += [self->lowerBoxSplitView frame].origin.x;
  frame.origin.y += [self->lowerBoxSplitView frame].origin.y;
  [self->lowerBoxChangeBodyTemplateButton setFrame:frame];
  [self->lowerBoxChangeBodyTemplateButton setHidden:
    ([[[self->lowerBoxSourceTextView superview] superview] frame].size.height < frame.size.height)];
}
//end splitViewDidResizeSubviews:

-(void) popUpButtonWillPopUp:(NSNotification*)notification
{
  NSPopUpButtonCell* changePreambleButtonCell = [self->lowerBoxChangePreambleButton cell];
  NSPopUpButtonCell* changeBodyTemplateButtonCell = [self->lowerBoxChangeBodyTemplateButton cell];
  if ([notification object] == changePreambleButtonCell)
  {
    NSAttributedString* currentPreamble = [self->lowerBoxPreambleTextView textStorage];
    NSArray* preambles                  = [[PreferencesController sharedController] preambles];
    NSInteger defaultDocumentPreamble   = [[PreferencesController sharedController] preambleDocumentIndex];
    NSInteger i = 0;
    NSDictionary* matchingPreamble = nil;
    for(i = 0 ; (unsigned)i<[preambles count] ; ++i)
    {
      NSDictionary* preamble = [preambles objectAtIndex:i];
      id rawValue = [preamble objectForKey:@"value"];
      NSAttributedString* value = [rawValue isKindOfClass:[NSAttributedString class]] ? rawValue :
                                  [rawValue isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawValue] :
                                  nil;
      NSString* currentPreambleAsTrimmedString = [[currentPreamble string] trim];
      NSString* candidatePreambleAsTrimmedString = [[value string] trim];
      BOOL isMatching = [currentPreambleAsTrimmedString isEqualToString:candidatePreambleAsTrimmedString];
      if (isMatching && (!matchingPreamble || (i == defaultDocumentPreamble)))
        matchingPreamble = preamble;
    }
  
    [changePreambleButtonCell removeAllItems];
    NSMenu* menu = [changePreambleButtonCell menu];
    [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [menu addItemWithTitle:[NSString stringWithFormat:@"%@...", NSLocalizedString(@"Preambles", @"Preambles")]
      action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    NSEnumerator* enumerator = [preambles objectEnumerator];
    NSDictionary* preamble = nil;
    while((preamble = [enumerator nextObject]))
    {
      id item = [menu addItemWithTitle:[preamble objectForKey:@"name"] action:@selector(changePreamble:) keyEquivalent:@""];
      [item setRepresentedObject:preamble];
      if (preamble == matchingPreamble)
        [item setState:NSOnState];
    }
      
    [menu setDelegate:(id)self];
  }//end if ([notification object] == changePreambleButtonCell)
  if ([notification object] == changeBodyTemplateButtonCell)
  {
    NSString* currentBody = [[self->lowerBoxSourceTextView textStorage] string];
    NSInteger bodyTemplateDocumentIndex = [[PreferencesController sharedController] bodyTemplateDocumentIndex];
    NSArray*  bodyTemplates = [[PreferencesController sharedController] bodyTemplatesWithNone];
    NSInteger i = 0;
    NSInteger matchIndex = 0;
    for(i = 1 ; (unsigned)i<[bodyTemplates count] ; ++i)//skip first one at 0 (which is "none")
    {
      NSDictionary* bodyTemplate = [bodyTemplates objectAtIndex:i];
      id rawHead = [bodyTemplate objectForKey:@"head"];
      NSAttributedString* head = [rawHead isKindOfClass:[NSAttributedString class]] ? rawHead :
                                 [rawHead isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawHead] :
                                 nil;
      id rawTail = [bodyTemplate objectForKey:@"tail"];
      NSAttributedString* tail = [rawTail isKindOfClass:[NSAttributedString class]] ? rawTail :
                                 [rawTail isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawTail] :
                                 nil;
      NSString* headString = [head string];
      NSString* tailString = [tail string];
      NSString* regexString = [NSString stringWithFormat:@"^[\\s\\n]*\\Q%@\\E[\\s\\n]*(.*)[\\s\\n]*\\Q%@\\E[\\s\\n]*$", headString, tailString];
      NSError*  error = nil;
      NSString* innerBody = [currentBody stringByMatching:regexString options:RKLMultiline|RKLDotAll inRange:NSMakeRange(0, [currentBody length])
                                                  capture:1 error:nil];
      BOOL isMatching = innerBody && !error;
      if (isMatching && (!matchIndex || (i == bodyTemplateDocumentIndex+1)))
        matchIndex = i;
    }//end for each body template
    NSDictionary* matchingBodyTemplate = [bodyTemplates objectAtIndex:matchIndex];
    [self->lastRequestedBodyTemplate release];
    self->lastRequestedBodyTemplate = [matchingBodyTemplate deepCopy];
  
    [changeBodyTemplateButtonCell removeAllItems];
    NSMenu* menu = [changeBodyTemplateButtonCell menu];
    [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [menu addItemWithTitle:[NSString stringWithFormat:@"%@...", NSLocalizedString(@"Body templates", @"Body templates")]
      action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    NSEnumerator* enumerator = [bodyTemplates objectEnumerator];
    NSDictionary* bodyTemplate = nil;
    while((bodyTemplate = [enumerator nextObject]))
    {
      id item = [menu addItemWithTitle:[bodyTemplate objectForKey:@"name"] action:@selector(changeBodyTemplate:) keyEquivalent:@""];
      [item setRepresentedObject:bodyTemplate];
      if (bodyTemplate == matchingBodyTemplate)
        [item setState:NSOnState];
    }
    [menu setDelegate:(id)self];
  }//end if ([notification object] == changeBodyTemplateButtonCell)
}
//end popUpButtonWillPopUp:

-(IBAction) changePreamble:(id)sender
{
  id preamble = nil;
  if ([sender respondsToSelector:@selector(representedObject)])
    preamble = [sender representedObject];
  if ([preamble isKindOfClass:[NSDictionary class]])
  {
    NSAttributedString* preambleAttributedString = [NSKeyedUnarchiver unarchiveObjectWithData:[preamble objectForKey:@"value"]];
    [self setPreamble:preambleAttributedString];
  }
  else
    [[AppController appController] showPreferencesPaneWithItemIdentifier:TemplatesToolbarItemIdentifier options:[NSNumber numberWithInt:0]]; 
}
//end changePreamble:

-(IBAction) changeBodyTemplate:(id)sender
{
  id bodyTemplate = nil;
  if ([sender respondsToSelector:@selector(representedObject)])
  {
    bodyTemplate = [sender representedObject];
    if (!bodyTemplate || [bodyTemplate isKindOfClass:[NSDictionary class]])
      [self setBodyTemplate:bodyTemplate moveCursor:YES];
  }
  else
    [[AppController appController] showPreferencesPaneWithItemIdentifier:TemplatesToolbarItemIdentifier options:[NSNumber numberWithInt:1]]; 
}
//end changeBodyTemplate:

@end
