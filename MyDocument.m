//  MyDocument.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.

// The main document of LaTeXiT. There is much to say !

#import "MyDocument.h"

#import "AdditionalFilesWindowController.h"
#import "AppController.h"
#import "BoolTransformer.h"
#import "CGPDFExtras.h"
#import "DocumentExtraPanelsController.h"
#import "ExportFormatOptionsPanes.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
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
#import "NSObjectExtended.h"
#import "NSOutlineViewExtended.h"
#import "NSSegmentedControlExtended.h"
#import "NSStringExtended.h"
#import "NSTaskExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "NSViewExtended.h"
#import "NSWindowExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "PreferencesWindowController.h"
#import "PropertyStorage.h"
#import "SMLSyntaxColouring.h"
#import "HistoryWindowController.h"
#import "SystemTask.h"
#import "LibraryView.h"
#import "LineCountRulerView.h"
#import "Utils.h"

#import <Carbon/Carbon.h>
#import <LinkBack/LinkBack.h>
#import <Quartz/Quartz.h>
#import "RegexKitLite.h"

static NSMutableIndexSet* freeIds = nil;

double yaxb(double x, double x0, double y0, double x1, double y1);
double yaxb(double x, double x0, double y0, double x1, double y1)
{
  double a = (y1-y0)/(x1-x0);
  double b = y0-a*x0;
  return a*x+b; 
}
//end yaxb()

BOOL NSRangeContains(NSRange range, NSUInteger index);
BOOL NSRangeContains(NSRange range, NSUInteger index)
{
  BOOL result = ((range.location <= index) && (index < range.location+range.length));
  return result;
}
//end NSRangeContains()

@interface MyDocument ()

+(NSUInteger) _giveId; //returns a free id and marks it as used
+(void) _releaseId:(NSUInteger)anId; //releases an id

@property (readonly, strong) DocumentExtraPanelsController *lazyDocumentExtraPanelsController;

//updates the logTableView to report the errors
-(void) _analyzeErrors:(NSArray*)errors;

-(void) _lineCountDidChange:(NSNotification*)aNotification;
-(void) _clickErrorLine:(NSNotification*)aNotification;

-(void) _setLogTableViewVisible:(BOOL)status;

@property (readonly, copy) NSImage *_checkEasterEgg;//may return an easter egg image

-(NSString*) descriptionForScript:(NSDictionary*)script;
-(void) _decomposeString:(NSString*)string preamble:(NSString**)preamble body:(NSString**)body;

-(void) exportImageWithData:(NSData*)pdfData format:(export_format_t)exportFormat scaleAsPercent:(CGFloat)scaleAsPercent
                  jpegColor:(NSColor*)jpegColor jpegQuality:(float)jpegQuality filePath:(NSString*)filePath;
                  
-(void) latexizeCoreRunWithConfiguration:(NSDictionary*)configuration;
-(void) removeObsoleteFiles;
-(void) applicationWillTerminate:(NSNotification*)notification;

-(void) selectLibraryItemForCurrentLinkedEquation:(id)sender;
-(void) bodyTextDidChange:(NSNotification*)notification;
@end

@implementation MyDocumentWindow
-(void)toggleToolbarShown:(id)sender
{
  [(MyDocument*)self.windowController.document toggleDocumentStyle];
}
@end

@interface MyDocumentPanel : NSPanel
@end
@implementation MyDocumentPanel
-(void)toggleToolbarShown:(id)sender
{
  [(MyDocument*)self.windowController.document toggleDocumentStyle];
}
@end

@implementation MyDocument
@synthesize documentStyle;
@synthesize lastAppliedLibraryEquation;
@synthesize linkBackLink;
@synthesize linkBackAllowed;
@synthesize reducedTextArea = isReducedTextArea;
@synthesize shouldApplyToPasteboardAfterLatexization;

+(void) initialize
{
  if (!freeIds)
  {
    @synchronized(self)
    {
      if (!freeIds)
        freeIds = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(1, NSNotFound-2)];
    }//end @synchronized(self)
  }//end if (!freeIds)
}
//end initialize

//returns a free id and marks it as used
+(NSUInteger) _giveId
{
  NSUInteger result = 0;
  @synchronized(freeIds)
  {
    result = freeIds.firstIndex;
    [freeIds removeIndex:result];
  }//end @synchronized(freeIds)
  return result;
}
//end _giveId

//marks an id as free, and put it into the freeIds array
+(void) _releaseId:(NSUInteger)anId
{
  @synchronized(freeIds)
  {
    [freeIds addIndex:anId];
  }//end @synchronized(freeIds)
}
//end _releaseId:

-(instancetype) init
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
  [self closeBackSyncFile];
  [self->backSyncOptions release];
  [MyDocument _releaseId:self->uniqueId];
  [self->documentExtraPanelsController release];
  [self setLinkBackLink:nil];
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

  //get rid of formatter localization problems
  self->pointSizeFormatter.locale = [NSLocale currentLocale];
  self->pointSizeFormatter.groupingSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleGroupingSeparator];
  self->pointSizeFormatter.decimalSeparator = [[NSLocale currentLocale] objectForKey:NSLocaleDecimalSeparator];
  NSString* pointSizeZeroSymbol =
    [NSString stringWithFormat:@"0%@%0*d%@",
       self->pointSizeFormatter.decimalSeparator, 2, 0, 
       self->pointSizeFormatter.positiveSuffix];
  self->pointSizeFormatter.zeroSymbol = pointSizeZeroSymbol;

  NSWindow* window = self.windowForSheet;
  
  window.delegate = (id)self;
  [window setFrameAutosaveName:[NSString stringWithFormat:@"LaTeXiT-window-%lu", (unsigned long)self->uniqueId]];
  window.title = self.displayName;
  self->lowerBoxControlsBoxLatexModeSegmentedControlMinimumSize = self->lowerBoxControlsBoxLatexModeSegmentedControl.frame.size;
  self->documentNormalMinimumSize = window.minSize;
  self->documentMiniMinimumSize = NSMakeSize(320, 150);
  self->documentFrameSaved = window.frame;
  
  PreferencesController* preferencesController = [PreferencesController sharedController];
  self->lowerBoxControlsBoxLatexModeSegmentedControl.segmentCount = 4;
  NSUInteger segmentIndex = 0;
  NSSegmentedCell* latexModeSegmentedCell = self->lowerBoxControlsBoxLatexModeSegmentedControl.cell;
  [latexModeSegmentedCell setTag:LATEX_MODE_ALIGN   forSegment:segmentIndex];
  [latexModeSegmentedCell setLabel:NSLocalizedString(@"Align", @"Align") forSegment:segmentIndex++];
  [latexModeSegmentedCell setTag:LATEX_MODE_DISPLAY forSegment:segmentIndex];
  [latexModeSegmentedCell setLabel:NSLocalizedString(@"Display", @"Display") forSegment:segmentIndex++];
  [latexModeSegmentedCell setTag:LATEX_MODE_INLINE  forSegment:segmentIndex];
  [latexModeSegmentedCell setLabel:NSLocalizedString(@"Inline", @"Inline") forSegment:segmentIndex++];
  [latexModeSegmentedCell setTag:LATEX_MODE_TEXT    forSegment:segmentIndex];
  [latexModeSegmentedCell setLabel:NSLocalizedString(@"Text", @"Text") forSegment:segmentIndex++];
  [latexModeSegmentedCell bind:NSSelectedTagBinding toObject:self withKeyPath:@"latexModeRequested" options:nil];
  latexModeSegmentedCell.target = self;
  latexModeSegmentedCell.action = @selector(changeRequestedLatexMode:);
  self.latexModeRequested = preferencesController.latexisationLaTeXMode;
  
  [self->lowerBoxControlsBoxFontSizeLabel setStringValue:NSLocalizedString(@"Font size :", @"Font size :")];
  self->lowerBoxControlsBoxFontSizeTextField.doubleValue = preferencesController.latexisationFontSize;

  [self->lowerBoxControlsBoxFontColorLabel setStringValue:NSLocalizedString(@"Color :", @"Color :")];
  NSColor* initialColor = [AppController appController].colorStyAvailable ?
                              preferencesController.latexisationFontColor : [NSColor blackColor];
  self->lowerBoxControlsBoxFontColorWell.color = initialColor;
  
  [self->lowerBoxLatexizeButton setTitle:NSLocalizedString(@"LaTeX it!", @"LaTeX it!")];

  NSFont* defaultFont = preferencesController.editionFont;
  NSMutableDictionary* typingAttributes = [NSMutableDictionary dictionaryWithDictionary:self->lowerBoxPreambleTextView.typingAttributes];
  typingAttributes[NSFontAttributeName] = defaultFont;
  self->lowerBoxPreambleTextView.typingAttributes = typingAttributes;
  self->lowerBoxSourceTextView.typingAttributes = typingAttributes;

  [self bind:@"reducedTextArea" toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:ReducedTextAreaStateKey] options:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:window];

  self->documentStyle = DOCUMENT_STYLE_UNDEFINED;//will force change
  document_style_t preferredDocumentStyle = preferencesController.documentStyle;
  self.documentStyle = DOCUMENT_STYLE_NORMAL;
  [self windowDidResize:nil];//force colorwell resize

  NSImage*  image = [NSImage imageNamed:@"button-menu"];
  self->lowerBoxChangePreambleButton.image = image;
  self->lowerBoxChangePreambleButton.alternateImage = image;
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(popUpButtonWillPopUp:) name:NSPopUpButtonCellWillPopUpNotification object:self->lowerBoxChangePreambleButton.cell];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(scrollViewDidScroll:) name:NotifyingScrollViewDidScrollNotification object:self->lowerBoxPreambleTextView.superview.superview];
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(scrollViewDidScroll:) name:NotifyingScrollViewDidScrollNotification object:self->lowerBoxSourceTextView.superview.superview];
  self->lowerBoxChangeBodyTemplateButton.image = image;
  self->lowerBoxChangeBodyTemplateButton.alternateImage = image;
  [[NSNotificationCenter defaultCenter] addObserver:self
    selector:@selector(popUpButtonWillPopUp:) name:NSPopUpButtonCellWillPopUpNotification object:self->lowerBoxChangeBodyTemplateButton.cell];

  self.reducedTextArea = preferencesController.documentIsReducedTextArea;

  //to paste rich LaTeXiT data, we must tune the responder chain  
  self->lowerBoxSourceTextView.nextResponder = self->upperBoxImageView;
  
  [[self->upperBoxLogTableView tableColumnWithIdentifier:@"line"].headerCell
    setStringValue:NSLocalizedString(@"line", @"line")];
  [self->upperBoxLogTableView tableColumnWithIdentifier:@"message"].headerCell.stringValue = NSLocalizedString(@"Error message", @"Error message").lowercaseString;

  //useful to avoid conflicts between mouse clicks on imageView and the progressIndicator
  self->upperBoxProgressIndicator.nextResponder = self->upperBoxImageView;
  [self->upperBoxProgressIndicator retain];
  [self->upperBoxProgressIndicator removeFromSuperview];
  
  [window makeKeyAndOrderFront:self];

  NSMutableParagraphStyle* paragraphStyle = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
  NSArray* arrayOfTabs = paragraphStyle.tabStops;
  CGFloat defaultTabInterval =
    (arrayOfTabs.count >= 2) ? ((NSTextTab*)arrayOfTabs[1]).location-((NSTextTab*)arrayOfTabs[0]).location :
    paragraphStyle.defaultTabInterval;
  paragraphStyle.defaultTabInterval = defaultTabInterval;
  paragraphStyle.tabStops = @[];
  self->lowerBoxPreambleTextView.defaultParagraphStyle = paragraphStyle;
  self->lowerBoxSourceTextView.defaultParagraphStyle = paragraphStyle;
  
  [self->upperBoxImageView setBackgroundColor:preferencesController.documentImageViewBackgroundColor updateHistoryItem:NO];
  [self->upperBoxZoomBoxSlider bind:NSEnabledBinding toObject:self->upperBoxImageView withKeyPath:@"image" options:
    @{NSValueTransformerNameBindingOption: NSIsNotNilTransformerName}];
  [self->upperBoxZoomBoxSlider bind:NSValueBinding toObject:self->upperBoxImageView withKeyPath:@"zoomLevel" options:
    @{NSContinuouslyUpdatesValueBindingOption: @YES}];

  [self->lowerBoxLinkbackButton bind:NSValueBinding toObject:self withKeyPath:@"linkBackAllowed" options:
    @{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:[NSNumber numberWithInt:NSOffState]
                                       trueValue:[NSNumber numberWithInt:NSOnState]]}];
  [self->lowerBoxLinkbackButton bind:NSEnabledBinding toObject:self withKeyPath:@"linkBackAllowed" options:
    @{NSValueTransformerBindingOption: [BoolTransformer transformerWithFalseValue:@NO
                                       trueValue:@NO]}];
  [self->lowerBoxLinkbackButton setEnabled:NO];

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
    self->lowerBoxControlsBoxLatexModeSegmentedControl.selectedSegment = [self->lowerBoxControlsBoxLatexModeSegmentedControl.cell tagForSegment:LATEX_MODE_TEXT];
    [self setSourceText:[[[NSAttributedString alloc] initWithString:self->initialBody] autorelease]];
    [self->initialBody release];
    self->initialBody = nil;
  }//end if (self->initialBody)
  else//if (!self->initialBody)
  {
    [self setBodyTemplate:[PreferencesController sharedController].bodyTemplateDocumentDictionary moveCursor:YES];
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
  [notificationCenter addObserver:self selector:@selector(bodyTextDidChange:) name:NSTextDidChangeNotification object:self->lowerBoxSourceTextView];

  [self splitViewDidResizeSubviews:nil];  
  [window makeFirstResponder:[self preferredFirstResponder]];
  self.documentStyle = preferredDocumentStyle;
  
  PreferencesController* preferenceController = [PreferencesController sharedController];
  if (preferenceController.synchronizationNewDocumentsEnabled && !self.fileURL)
  {
    NSString* path =
      [preferenceController.synchronizationNewDocumentsPath
        stringByAppendingPathComponent:[self.displayName stringByAppendingPathExtension:@"tex"]];
    BOOL isDirectory = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory])
    {
      NSString* defaultFileContent =
        [NSString stringWithFormat:@"%@\n\\begin{document}\n\\end{document}\n",
          [preferenceController preambleDocumentAttributedString].string];
      NSData* defaultFileContentData = [defaultFileContent dataUsingEncoding:NSUTF8StringEncoding];
      [defaultFileContentData writeToFile:path atomically:NO];
    }//end if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory])
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && !isDirectory)
    {
      [self openBackSyncFile:path options:
        @{@"synchronizePreamble": @(preferenceController.synchronizationNewDocumentsSynchronizePreamble),
           @"synchronizeEnvironment": @(preferenceController.synchronizationNewDocumentsSynchronizeEnvironment),
           @"synchronizeBody": @(preferenceController.synchronizationNewDocumentsSynchronizeBody)}];
    }//end if ([[NSFileManager defaultManager] fileExists:path isDirectory:&isDirectory] && !isDirectory)
  }//end if ([preferenceController synchronizationNewDocumentsEnabled])
}
//end windowControllerDidLoadNib:

-(void) windowDidResize:(NSNotification*)notification
{
  if (self->documentStyle == DOCUMENT_STYLE_NORMAL)
  {
    NSRect colorWellFrame = self->lowerBoxControlsBoxFontColorWell.frame;
    colorWellFrame.size.width = MIN(52, [self->lowerBoxLatexizeButton frame].origin.x-4-colorWellFrame.origin.x);
    self->lowerBoxControlsBoxFontColorWell.frame = colorWellFrame;
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
    result = self.windowForSheet.initialFirstResponder;
  return result;
}
//end previousFirstResponder

//set the document title that will be displayed as window title. There is no represented file associated
-(void) setDocumentTitle:(NSString*)title
{
  [title retain];
  [self->documentTitle release];
  self->documentTitle = title;
  [self.windowForSheet.windowController synchronizeWindowTitleWithDocumentName];
}
//end setDocumentTitle:

-(void) setDocumentStyle:(document_style_t)value
{
  if (value != self->documentStyle)
  {
    document_style_t oldValue = self->documentStyle;
    self->documentStyle = value;
    NSWindow* window = self.windowForSheet;
    if (self->documentStyle == DOCUMENT_STYLE_MINI)
    {
      NSRect previousFrame = window.frame;
      NSRect nextFrame     = previousFrame;
      self->documentFrameSaved = previousFrame;      
      nextFrame.size = self->documentMiniMinimumSize;
      nextFrame.origin.y = previousFrame.origin.y+previousFrame.size.height-nextFrame.size.height;
      [window setShowsResizeIndicator:NO];
      window.minSize = self->documentMiniMinimumSize;
      [window setFrame:nextFrame display:YES animate:window.visible];
      NSRect newLowerBoxFrame = self->lowerBox.frame;
      newLowerBoxFrame.size.height = self->upperBox.frame.origin.y-4;
      self->lowerBox.frame = newLowerBoxFrame;

      NSRect superviewFrame = self->upperImageBox.superview.frame;
      NSRect zoomBoxFrame = self->upperBoxZoomBox.frame;
      self->upperImageBox.frame = NSMakeRect(0, 0, superviewFrame.size.width-zoomBoxFrame.size.width, superviewFrame.size.height);
      self->upperBoxZoomBox.frame = NSMakeRect(superviewFrame.size.width-zoomBoxFrame.size.width, 0, zoomBoxFrame.size.width, superviewFrame.size.height);
      
      ((NSScrollView*)self->upperBoxLogTableView.superview.superview).horizontalScroller.controlSize = NSMiniControlSize;
      ((NSScrollView*)self->upperBoxLogTableView.superview.superview).verticalScroller.controlSize = NSMiniControlSize;
      ((NSScrollView*)[self->upperBoxImageView.superview.superview dynamicCastToClass:[NSScrollView class]]).verticalScroller.controlSize = NSMiniControlSize;
      
      superviewFrame = self->lowerBox.frame;
      self->lowerBoxSplitView.frame = NSMakeRect(0,  34, superviewFrame.size.width, superviewFrame.size.height-34);
      self->lowerBoxSplitView.dividerThickness = 0.;
      NSScrollView* sourceTextScrollView = (NSScrollView*)self->lowerBoxSourceTextView.superview.superview;
      sourceTextScrollView.horizontalScroller.controlSize = NSMiniControlSize;
      sourceTextScrollView.verticalScroller.controlSize = NSMiniControlSize;
      [self->lowerBoxChangePreambleButton setFrameOrigin:NSMakePoint(0, superviewFrame.size.height-self->lowerBoxChangePreambleButton.frame.size.height)];
      self->lowerBoxControlsBox.frame = NSMakeRect(0,  0, superviewFrame.size.width, 34);

      NSRect lowerBoxControlsBoxLatexModeViewFrame =
        NSMakeRect(0, 18, self->lowerBoxControlsBoxLatexModeView.superview.frame.size.width, 16);
      self->lowerBoxControlsBoxLatexModeView.frame = lowerBoxControlsBoxLatexModeViewFrame;
      superviewFrame = self->lowerBoxControlsBoxLatexModeView.frame;
      self->lowerBoxControlsBoxLatexModeAutoButton.cell.controlSize = NSMiniControlSize;
      self->lowerBoxControlsBoxLatexModeAutoButton.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
      [self->lowerBoxControlsBoxLatexModeAutoButton sizeToFit];
      [self->lowerBoxControlsBoxLatexModeAutoButton setFrameOrigin:NSZeroPoint];
      [self->lowerBoxControlsBoxLatexModeAutoButton centerInSuperviewHorizontally:NO vertically:YES];
      self->lowerBoxControlsBoxLatexModeSegmentedControl.cell.controlSize = NSMiniControlSize;
      self->lowerBoxControlsBoxLatexModeSegmentedControl.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl sizeToFitWithSegmentWidth:floor(superviewFrame.size.width-8-NSMaxX([self->lowerBoxControlsBoxLatexModeAutoButton frame]))/self->lowerBoxControlsBoxLatexModeSegmentedControl.segmentCount useSameSize:YES];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl setFrameOrigin:NSMakePoint(NSMaxX(self->lowerBoxControlsBoxLatexModeAutoButton.frame), 0)];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl centerInSuperviewHorizontally:NO vertically:YES];
      self->lowerBoxControlsBoxFontSizeLabel.cell.controlSize = NSMiniControlSize;
      self->lowerBoxControlsBoxFontSizeLabel.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
      [self->lowerBoxControlsBoxFontSizeLabel sizeToFit];
      self->lowerBoxControlsBoxFontSizeTextField.cell.controlSize = NSMiniControlSize;
      self->lowerBoxControlsBoxFontSizeTextField.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
      [self->lowerBoxControlsBoxFontSizeTextField sizeToFit];
      [self->lowerBoxControlsBoxFontSizeLabel setFrameOrigin:NSMakePoint(0, (self->lowerBoxControlsBoxFontSizeTextField.frame.size.height-self->lowerBoxControlsBoxFontSizeLabel.frame.size.height)/2)];
      [self->lowerBoxControlsBoxFontSizeTextField setFrameOrigin:NSMakePoint(NSMaxX(self->lowerBoxControlsBoxFontSizeLabel.frame)+2, 0)];
      self->lowerBoxControlsBoxFontColorLabel.cell.controlSize = NSMiniControlSize;
      self->lowerBoxControlsBoxFontColorLabel.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
      [self->lowerBoxControlsBoxFontColorLabel sizeToFit];
      self->lowerBoxControlsBoxFontColorWell.cell.controlSize = NSMiniControlSize;
      self->lowerBoxControlsBoxFontColorWell.frame = NSRectChange(self->lowerBoxControlsBoxFontColorWell.frame, NO, 0, YES, 0, YES, 2*self->lowerBoxControlsBoxFontSizeTextField.frame.size.height, YES, self->lowerBoxControlsBoxFontSizeTextField.frame.size.height);
      [self->lowerBoxControlsBoxFontColorLabel setFrameOrigin:
        NSMakePoint(NSMaxX(self->lowerBoxControlsBoxFontSizeTextField.frame)+2,
                    (self->lowerBoxControlsBoxFontColorWell.frame.size.height-self->lowerBoxControlsBoxFontColorLabel.frame.size.height)/2)];
      [self->lowerBoxControlsBoxFontColorWell setFrameOrigin:NSMakePoint(NSMaxX(self->lowerBoxControlsBoxFontColorLabel.frame), 0)];

      self->lowerBoxLatexizeButton.cell.controlSize = NSMiniControlSize;
      self->lowerBoxLatexizeButton.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSMiniControlSize]];
      [self->lowerBoxLatexizeButton sizeToFit];
      NSRect lowerBoxLatexizeButtonFrame = self->lowerBoxLatexizeButton.frame;
      self->lowerBoxLatexizeButton.frame = NSMakeRect(superviewFrame.size.width-lowerBoxLatexizeButtonFrame.size.width,
                                                 (self->lowerBoxControlsBoxFontColorWell.frame.size.height-lowerBoxLatexizeButtonFrame.size.height)/2,
                                                 lowerBoxLatexizeButtonFrame.size.width, lowerBoxLatexizeButtonFrame.size.height);
      lowerBoxLatexizeButtonFrame = self->lowerBoxLatexizeButton.frame;
      NSRect lowerBoxLinkbackButtonFrame = self->lowerBoxLinkbackButton.frame;
      self->lowerBoxLinkbackButton.frame = NSMakeRect(
        lowerBoxLatexizeButtonFrame.origin.x-4-lowerBoxLinkbackButtonFrame.size.width,
        lowerBoxLatexizeButtonFrame.origin.y+1+(lowerBoxLatexizeButtonFrame.size.height-lowerBoxLinkbackButtonFrame.size.height)/2,
        lowerBoxLinkbackButtonFrame.size.width, lowerBoxLinkbackButtonFrame.size.height);
                                                 
      NSPanel* miniWindow =
        [[MyDocumentPanel alloc] initWithContentRect:window.contentView.frame
                                   styleMask:NSTitledWindowMask|NSUtilityWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask
                                     backing:NSBackingStoreBuffered defer:NO];
      [miniWindow setReleasedWhenClosed:YES];
      miniWindow.delegate = (id)self;
      [miniWindow setFrameAutosaveName:[NSString stringWithFormat:@"LaTeXiT-window-%lu", (unsigned long)self->uniqueId]];
      [miniWindow setFrame:window.frame display:YES];
      [miniWindow setShowsResizeIndicator:NO];
      miniWindow.minSize = self->documentMiniMinimumSize;
      miniWindow.maxSize = self->documentMiniMinimumSize;
      miniWindow.title = self.displayName;
      NSArray* subViews = [NSArray arrayWithArray:window.contentView.subviews];
      NSEnumerator* enumerator = [subViews objectEnumerator];
      NSView* view = nil;
      while((view = [enumerator nextObject]))
      {
        [view retain];
        [view removeFromSuperview];
        [miniWindow.contentView addSubview:view];
        [view release];
      }
      NSWindowController* windowController = window.windowController;
      [self retain];
      [window setAnimationEnabled:NO];
      [window retain];
      windowController.window = miniWindow;
      windowController.document = self;
      [self release];
      miniWindow.windowController = windowController;
      [miniWindow setAnimationEnabled:NO];
      [miniWindow makeKeyAndOrderFront:nil];
      [window close];
      [window release];
      [miniWindow setAnimationEnabled:YES];
    }//end if (self->documentStyle == DOCUMENT_STYLE_MINI)
    else//if (self->documentStyle == DOCUMENT_STYLE_NORMAL)
    {
      NSRect superviewFrame = NSZeroRect;
      NSRect nextFrame      = self->documentFrameSaved;
      if (oldValue != DOCUMENT_STYLE_UNDEFINED)
      {
        NSRect previousFrame = window.frame;
        nextFrame.origin.y = previousFrame.origin.y+previousFrame.size.height-nextFrame.size.height;
        [window setShowsResizeIndicator:YES];
        window.minSize = self->documentNormalMinimumSize;
        [window setFrame:nextFrame display:YES animate:window.visible];
        NSRect newLowerBoxFrame = self->lowerBox.frame;
        newLowerBoxFrame.size.height = self->upperBox.frame.origin.y-4;
        self->lowerBox.frame = newLowerBoxFrame;

        superviewFrame = self->upperImageBox.superview.frame;
        NSRect zoomBoxFrame = self->upperBoxZoomBox.frame;
        self->upperImageBox.frame = NSMakeRect(20, 0, superviewFrame.size.width-20-zoomBoxFrame.size.width, superviewFrame.size.height-16);
        self->upperBoxZoomBox.frame = NSMakeRect(superviewFrame.size.width-zoomBoxFrame.size.width, 0, zoomBoxFrame.size.width, superviewFrame.size.height-16);
        
        ((NSScrollView*)self->upperBoxLogTableView.superview.superview).horizontalScroller.controlSize = NSRegularControlSize;
        ((NSScrollView*)self->upperBoxLogTableView.superview.superview).verticalScroller.controlSize = NSRegularControlSize;
      ((NSScrollView*)[self->upperBoxImageView.superview.superview dynamicCastToClass:[NSScrollView class]]).verticalScroller.controlSize = NSRegularControlSize;


        superviewFrame = self->lowerBox.frame;
        NSScrollView* sourceTextScrollView = (NSScrollView*)self->lowerBoxSourceTextView.superview.superview;
        self->lowerBoxSplitView.frame = NSMakeRect(20+1,  80, superviewFrame.size.width-2*(20+1), superviewFrame.size.height-80);
        self->lowerBoxSplitView.dividerThickness = -1;
        sourceTextScrollView.horizontalScroller.controlSize = NSRegularControlSize;
        sourceTextScrollView.verticalScroller.controlSize = NSRegularControlSize;
        superviewFrame = self->lowerBoxSplitView.frame;
        sourceTextScrollView.frame = NSMakeRect(0, 0, superviewFrame.size.width, superviewFrame.size.height);
        superviewFrame = self->lowerBox.frame;
        [self->lowerBoxChangePreambleButton setFrameOrigin:NSMakePoint(20, superviewFrame.size.height-self->lowerBoxChangePreambleButton.frame.size.height)];
        self->lowerBoxSplitView.frame = NSMakeRect(20+1, 80, superviewFrame.size.width-2*(20+1), superviewFrame.size.height-80);
        [self setPreambleVisible:NO animate:NO];
        [self->lowerBoxSplitView setHidden:NO];
        self->lowerBoxControlsBox.frame = NSMakeRect(0,  0, superviewFrame.size.width, 80);
      }//end if (oldValue != DOCUMENT_STYLE_UNDEFINED)

      self->lowerBoxControlsBoxLatexModeView.frame = NSMakeRect(0, 48, 342, 32);
      [self->lowerBoxControlsBoxLatexModeView centerInSuperviewHorizontally:YES vertically:NO];
      superviewFrame = self->lowerBoxControlsBoxLatexModeView.frame;
      self->lowerBoxControlsBoxLatexModeAutoButton.cell.controlSize = NSSmallControlSize;
      self->lowerBoxControlsBoxLatexModeAutoButton.font = [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSSmallControlSize]];
      [self->lowerBoxControlsBoxLatexModeAutoButton sizeToFit];
      [self->lowerBoxControlsBoxLatexModeAutoButton setFrameOrigin:NSMakePoint(6, 0)];
      [self->lowerBoxControlsBoxLatexModeAutoButton centerInSuperviewHorizontally:NO vertically:YES];
      self->lowerBoxControlsBoxLatexModeSegmentedControl.cell.controlSize = NSRegularControlSize;
      self->lowerBoxControlsBoxLatexModeSegmentedControl.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl sizeToFitWithSegmentWidth:(self->lowerBoxControlsBoxLatexModeSegmentedControlMinimumSize.width-8)/self->lowerBoxControlsBoxLatexModeSegmentedControl.segmentCount useSameSize:YES];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl setFrameSize:self->lowerBoxControlsBoxLatexModeSegmentedControlMinimumSize];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl setFrameOrigin:NSMakePoint(NSMaxX(self->lowerBoxControlsBoxLatexModeAutoButton.frame)+6, 0)];
      [self->lowerBoxControlsBoxLatexModeSegmentedControl centerInSuperviewHorizontally:NO vertically:YES];
      self->lowerBoxControlsBoxFontSizeLabel.cell.controlSize = NSRegularControlSize;
      self->lowerBoxControlsBoxFontSizeLabel.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]];
      [self->lowerBoxControlsBoxFontSizeLabel sizeToFit];
      self->lowerBoxControlsBoxFontSizeTextField.cell.controlSize = NSRegularControlSize;
      self->lowerBoxControlsBoxFontSizeTextField.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]];
      [self->lowerBoxControlsBoxFontSizeTextField sizeToFit];
      [self->lowerBoxControlsBoxFontSizeLabel setFrameOrigin:NSMakePoint(20, 15)];
      [self->lowerBoxControlsBoxFontSizeTextField setFrameOrigin:NSMakePoint(NSMaxX(self->lowerBoxControlsBoxFontSizeLabel.frame)+4, 12)];
      self->lowerBoxControlsBoxFontColorLabel.cell.controlSize = NSRegularControlSize;
      self->lowerBoxControlsBoxFontColorLabel.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]];
      [self->lowerBoxControlsBoxFontColorLabel sizeToFit];
      self->lowerBoxControlsBoxFontColorWell.cell.controlSize = NSRegularControlSize;
      [self->lowerBoxControlsBoxFontColorLabel setFrameOrigin:NSMakePoint(NSMaxX(self->lowerBoxControlsBoxFontSizeTextField.frame)+10, 15)];
      self->lowerBoxControlsBoxFontColorWell.frame = NSMakeRect(NSMaxX(self->lowerBoxControlsBoxFontColorLabel.frame)+4, 10, 52, 26);

      self->lowerBoxLatexizeButton.cell.controlSize = NSRegularControlSize;
      self->lowerBoxLatexizeButton.font = [NSFont controlContentFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]];
      [self->lowerBoxLatexizeButton sizeToFit];
      superviewFrame = self->lowerBoxControlsBoxLatexModeView.superview.frame;
      NSRect lowerBoxLatexizeButtonFrame = self->lowerBoxLatexizeButton.frame;
      self->lowerBoxLatexizeButton.frame = NSMakeRect(MAX(superviewFrame.size.width-18-lowerBoxLatexizeButtonFrame.size.width,
                                                            NSMaxX([self->lowerBoxControlsBoxLatexModeView frame])-
                                                            lowerBoxLatexizeButtonFrame.size.width), 5,
                                                        lowerBoxLatexizeButtonFrame.size.width, lowerBoxLatexizeButtonFrame.size.height);

      lowerBoxLatexizeButtonFrame = self->lowerBoxLatexizeButton.frame;
      NSRect lowerBoxLinkbackButtonFrame = self->lowerBoxLinkbackButton.frame;
      self->lowerBoxLinkbackButton.frame = NSMakeRect(
        lowerBoxLatexizeButtonFrame.origin.x+lowerBoxLatexizeButtonFrame.size.width-4,
        lowerBoxLatexizeButtonFrame.origin.y+2+(lowerBoxLatexizeButtonFrame.size.height-lowerBoxLinkbackButtonFrame.size.height)/2,
        lowerBoxLinkbackButtonFrame.size.width, lowerBoxLinkbackButtonFrame.size.height);

      if (oldValue != DOCUMENT_STYLE_UNDEFINED)
      {
        NSWindow* normalWindow =
          [[MyDocumentWindow alloc] initWithContentRect:window.frame
                                     styleMask:NSTitledWindowMask|NSClosableWindowMask|NSMiniaturizableWindowMask|NSResizableWindowMask
                                       backing:NSBackingStoreBuffered defer:NO];
        [normalWindow setReleasedWhenClosed:YES];
        normalWindow.delegate = (id)self;
        [normalWindow setFrameAutosaveName:[NSString stringWithFormat:@"LaTeXiT-window-%lu", (unsigned long)self->uniqueId]];
        [normalWindow setFrame:window.frame display:YES];
        [normalWindow setShowsResizeIndicator:YES];
        normalWindow.minSize = self->documentNormalMinimumSize;
        normalWindow.title = self.displayName;
        NSArray* subViews = [NSArray arrayWithArray:window.contentView.subviews];
        NSEnumerator* enumerator = [subViews objectEnumerator];
        NSView* view = nil;
        while((view = [enumerator nextObject]))
        {
          [view retain];
          [view removeFromSuperview];
          [normalWindow.contentView addSubview:view];
          [view release];
        }
        NSWindowController* windowController = window.windowController;
        [self retain];
        [window setAnimationEnabled:NO];
        [window retain];
        windowController.window = normalWindow;
        windowController.document = self;
        [self release];
        normalWindow.windowController = windowController;
        [normalWindow setAnimationEnabled:NO];
        [normalWindow makeKeyAndOrderFront:nil];
        [window close];
        [window release];
        [normalWindow setAnimationEnabled:YES];
      }//end if (oldValue != DOCUMENT_STYLE_UNDEFINED)
    }//end if (self->documentStyle == DOCUMENT_STYLE_NORMAL)
    [self->upperBoxImageView updateViewSize];
    
    
    NSToolbar* toolbar = [[[NSToolbar alloc] initWithIdentifier:@""] autorelease];
    toolbar.displayMode = NSToolbarDisplayModeLabelOnly;
    toolbar.sizeMode = NSToolbarSizeModeSmall;
    [toolbar setVisible:NO];
    self.windowForSheet.toolbar = toolbar;
    
    [PreferencesController sharedController].documentStyle = self->documentStyle;
  }//end if (value != self->documentStyle)
}
//end setDocumentStyle:

-(void) toggleDocumentStyle
{
  if (self->documentStyle == DOCUMENT_STYLE_NORMAL)
    self.documentStyle = DOCUMENT_STYLE_MINI;
  else
    self.documentStyle = DOCUMENT_STYLE_NORMAL;
}
//end toggleDocumentStyle

-(BOOL) windowShouldZoom:(NSWindow*)window toFrame:(NSRect)proposedFrame
{
  BOOL result = NO;
  if (!window.zoomed)
    self->unzoomedFrame = window.frame;
  else
    proposedFrame = self->unzoomedFrame;
  //OOL optionIsPressed = ((GetCurrentEventKeyModifiers() & optionKey) != 0);
  if (/*optionIsPressed &&*/ (self->documentStyle == DOCUMENT_STYLE_NORMAL))
    self.documentStyle = DOCUMENT_STYLE_MINI;
  else if (self->documentStyle == DOCUMENT_STYLE_MINI)
    self.documentStyle = DOCUMENT_STYLE_NORMAL;
  else
    result = YES;
  return result;
}
//end windowShouldZoom:toFrame:

-(void) scrollViewDidScroll:(NSNotification*)notification
{
  id sender = notification.object;
  if (sender == self->lowerBoxPreambleTextView.superview.superview)
  {
    [[self->lowerBoxPreambleTextView lineCountRulerView] setNeedsDisplay:YES];
    [self->lowerBoxChangePreambleButton setNeedsDisplay:YES];
  }
  else if (sender == self->lowerBoxSourceTextView.superview.superview)
  {
    [[self->lowerBoxSourceTextView lineCountRulerView] setNeedsDisplay:YES];
    [self->lowerBoxChangeBodyTemplateButton setNeedsDisplay:YES];
  }
}
//end scrollViewDidScroll:

//automatically called by Cocoa. The name of the document has nothing to do with a represented file
-(NSString*) displayName
{
  NSString* title = self->documentTitle;
  if (self.fileURL)
    title = super.displayName;
  else if (!title)
    title = [NSString stringWithFormat:@"%@-%lu", [[NSWorkspace sharedWorkspace] applicationName], (unsigned long)self->uniqueId];
  return title;
}
//end displayName

//updates interface to allow latexisation or not, according to current configuration
-(void) updateGUIfromSystemAvailabilities
{
  AppController* appController = [AppController appController];
  composition_mode_t compositionMode = [[PreferencesController sharedController].compositionConfigurationDocument compositionConfigurationCompositionMode];
  BOOL lowerBoxLatexizeButtonEnabled =
    (compositionMode == COMPOSITION_MODE_PDFLATEX) ? appController.pdfLaTeXAvailable && appController.gsAvailable :
    (compositionMode == COMPOSITION_MODE_XELATEX)  ? appController.pdfLaTeXAvailable && appController.xeLaTeXAvailable && appController.gsAvailable :
    (compositionMode == COMPOSITION_MODE_LUALATEX) ? appController.pdfLaTeXAvailable && appController.luaLaTeXAvailable && appController.gsAvailable :
    (compositionMode == COMPOSITION_MODE_LATEXDVIPDF) ? appController.laTeXAvailable && appController.dviPdfAvailable && appController.gsAvailable :
    NO;    
  self->lowerBoxLatexizeButton.enabled = lowerBoxLatexizeButtonEnabled;
  [self->lowerBoxLatexizeButton setNeedsDisplay:YES];
  if (lowerBoxLatexizeButtonEnabled)
    [self->lowerBoxLatexizeButton setToolTip:nil];
  else if (!self->lowerBoxLatexizeButton.toolTip)
    [self->lowerBoxLatexizeButton setToolTip:
      NSLocalizedString(@"pdflatex, latex, dvipdf, xelatex, lualatex or gs (depending to the current configuration) seems unavailable in your system. Please check their installation.",
                        @"pdflatex, latex, dvipdf, xelatex, lualatex or gs (depending to the current configuration) seems unavailable in your system. Please check their installation.")];
  
  BOOL colorStyEnabled = appController.colorStyAvailable;
  self->lowerBoxControlsBoxFontColorWell.enabled = colorStyEnabled;
  [self->lowerBoxControlsBoxFontColorWell setNeedsDisplay:YES];
  if (colorStyEnabled)
    [self->lowerBoxControlsBoxFontColorWell setToolTip:nil];
  else if (!self->lowerBoxControlsBoxFontColorWell.toolTip)
    [self->lowerBoxControlsBoxFontColorWell setToolTip:
      NSLocalizedString(@"color.sty package seems not to be present in your LaTeX installation. "\
                        @"So, color font change is disabled.",
                        @"color.sty package seems not to be present in your LaTeX installation. "\
                        @"So, color font change is disabled.")];

  [self.windowForSheet display];
}
//end updateGUIfromSystemAvailabilities

-(NSData*) dataOfType:(NSString *)typeName error:(NSError * _Nullable *)outError
{
  return nil;
}
//end dataOfType:error:

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
    if (UTTypeConformsTo((CFStringRef)self->initialUTI, kUTTypeRTF))
    {
      NSData* data = [NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error];
      NSString* string = [[[NSAttributedString alloc] initWithRTF:data documentAttributes:nil] autorelease].string;
      [self _decomposeString:string preamble:&self->initialPreamble body:&self->initialBody];
    }//end if (UTTypeConformsTo((CFStringRef)self->initialUTI, kUTTypeRTF))
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, kUTTypePDF))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, kUTTypeTIFF))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, kUTTypePNG))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, kUTTypeJPEG))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, kUTTypeHTML))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else if (UTTypeConformsTo((CFStringRef)self->initialUTI, kUTTypeScalableVectorGraphics))
      self->initialData = [[NSData dataWithContentsOfURL:absoluteURL options:NSUncachedRead error:&error] copy];
    else //by default, we suppose that it is a plain text file
    {
      NSStringEncoding encoding = NSMacOSRomanStringEncoding;
      NSError* error = nil;
      NSString* string = [NSString stringWithContentsOfFile:absoluteURL.path guessEncoding:&encoding error:&error];
      if (error)
        [self presentError:error];
      [self _decomposeString:string preamble:&self->initialPreamble body:&self->initialBody];
    }//end if plain text
    ok = self->initialData || self->initialPreamble || self->initialBody;
  }//end if (![typeName isEqualToString:@"LatexPalette"])
  return ok;
}
//end readFromURL:ofType:error:

-(void) _decomposeString:(NSString*)string preamble:(NSString**)outPreamble body:(NSString**)outBody
{
  //if a text document is opened, try to split it into preamble+body
  if (string)
  {
    NSArray* components =
    [string captureComponentsMatchedByRegex:@"^\\s*(.*)\\s*\\\\begin\\{document\\}\\s*(.*)\\s*\\\\end\\{document\\}.*$"
                                    options:RKLDotAll range:NSMakeRange(0, string.length) error:nil];
    BOOL hasPreambleAndBody = (components.count == 3);
    NSString* preamble = !hasPreambleAndBody ? nil : components[1];
    NSString* body = !hasPreambleAndBody ? string : components[2];
    if (outPreamble)
      *outPreamble = [preamble copy];
    if (outBody)
      *outBody = [body copy];
  }//end if string
}
//end _decomposeString:preamble:body:

//when the linecount changes in the preamble view, the numerotation must change in the body view
-(void) _lineCountDidChange:(NSNotification*)aNotification
{
  //registered only for preambleTextView
  self->lowerBoxSourceTextView.lineShift = [self->lowerBoxPreambleTextView lineRanges].count;
}
//end _lineCountDidChange:

-(void) setFont:(NSFont*)font//changes the font of both preamble and sourceText views
{
  self->lowerBoxPreambleTextView.textStorage.font = font;
  self->lowerBoxSourceTextView.textStorage.font = font;
}
//end setFont:

-(void) setPreamble:(NSAttributedString*)aString
{
  [self->lowerBoxPreambleTextView clearErrors];
  [self->lowerBoxPreambleTextView setAttributedString:aString];
  [[self->lowerBoxPreambleTextView syntaxColouring] recolourCompleteDocument];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:self->lowerBoxPreambleTextView];
  [self->lowerBoxPreambleTextView setNeedsDisplay:YES];
}
//end setPreamble:

-(void) setSourceText:(NSAttributedString*)aString
{
  [[self.undoManager prepareWithInvocationTarget:self]
    setSourceText:[[self->lowerBoxSourceTextView.textStorage copy] autorelease]];
  [self->lowerBoxSourceTextView clearErrors];
  [self->lowerBoxSourceTextView.textStorage setAttributedString:(aString ? aString : [[[NSAttributedString alloc] init] autorelease])];
  [[self->lowerBoxSourceTextView syntaxColouring] recolourCompleteDocument];
  [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification object:self->lowerBoxSourceTextView];
  [self->lowerBoxSourceTextView setNeedsDisplay:YES];
}
//end setSourceText:

-(void) setBodyTemplate:(NSDictionary*)bodyTemplate moveCursor:(BOOL)moveCursor
{
  //get rid of previous bodyTemplate
  NSAttributedString* currentBody = self->lowerBoxSourceTextView.textStorage;
  id rawHead = self->lastRequestedBodyTemplate[@"head"];
  NSAttributedString* head = [rawHead isKindOfClass:[NSAttributedString class]] ? rawHead :
                             [rawHead isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawHead] :
                             nil;
  id rawTail = self->lastRequestedBodyTemplate[@"tail"];
  NSAttributedString* tail = [rawTail isKindOfClass:[NSAttributedString class]] ? rawTail :
                             [rawTail isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawTail] :
                             nil;
  NSString* currentBodyString = currentBody.string;
  NSString* headString = head.string;
  NSString* tailString = tail.string;
  NSString* regexString = [NSString stringWithFormat:@"^[\\s\\n]*\\Q%@\\E[\\s\\n]*(.*)[\\s\\n]*\\Q%@\\E[\\s\\n]*$", headString, tailString];
  NSError* error = nil;
  NSString* innerBody = [currentBodyString stringByMatching:regexString options:RKLMultiline|RKLDotAll inRange:NSMakeRange(0, currentBodyString.length)
                                                    capture:1 error:&error];
  currentBodyString = !innerBody ? currentBodyString : innerBody;

   //replace current body template
  [self->lastRequestedBodyTemplate release];
  self->lastRequestedBodyTemplate = [bodyTemplate deepCopy];

  rawHead = self->lastRequestedBodyTemplate[@"head"];
  head    = [rawHead isKindOfClass:[NSAttributedString class]] ? rawHead :
              [rawHead isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawHead] :
              nil;
  rawTail = self->lastRequestedBodyTemplate[@"tail"];
  tail    = [rawTail isKindOfClass:[NSAttributedString class]] ? rawTail :
               [rawTail isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawTail] :
               nil;
  headString = head.string;
  tailString = tail.string;
  NSString* trimmedHead = [headString trim];
  NSString* trimmedTail = [tailString trim];
  NSString* trimmedCurrentBody = [currentBodyString trim];
  NSMutableAttributedString* newBody = [[[NSMutableAttributedString alloc] init] autorelease];
  if (trimmedHead && ![trimmedCurrentBody startsWith:trimmedHead options:0])
    [newBody appendAttributedString:head];
  [newBody appendAttributedString:[[[NSAttributedString alloc] initWithString:trimmedCurrentBody] autorelease]];
  if (trimmedTail && ![trimmedCurrentBody endsWith:trimmedTail options:0])
    [newBody appendAttributedString:tail];
  
  NSMutableDictionary* typingAttributes = [NSMutableDictionary dictionaryWithDictionary:self->lowerBoxPreambleTextView.typingAttributes];
  NSFont* defaultFont = [PreferencesController sharedController].editionFont;
  typingAttributes[NSFontAttributeName] = defaultFont;
  [newBody addAttributes:typingAttributes range:NSMakeRange(0, newBody.length)];
  [self setSourceText:newBody];
  if (moveCursor)
    [self->lowerBoxSourceTextView setSelectedRange:NSMakeRange(headString.length, 0)];
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
  NSArray* result = !self->poolOfObsoleteUniqueIds.count ? nil :
  [fileManager contentsOfDirectoryAtPath:workingDirectory error:&error];
  NSUInteger count = result.count;
  if (count)
  {
    NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
    @synchronized(self->poolOfObsoleteUniqueIds)
    {
      while(count--)
      {
        NSString* filename = result[count];
        NSEnumerator* enumerator = [self->poolOfObsoleteUniqueIds objectEnumerator];
        NSString* obsoleteUniqueId = nil;
        while((obsoleteUniqueId = [enumerator nextObject]))
        {
          if ([filename isMatchedByRegex:[NSString stringWithFormat:@"^\\Q%@\\E.*", obsoleteUniqueId]])
            [fileManager removeItemAtPath:[workingDirectory stringByAppendingPathComponent:filename] error:0];
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
  if (self.busy)
    [self setBusyIdentifier:nil];//will cancel result
  else//if (![self isBusy])
  {
    [self->lowerBoxControlsBoxFontSizeTextField validateEditing];
    NSDictionary* configuration =
      @{@"runBegin": @YES,
        @"applyToPasteboard": @(self->shouldApplyToPasteboardAfterLatexization)};
    [self latexizeCoreRunWithConfiguration:configuration];
  }//end if (![self isBusy])
}
//end latexize:

-(void) waitLatexizationDidEnd:(NSNotification*)notification
{
  NSDictionary* configuration = notification.object;
  id document = configuration[@"document"];
  if (self == document)
  {
    @synchronized(self){
      --self->nbBackgroundLatexizations;
    }
    NSString* previousUniqueId = configuration[@"uniqueIdentifier"];
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
          configuration2[@"runBegin"] = @NO;
          configuration2[@"runEnd"] = @YES;
          [self performSelectorOnMainThread:@selector(latexizeCoreRunWithConfiguration:) withObject:configuration2 waitUntilDone:NO];
        }//end if ([self->busyIdentifier isEqualToString:previousUniqueId])
      }
    }//end if (!self->isClosed)
  }//end if (self == document)
}
//end waitLatexizationDidEnd:

-(void) latexizeCoreRunWithConfiguration:(NSDictionary*)configuration
{
  BOOL runBegin = [configuration[@"runBegin"] boolValue];
  BOOL runEnd   = [configuration[@"runEnd"] boolValue];
  BOOL applyToPasteboard  = [configuration[@"applyToPasteboard"] boolValue];

  NSString* body = self->lowerBoxSourceTextView.string;
  BOOL mustProcess = runEnd || (body && body.length);

  if (runBegin && !mustProcess)
  {
    NSAlert* alert = [NSAlert new];
    alert.messageText = NSLocalizedString(@"Empty LaTeX body", @"Empty LaTeX body");
    alert.informativeText = NSLocalizedString(@"You did not type any text in the body. The result will certainly be empty.",
                                              @"You did not type any text in the body. The result will certainly be empty.");
    [alert addButtonWithTitle:NSLocalizedString(@"Process anyway", @"Process anyway")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
    
    NSInteger result = [alert runModal];
    [alert release];
    mustProcess = (result == NSAlertFirstButtonReturn);
  }//end if (runBegin && !mustProcess)
  
  if (runBegin && mustProcess)
  {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:ShowWhiteColorWarningKey] &&
        [self->lowerBoxControlsBoxFontColorWell.color isRGBEqualTo:[NSColor whiteColor]])
    {
      [self->lowerBoxControlsBoxFontColorWell deactivate];
      [[[AppController appController] whiteColorWarningWindow] center];
      NSInteger result = [NSApp runModalForWindow:[[AppController appController] whiteColorWarningWindow]];
      if (result == NSModalResponseCancel)
        mustProcess = NO;
    }
  }//end if (runBegin && mustProcess)

  NSArray*  errors     = configuration[@"outErrors"];
  NSString* outFullLog = configuration[@"outFullLog"];
  NSData*   pdfData    = configuration[@"outPdfData"];

  NSString* uniqueIdentifier = nil;
  if (runBegin && mustProcess)
  {
    @synchronized(self){
      if (!self->nbBackgroundLatexizations)
      {
        uniqueIdentifier = [NSString stringWithFormat:@"latexit-%lu", (unsigned long)self->uniqueId];
      }
      else//if (self->nbBackgroundLatexizations)
      {
        @synchronized(self->poolOfObsoleteUniqueIds){
          if (self->poolOfObsoleteUniqueIds.count)
          {
            uniqueIdentifier = [[self->poolOfObsoleteUniqueIds.lastObject retain] autorelease];
            [self->poolOfObsoleteUniqueIds removeLastObject];
          }
          else
          {
            CFUUIDRef uuid = CFUUIDCreate(kCFAllocatorDefault);
            CFStringRef uuidString = CFUUIDCreateString(kCFAllocatorDefault, uuid);
            if (uuid) CFRelease(uuid);
            uniqueIdentifier = [NSString stringWithFormat:@"latexit-%lu-%@", (unsigned long)self->uniqueId, !uuidString ? @"" : (NSString*)uuidString];
            if (uuidString) CFRelease(uuidString);
          }
        }
      }//end if (self->isBackgroundLatexizing)
    }//end @synchronized(self)

    PreferencesController* preferencesController = [PreferencesController sharedController];
    [self->upperBoxImageView setPDFData:nil cachedImage:nil];       //clears current image
    [self->upperBoxImageView setBackgroundColor:preferencesController.documentImageViewBackgroundColor
                              updateHistoryItem:NO];
    if (preferencesController.documentUseAutomaticHighContrastedPreviewBackground)
      [self->upperBoxImageView setBackgroundColor:nil updateHistoryItem:NO];
    [self->upperBoxImageView setNeedsDisplay:YES];
    [self->upperBoxImageView displayIfNeeded]; //refresh it
    [self setBusyIdentifier:uniqueIdentifier];
  }//end if (runBegin && mustProcess)

  if (runBegin && mustProcess)
  {
    PreferencesController* preferencesController = [PreferencesController sharedController];

    //computes the parameters thanks to the value of the GUI elements
    NSString* preamble = [[self->lowerBoxPreambleTextView.string mutableCopy] autorelease];
    NSColor* color = [[self->lowerBoxControlsBoxFontColorWell.color copy] autorelease];
    latex_mode_t mode = (latex_mode_t) self->lowerBoxControlsBoxLatexModeSegmentedControl.selectedSegmentTag;
    
    //perform effective latexisation

    NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
    
    [self removeObsoleteFiles];

    NSDictionary* fullEnvironment = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];
    
    CGFloat leftMargin   = [AppController appController].marginsCurrentLeftMargin;
    CGFloat rightMargin  = [AppController appController].marginsCurrentRightMargin;
    CGFloat bottomMargin = [AppController appController].marginsCurrentBottomMargin;
    CGFloat topMargin    = [AppController appController].marginsCurrentTopMargin;

    NSMutableDictionary* configuration = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:
      @YES, @"runInBackgroundThread",
      self, @"document",
      preamble, @"preamble", body, @"body", color, @"color", [NSNumber numberWithInt:mode], @"mode",
      @(self->lowerBoxControlsBoxFontSizeTextField.doubleValue), @"magnification",
      preferencesController.compositionConfigurationDocument, @"compositionConfiguration",
      !self->upperBoxImageView.backgroundColor ? (id)[NSNull null] : (id)self->upperBoxImageView.backgroundColor, @"backgroundColor",
      @(leftMargin), @"leftMargin",
      @(rightMargin), @"rightMargin",
      @(topMargin), @"topMargin",
      @(bottomMargin), @"bottomMargin",
      [[AppController appController] additionalFilesPaths], @"additionalFilesPaths",
      !workingDirectory ? @"" : workingDirectory, @"workingDirectory",
      !fullEnvironment ? @{} : fullEnvironment, @"fullEnvironment",
      !uniqueIdentifier ? @"" : uniqueIdentifier, @"uniqueIdentifier",
      !outFullLog ? @"" : outFullLog, @"outFullLog",
      !errors ? @[] : errors, @"outErrors",
      !pdfData ? [NSData data] : pdfData, @"outPdfData",
      @(applyToPasteboard), @"applyToPasteboard",
      nil] autorelease];
    @synchronized(self){
      ++self->nbBackgroundLatexizations;
    }
    [[LaTeXProcessor sharedLaTeXProcessor] latexiseWithConfiguration:configuration];
  }//end if (runBegin && mustProcess)

  if (runEnd && mustProcess)
  {
    [self->lastExecutionLog setString:outFullLog];
    self->documentExtraPanelsController.log = self->lastExecutionLog;//self->documentExtraPanelsController may be nil
    [self _analyzeErrors:errors];

    //did it work ?
    BOOL failed = !pdfData || !pdfData.length || self->upperBoxLogTableView.numberOfRows;
    if (failed)
    {
      if (!self->upperBoxLogTableView.numberOfRows ) //unexpected error...
        [self->upperBoxLogTableView setErrors:
          @[[NSString stringWithFormat:@"::%@",
              NSLocalizedString(@"unexpected error, please see \"LaTeX > Display last log\"",
                                @"unexpected error, please see \"LaTeX > Display last log\"")]]];
    }//end if (failed)
    else//if (!failed)
    {
      //if it is ok, updates the image view
      [self->upperBoxImageView setPDFData:pdfData cachedImage:nil];
      if (applyToPasteboard)
        [self->upperBoxImageView copy:nil];
      self->currentEquationIsARecentLatexisation = YES;

      //and insert a new element into the history
      LatexitEquation* latexitEquation = [self latexitEquationWithCurrentStateTransient:NO];
      
      PreferencesController* preferencesController = [PreferencesController sharedController];
      if (preferencesController.documentUseAutomaticHighContrastedPreviewBackground)
      {
        NSColor* latexitEquationBackgroundColor = latexitEquation.backgroundColor;
        if (!latexitEquationBackgroundColor)
          latexitEquationBackgroundColor = [NSColor whiteColor];
        CGFloat grayLevelOfBackgroundColorToApply = [latexitEquationBackgroundColor grayLevel];
        CGFloat grayLevelOfTextColor              = [latexitEquation.color grayLevel];
        if ((grayLevelOfBackgroundColorToApply < .5) && (grayLevelOfTextColor < .5))
          latexitEquationBackgroundColor = [NSColor whiteColor];
        else if ((grayLevelOfBackgroundColorToApply > .5) && (grayLevelOfTextColor > .5))
          latexitEquationBackgroundColor = [NSColor blackColor];
        latexitEquation.backgroundColor = latexitEquationBackgroundColor;
      }

      if (![PreferencesController sharedController].historySmartEnabled)
      {
        [[AppController appController] addEquationToHistory:latexitEquation];
      }
      [self->upperBoxImageView setBackgroundColor:latexitEquation.backgroundColor updateHistoryItem:NO];
      [[[AppController appController] historyWindowController] deselectAll:0];
      [self.undoManager disableUndoRegistration];
      [self applyLatexitEquation:latexitEquation isRecentLatexisation:YES];
      [self.undoManager enableUndoRegistration];
      
      //reupdate for easter egg
      [self->upperBoxImageView setPDFData:latexitEquation.pdfData cachedImage:[self _checkEasterEgg]];

      //updates the pasteboard content for a live Linkback link, and triggers a sendEdit
      if (self.linkBackAllowed)
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
  if (self.canReexport)
    [self reexportImage:sender];
}
//end latexizeAndExport:

-(latex_mode_t) latexModeApplied
{
  latex_mode_t result = self->latexModeApplied;
  return result;
}
//end latexModeApplied

-(IBAction) changeLatexModeAuto:(id)sender
{
  BOOL isAuto = (((NSButton*)sender).state == NSOnState);
  self.latexModeRequested = isAuto ? LATEX_MODE_AUTO : [self detectLatexMode];
}
//end changeLatexModeAuto:(id)sender

-(void) setLatexModeApplied:(latex_mode_t)value
{
  [self willChangeValueForKey:@"latexModeApplied"];
  self->latexModeApplied = value;
  NSSegmentedCell* segmentedCell = self->lowerBoxControlsBoxLatexModeSegmentedControl.cell;
  NSInteger i = 0;
  for(i = 0 ; i<self->lowerBoxControlsBoxLatexModeSegmentedControl.segmentCount ; ++i)
  {
    NSInteger tagForSegment = [segmentedCell tagForSegment:i];
    [self->lowerBoxControlsBoxLatexModeSegmentedControl setSelected:(tagForSegment == (signed)self->latexModeApplied) forSegment:i];
  }//end for each segment
  [self didChangeValueForKey:@"latexModeApplied"];
}
//end setLatexModeApplied:

-(latex_mode_t) latexModeRequested
{
  latex_mode_t result = self->latexModeRequested;
  return result;
}
//end latexModeRequested

-(void) setLatexModeRequested:(latex_mode_t)value
{
  [self willChangeValueForKey:@"latexModeRequested"];
  self->latexModeRequested = value;
  BOOL newModeIsAuto = (self->latexModeRequested == LATEX_MODE_AUTO);
  self->lowerBoxControlsBoxLatexModeSegmentedControl.enabled = !newModeIsAuto;
  NSInteger i = 0;
  for(i = 0 ; i<self->lowerBoxControlsBoxLatexModeSegmentedControl.segmentCount ; ++i)
    [self->lowerBoxControlsBoxLatexModeSegmentedControl setEnabled:!newModeIsAuto forSegment:i];

  self->lowerBoxControlsBoxLatexModeAutoButton.state = newModeIsAuto ? NSOnState : NSOffState;
  /*[[self->lowerBoxControlsBoxLatexModeSegmentedControl cell] setTrackingMode:
    newModeIsAuto ? NSSegmentSwitchTrackingSelectAny : NSSegmentSwitchTrackingSelectOne];
  [self->lowerBoxControlsBoxLatexModeSegmentedControl setEnabled:!newModeIsAuto forSegment:1];
  [self->lowerBoxControlsBoxLatexModeSegmentedControl setEnabled:!newModeIsAuto forSegment:2];
  [self->lowerBoxControlsBoxLatexModeSegmentedControl setEnabled:!newModeIsAuto forSegment:3];
  [self->lowerBoxControlsBoxLatexModeSegmentedControl setEnabled:!newModeIsAuto forSegment:4];*/
  [self->lowerBoxControlsBoxLatexModeSegmentedControl selectSegmentWithTag:self->latexModeRequested];
  if (!newModeIsAuto)
    self.latexModeApplied = self.latexModeRequested;
  [self didChangeValueForKey:@"latexModeRequested"];
  [self bodyTextDidChange:nil];
}
//end setLatexModeRequested:

-(IBAction) changeRequestedLatexMode:(id)sender
{
  if (sender == self->lowerBoxControlsBoxLatexModeSegmentedControl)
  {
    NSInteger lastClickedSegment = self->lowerBoxControlsBoxLatexModeSegmentedControl.selectedSegment;
    self.latexModeRequested = (latex_mode_t)[self->lowerBoxControlsBoxLatexModeSegmentedControl.cell tagForSegment:lastClickedSegment];
  }//end if (sender == self->lowerBoxControlsBoxLatexModeSegmentedControl)
}
//end changeRequestedLatexMode:

-(void) setColor:(NSColor*)color
{
  self->lowerBoxControlsBoxFontColorWell.color = color;
}
//end setColor:

-(void) setMagnification:(CGFloat)magnification
{
  self->lowerBoxControlsBoxFontSizeTextField.floatValue = magnification;
}
//end setMagnification:

//This will update the error tableview, filling it with the filtered log obtained during the latexisation, and add error markers
//in the rulertextviews
-(void) _analyzeErrors:(NSArray*)errors
{
  [self->upperBoxLogTableView setErrors:errors];
  
  [self->lowerBoxPreambleTextView clearErrors];
  [self->lowerBoxSourceTextView clearErrors];
  NSInteger numberOfRows = self->upperBoxLogTableView.numberOfRows;
  NSInteger i = 0;
  for(i = 0 ; i<numberOfRows ; ++i)
  {
    NSNumber* lineNumber = [self->upperBoxLogTableView tableView:self->upperBoxLogTableView
                            objectValueForTableColumn:[self->upperBoxLogTableView tableColumnWithIdentifier:@"line"] row:i];
    NSString* message = [self->upperBoxLogTableView tableView:self->upperBoxLogTableView
                      objectValueForTableColumn:[self->upperBoxLogTableView tableColumnWithIdentifier:@"message"] row:i];
    NSInteger line = lineNumber.integerValue;
    NSInteger nbLinesInUserPreamble = [self->lowerBoxPreambleTextView nbLines];
    if (line <= nbLinesInUserPreamble)
      [self->lowerBoxPreambleTextView setErrorAtLine:line message:message];
    else
      [self->lowerBoxSourceTextView setErrorAtLine:line message:message];
  }
}
//end _analyzeErrors:

-(BOOL) hasImage
{
  return (self->upperBoxImageView.image != nil);
}
//end hasImage

-(BOOL) isPreambleVisible
{
  //[[preambleTextView superview] superview] is a scrollview that is a subView of splitView
  return (self->lowerBoxPreambleTextView.superview.superview.frame.size.height > 0);
}
//end isPreambleVisible

-(void) setPreambleVisible:(BOOL)visible animate:(BOOL)animate
{
  if (!(visible && self.preambleVisible)) //if preamble is already visible and visible is YES, do nothing
  {
    //[[preambleTextView superview] superview] and [[sourceTextView superview] superview] are scrollviews that are subViews of splitView
    NSView* preambleView = self->lowerBoxPreambleTextView.superview.superview;
    NSView* sourceView   = self->lowerBoxSourceTextView.superview.superview;
    NSRect preambleFrame = preambleView.frame;
    NSRect sourceFrame = sourceView.frame;
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
      preambleView.frame = newPreambleFrame; 
      sourceView.frame = newSourceFrame; 
      [self->lowerBoxSplitView adjustSubviews]; 
      [self->lowerBoxSplitView displayIfNeeded];
      if (animate)
      {
        [NSThread sleepUntilDate:[[NSDate date] dateByAddingTimeInterval:1/100.0f]];
      }//end if (animate)
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
  BOOL automaticHighContrastedPreviewBackground = preferencesController.documentUseAutomaticHighContrastedPreviewBackground;
  NSColor* backgroundColor = /*!automaticHighContrastedPreviewBackground ? nil :*/ self->upperBoxImageView.backgroundColor;
  result = //self->linkedLibraryEquation ? [self->linkedLibraryEquation equation] :
      !transient ?
    [[[LatexitEquation alloc] initWithPDFData:self->upperBoxImageView.pdfData useDefaults:YES] autorelease] :
    [[[LatexitEquation alloc] initWithPDFData:self->upperBoxImageView.pdfData
                                     preamble:[[self->lowerBoxPreambleTextView.textStorage mutableCopy] autorelease]
                                   sourceText:[[self->lowerBoxSourceTextView.textStorage mutableCopy] autorelease]
                                        color:self->lowerBoxControlsBoxFontColorWell.color
                                    pointSize:self->lowerBoxControlsBoxFontSizeTextField.doubleValue date:[NSDate date]
                                         mode:self.latexModeApplied
                              backgroundColor:backgroundColor] autorelease];
  if (backgroundColor)
    result.backgroundColor = backgroundColor;
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
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypePDF))
  {
    NSString* pdfString = CGPDFDocumentCreateStringRepresentationFromData(data);
    ok = pdfString && ![pdfString isEqualToString:@""];
    if (pdfString && ![pdfString isEqualToString:@""])
      [self applyString:pdfString];
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypePDF))
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.tex")))
  {
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    ok = (string != nil);
    if (ok)
      [self updateDocumentFromString:string updatePreamble:YES updateEnvironment:YES updateBody:YES];
    [string release];
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, CFSTR("public.tex")))
  else if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeText))
  {
    NSString* string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    ok = (string != nil);
    if (ok)
      [self applyString:string];
    [string release];
  }//end if (UTTypeConformsTo((CFStringRef)sourceUTI, kUTTypeText))
  return ok;
}
//end applyData:sourceUTI:

-(void) applyString:(NSString*)string
{
  [[self.undoManager prepareWithInvocationTarget:self] applyLatexitEquation:[self latexitEquationWithCurrentStateTransient:YES]  isRecentLatexisation:self->currentEquationIsARecentLatexisation];
  NSArray* components =
    [string captureComponentsMatchedByRegex:@"^\\s*(.*)\\s*\\\\begin\\{document\\}\\s*(.*)\\s*\\\\end\\{document\\}.*$"
                                    options:RKLDotAll range:NSMakeRange(0, string.length) error:nil];
  BOOL hasPreambleAndBody = (components.count == 3);
  NSString* preamble = !hasPreambleAndBody ? nil : components[1];
  NSString* body = !hasPreambleAndBody ? string : components[2];
  if (preamble)
    [self setPreamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]];
  if (body)
    [self setSourceText:[[[NSAttributedString alloc] initWithString:body] autorelease]];
}
//end applyString:

//updates the document according to the given library file
-(void) applyLibraryEquation:(LibraryEquation*)libraryEquation
{
  [self applyLatexitEquation:libraryEquation.equation isRecentLatexisation:NO]; //sets lastAppliedLibraryEquation to nil
  self.lastAppliedLibraryEquation = libraryEquation;
}
//end applyLibraryEquation:

//sets the state of the document
-(void) applyLatexitEquation:(LatexitEquation*)latexitEquation isRecentLatexisation:(BOOL)isRecentLatexisation
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  [[self.undoManager prepareWithInvocationTarget:self] applyLatexitEquation:[self latexitEquationWithCurrentStateTransient:YES] isRecentLatexisation:self->currentEquationIsARecentLatexisation];
  [[self.undoManager prepareWithInvocationTarget:self] setLastAppliedLibraryEquation:self.lastAppliedLibraryEquation];
  [self setLastAppliedLibraryEquation:nil];
  self->currentEquationIsARecentLatexisation = isRecentLatexisation;
  if (latexitEquation)
  {
    if (self->linkedLibraryEquation && (latexitEquation != self->linkedLibraryEquation.equation))
    {
      LatexitEquation* linkedEquation = self->linkedLibraryEquation.equation;
      [linkedEquation beginUpdate];
      linkedEquation.pdfData = latexitEquation.pdfData;
      linkedEquation.preamble = latexitEquation.preamble;
      linkedEquation.sourceText = latexitEquation.sourceText;
      linkedEquation.color = latexitEquation.color;
      linkedEquation.baseline = latexitEquation.baseline;
      linkedEquation.pointSize = latexitEquation.pointSize;
      linkedEquation.date = latexitEquation.date;
      linkedEquation.mode = latexitEquation.mode;
      linkedEquation.backgroundColor = latexitEquation.backgroundColor;
      linkedEquation.title = latexitEquation.title;
      [linkedEquation endUpdate];
      latexitEquation = linkedEquation;
      LibraryWindowController* libraryWindowController = [[AppController appController] libraryWindowController];
      [libraryWindowController blink:self->linkedLibraryEquation];
    }//end if (self->linkedLibraryEquation && (latexitEquation != [self->linkedLibraryEquation equation]))

    self->lastFirstResponder = self.windowForSheet.firstResponder;
    if ((self->lastFirstResponder != self->lowerBoxPreambleTextView) &&
        (self->lastFirstResponder != self->lowerBoxSourceTextView))
      self->lastFirstResponder = nil;
    [self.windowForSheet makeFirstResponder:self->upperBoxImageView];

    [self _setLogTableViewVisible:NO];
    [self->upperBoxImageView setPDFData:latexitEquation.pdfData cachedImage:[latexitEquation pdfCachedImage]];

    NSParagraphStyle* paragraphStyle = self->lowerBoxPreambleTextView.defaultParagraphStyle;
    [self setPreamble:latexitEquation.preamble];
    [self setSourceText:latexitEquation.sourceText];
    [self->lowerBoxPreambleTextView.textStorage addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, self->lowerBoxPreambleTextView.textStorage.length)];
    [self->lowerBoxSourceTextView.textStorage   addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, self->lowerBoxSourceTextView.textStorage.length)];

    [self->lowerBoxControlsBoxFontColorWell deactivate];
    NSColor* latexitEquationColor = latexitEquation.color;
    if (latexitEquationColor)
      self->lowerBoxControlsBoxFontColorWell.color = latexitEquationColor;
    self->lowerBoxControlsBoxFontSizeTextField.doubleValue = latexitEquation.pointSize;
    if (latexitEquation.mode != LATEX_MODE_AUTO)
    {
      self->lowerBoxControlsBoxLatexModeAutoButton.state = NSOffState;
      [self->lowerBoxControlsBoxLatexModeSegmentedControl selectSegmentWithTag:latexitEquation.mode];
    }//end if ([latexitEquation mode] != LATEX_MODE_AUTO)
    else//if ([latexitEquation mode] == LATEX_MODE_AUTO)
    {
      self->lowerBoxControlsBoxLatexModeAutoButton.state = NSOnState;
      if (self->lowerBoxControlsBoxLatexModeSegmentedControl.selectedSegment)
        [self->lowerBoxControlsBoxLatexModeSegmentedControl setSelected:NO forSegment:self->lowerBoxControlsBoxLatexModeSegmentedControl.selectedSegment];
    }//end if ([latexitEquation mode] == LATEX_MODE_AUTO)
    NSColor* latexitEquationBackgroundColor = latexitEquation.backgroundColor;
    NSColor* greyLevelLatexitEquationBackgroundColor = latexitEquationBackgroundColor ? [latexitEquationBackgroundColor colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] : [NSColor whiteColor];
    latexitEquationBackgroundColor = (greyLevelLatexitEquationBackgroundColor.whiteComponent == 1.0f) ? nil : latexitEquationBackgroundColor;
    NSColor* colorFromUserDefaults = preferencesController.documentImageViewBackgroundColor;
    if (!latexitEquationBackgroundColor)
      latexitEquationBackgroundColor = colorFromUserDefaults;
    [self->upperBoxImageView setBackgroundColor:latexitEquationBackgroundColor updateHistoryItem:NO];
    if (self->backSyncFilePath)
      [self save:self];
  }
  else
  {
    [self _setLogTableViewVisible:NO];
    [self->upperBoxImageView setPDFData:nil cachedImage:nil];
    NSFont* defaultFont = preferencesController.editionFont;

    NSParagraphStyle* paragraphStyle = self->lowerBoxPreambleTextView.defaultParagraphStyle;
    [self->lowerBoxPreambleTextView.textStorage addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, self->lowerBoxPreambleTextView.textStorage.length)];
    [self->lowerBoxSourceTextView.textStorage   addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, self->lowerBoxSourceTextView.textStorage.length)];

    NSMutableDictionary* typingAttributes = [NSMutableDictionary dictionaryWithDictionary:self->lowerBoxPreambleTextView.typingAttributes];
    typingAttributes[NSFontAttributeName] = defaultFont;
    self->lowerBoxPreambleTextView.typingAttributes = typingAttributes;
    self->lowerBoxSourceTextView.typingAttributes = typingAttributes;
    [self setPreamble:[[AppController appController] preambleLatexisationAttributedString]];
    [self setSourceText:[[[NSAttributedString alloc ] init] autorelease]];
    [self->lowerBoxPreambleTextView.textStorage addAttributes:typingAttributes range:NSMakeRange(0, self->lowerBoxPreambleTextView.textStorage.length)];
    [self->lowerBoxSourceTextView.textStorage   addAttributes:typingAttributes range:NSMakeRange(0, self->lowerBoxSourceTextView.textStorage.length)];
    [self->lowerBoxControlsBoxFontColorWell deactivate];
    self->lowerBoxControlsBoxFontColorWell.color = preferencesController.latexisationFontColor;
    self->lowerBoxControlsBoxFontSizeTextField.doubleValue = preferencesController.latexisationFontSize;
    self.latexModeRequested = preferencesController.latexisationLaTeXMode;
    [self->upperBoxImageView setBackgroundColor:preferencesController.documentImageViewBackgroundColor
                              updateHistoryItem:NO];
  }
}
//end applyLatexitEquation:isRecentLatexisation:

//calls the log window
-(IBAction) displayLastLog:(id)sender
{
  DocumentExtraPanelsController* controller = [self lazyDocumentExtraPanelsController];
  controller.log = self->lastExecutionLog;
  [controller.logWindow makeKeyAndOrderFront:self];
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
  if (sender.menu == self->lowerBoxChangePreambleButton.cell.menu)
    ok = (sender.action != nil);
  else if (sender.menu == self->lowerBoxChangeBodyTemplateButton.cell.menu)
    ok = (sender.action != nil);
  else if (sender.tag == EXPORT_FORMAT_EPS)
    ok = [AppController appController].gsAvailable;
  else if (sender.tag == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
    ok = [AppController appController].gsAvailable && [AppController appController].psToPdfAvailable;
  else if (sender.tag == -1)//default
  {
    export_format_t exportFormat = [PreferencesController sharedController].exportFormatPersistent;
    sender.title = [NSString stringWithFormat:@"%@ (%@)",
      NSLocalizedString(@"Default Format", @"Default Format"),
      [[AppController appController] nameOfType:exportFormat]];
  }
  return ok;
}
//end validateMenuItem:

//asks for a filename and format to export
-(IBAction) exportImage:(id)sender
{
  //first, disables PDF_NOT_EMBEDDED_FONTS if needed
  DocumentExtraPanelsController* controller = [self lazyDocumentExtraPanelsController];
  if(!controller.currentSavePanel)//not already onscreen
  {
    if ((controller.saveAccessoryViewExportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) &&
        (![AppController appController].gsAvailable || ![AppController appController].psToPdfAvailable))
      controller.saveAccessoryViewExportFormat = EXPORT_FORMAT_PDF;

    NSSavePanel* currentSavePanel = [NSSavePanel savePanel];
    controller.currentSavePanel = currentSavePanel;
    [currentSavePanel setCanSelectHiddenExtension:YES];
    [currentSavePanel setCanCreateDirectories:YES];
    [currentSavePanel setExtensionHidden:NO];
    
    NSString* directory = nil;
    NSString* file = NSLocalizedString(@"Untitled", @"Untitled");
    NSString* currentFilePath = self.fileURL.path;
    if (currentFilePath)
    {
      directory = currentFilePath.stringByDeletingLastPathComponent;
      file = currentFilePath.lastPathComponent;
    }
    [controller willChangeValueForKey:@"saveAccessoryViewExportFormat"];
    [controller didChangeValueForKey:@"saveAccessoryViewExportFormat"];
    currentSavePanel.directoryURL = [NSURL fileURLWithPath:directory isDirectory:YES];
    currentSavePanel.nameFieldStringValue = file;
    [currentSavePanel beginSheetModalForWindow:self.windowForSheet completionHandler:^(NSInteger result) {
      [self exportChooseFileDidEnd:currentSavePanel returnCode:result contextInfo:NULL];
    }];
  }//end if(![controller currentSavePanel])//not already onscreen
}
//end exportImage:

-(BOOL) canReexport
{
  return self.fileURL.path && self.hasImage;
}
//end canReexport

//asks for a filename and format to export
-(IBAction) reexportImage:(id)sender
{
  if (!self.canReexport)
    [self exportImage:sender];
  else
  {
    DocumentExtraPanelsController* controller = [self lazyDocumentExtraPanelsController];
    //first, disables PDF_NOT_EMBEDDED_FONTS if needed
    if ((controller.saveAccessoryViewExportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) &&
        (![AppController appController].gsAvailable || ![AppController appController].psToPdfAvailable))
      controller.saveAccessoryViewExportFormat = EXPORT_FORMAT_PDF;
    [self exportImageWithData:self->upperBoxImageView.pdfData format:controller.saveAccessoryViewExportFormat
               scaleAsPercent:controller.saveAccessoryViewOptionsJpegQualityPercent jpegColor:controller.saveAccessoryViewOptionsJpegBackgroundColor
                  jpegQuality:controller.saveAccessoryViewOptionsJpegQualityPercent filePath:self.fileURL.path];
  }//end if ([can reexport])
}
//end reexportImage:

-(void) exportChooseFileDidEnd:(NSSavePanel*)sheet returnCode:(NSInteger)code contextInfo:(void*)contextInfo
{
  DocumentExtraPanelsController* controller = [self lazyDocumentExtraPanelsController];
  if ((code == NSModalResponseOK) && self->upperBoxImageView.image)
  {
    export_format_t exportFormat = controller.saveAccessoryViewExportFormat;
    NSString* filePath = sheet.URL.path;
    [self exportImageWithData:self->upperBoxImageView.pdfData format:exportFormat
               scaleAsPercent:controller.saveAccessoryViewScalePercent
                    jpegColor:controller.saveAccessoryViewOptionsJpegBackgroundColor jpegQuality:controller.saveAccessoryViewOptionsJpegQualityPercent
                     filePath:filePath];
  }//end if save
  [controller setCurrentSavePanel:nil];
}
//end exportChooseFileDidEnd:returnCode:contextInfo:

-(void) exportImageWithData:(NSData*)pdfData format:(export_format_t)exportFormat scaleAsPercent:(CGFloat)scaleAsPercent
                  jpegColor:(NSColor*)aJpegColor jpegQuality:(float)aJpegQuality filePath:(NSString*)filePath
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithFloat:aJpegQuality], @"jpegQuality",
                                 [NSNumber numberWithFloat:scaleAsPercent], @"scaleAsPercent",
                                 [NSNumber numberWithBool:[preferencesController exportIncludeBackgroundColor]], @"exportIncludeBackgroundColor",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportPreamble]], @"textExportPreamble",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportEnvironment]], @"textExportEnvironment",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportBody]], @"textExportBody",
                                 aJpegColor, @"jpegColor",//at the end for the case it is null
                                 nil];
  
  NSData* data = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData exportOptions:exportOptions
                                                compositionConfiguration:preferencesController.compositionConfigurationDocument
                                                uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  if (data)
  {
    [data writeToFile:filePath atomically:YES];
    [[NSFileManager defaultManager] setAttributes:@{NSFileHFSCreatorCode: @((OSType)'LTXt')}
                                            ofItemAtPath:filePath error:0];    
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
  if (self->currentEquationIsARecentLatexisation && [PreferencesController sharedController].historySmartEnabled)
  {
    [[AppController appController] addEquationToHistory:[self latexitEquationWithCurrentStateTransient:NO]];
    self->currentEquationIsARecentLatexisation = NO;
  }//end if (self->currentEquationIsARecentLatexisation && [[PreferencesController sharedController] historySmartEnabled])
}
//end triggerSmartHistoryFeature

-(NSString*) selectedText
{
  NSString* text = [NSString string];
  NSResponder* firstResponder = self.windowForSheet.firstResponder;
  if ((firstResponder == self->lowerBoxPreambleTextView) || (firstResponder == self->lowerBoxSourceTextView))
  {
    NSTextView* textView = (NSTextView*) firstResponder;
    text = [textView.string substringWithRange:[textView selectedRange]];
  }
  return text;
}
//end selectedText

-(void) insertText:(id)text
{
  NSResponder* firstResponder = self.windowForSheet.firstResponder;
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
      self->upperBoxZoomBoxSlider.enabled = !self->busyIdentifier;
      self->lowerBoxControlsBoxLatexModeSegmentedControl.enabled = (self->latexModeRequested != LATEX_MODE_AUTO) &&
                                                                     !self->busyIdentifier;
      NSInteger i = 0;
      for(i = 0 ; i<self->lowerBoxControlsBoxLatexModeSegmentedControl.segmentCount ; ++i)
        [self->lowerBoxControlsBoxLatexModeSegmentedControl setEnabled:(self->latexModeRequested != LATEX_MODE_AUTO) &&
                                                                       !self->busyIdentifier forSegment:i];
      
      self->lowerBoxControlsBoxLatexModeAutoButton.enabled = !self->busyIdentifier;
      self->lowerBoxControlsBoxFontSizeTextField.enabled = !self->busyIdentifier;
      self->lowerBoxControlsBoxFontColorWell.enabled = !self->busyIdentifier;
      self->lowerBoxPreambleTextView.editable = !self->busyIdentifier;
      self->lowerBoxChangePreambleButton.enabled = !self->busyIdentifier;
      self->lowerBoxSourceTextView.editable = !self->busyIdentifier;
      self->lowerBoxChangeBodyTemplateButton.enabled = !self->busyIdentifier;
      self->lowerBoxLatexizeButton.title = self->busyIdentifier ? NSLocalizedString(@"Stop", @"Stop") : NSLocalizedString(@"LaTeX it!", @"LaTeX it!");
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
        [self _setLogTableViewVisible:(self->upperBoxLogTableView.numberOfRows > 0)];
      }
    }//end if (![self->busyIdentifier isEqualToString:value])
  }//end @synchronized(self)
}
//end setBusy:

//teleportation to the faulty lines of the latex code when the user clicks a line in the error tableview
-(void) _clickErrorLine:(NSNotification*)aNotification
{
  //registered only for logTableView
  NSNumber* number = (NSNumber*) aNotification.userInfo[@"lineError"];
  if (!number)
  {
    [self displayLastLog:self];
    NSString* message = aNotification.userInfo[@"message"];
    if (!message)
      message = @"";
    NSRange errorRange = [self->lastExecutionLog rangeOfString:message options:NSCaseInsensitiveSearch];
    if (errorRange.location != NSNotFound)
    {
      NSTextView* logTextView = self->documentExtraPanelsController.logTextView;//may be nil
      [logTextView setSelectedRange:errorRange];
      [logTextView scrollRangeToVisible:errorRange];
    }
  }
  else
    [self gotoLine:number.integerValue];
}
//end _clickErrorLine:

-(void) gotoLine:(NSInteger)row
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
  NSScrollView* scrollView = (NSScrollView*) self->upperBoxLogTableView.superview.superview;
  scrollView.hidden = !status;
  [scrollView setNeedsDisplay:YES];
}
//end _setLogTableViewVisible:

//sets up a new linkBack link
-(void) setLinkBackLink:(LinkBack*)newLinkBackLink
{
  if (newLinkBackLink != self->linkBackLink)
  {
    [self willChangeValueForKey:@"linkBackLink"];
    LinkBack* oldLinkbackLink = self->linkBackLink;
    self->linkBackLink = nil;
    //[oldLinkbackLink remoteCloseLink];
    [oldLinkbackLink closeLink];
    [oldLinkbackLink release];
    self->linkBackLink = [newLinkBackLink retain];
    [self didChangeValueForKey:@"linkBackLink"];
    NSWindow* window = self.windowForSheet;
    if (window)
    {
      self->lowerBoxLinkbackButton.hidden = !self->linkBackLink;
      [self->lowerBoxLinkbackButton setEnabled:NO];
      self.linkBackAllowed = (self->linkBackLink != nil);
      if (!self->linkBackLink)
        [self setDocumentTitle:nil];
    }//end if (window)
  }//end if (newLinkBackLink != self->linkBackLink)
}
//end setLinkBackLink:

-(void) setLinkBackAllowed:(BOOL)value
{
  if (value != self->linkBackAllowed)
  {
    [self willChangeValueForKey:@"linkBackAllowed"];
    self->linkBackAllowed = value;
    [self didChangeValueForKey:@"linkBackAllowed"];
    self->lowerBoxLinkbackButton.toolTip = self->linkBackAllowed ?
      NSLocalizedString(@"The Linkback link is active", @"The Linkback link is active") :
      NSLocalizedString(@"The Linkback link is suspended", @"The Linkback link is suspended");
  }//end if (value != self->linkBackAllowed)
}
//end setLinkBackAllowed:

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
      [self setDocumentTitle:libraryEquation.title];
      self.windowForSheet.representedFilename = libraryEquation.title;
    }//end if (self->linkedLibraryEquation)
  }//end if (libraryEquation != self->linkedLibraryEquation)
}
//end setLinkedLibraryEquation:

-(BOOL) window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu*)menu
{
  BOOL result = NO;
  if (self.fileURL)
    result = YES;
  else if (self->linkedLibraryEquation)
  {
    while(menu.numberOfItems)
      [menu removeItemAtIndex:0];
    NSMenuItem* menuItem =
      [menu addItemWithTitle:self->linkedLibraryEquation.title action:@selector(selectLibraryItemForCurrentLinkedEquation:) keyEquivalent:@""];
    menuItem.target = self;
    menuItem.representedObject = self->linkedLibraryEquation;
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
  }//end if (!libraryEquation || (self->linkedLibraryEquation == libraryEquation))
}
//end closeLinkedLibraryEquation:

-(void) libraryDidChangeNotification:(NSNotification*)notification
{
  if (self->linkedLibraryEquation)
  {
    if (!self->linkedLibraryEquation.managedObjectContext || self->linkedLibraryEquation.deleted)
    {
      //[[[self undoManager] prepareWithInvocationTarget:self] setLinkedLibraryEquation:self->linkedLibraryEquation];
      [self closeLinkedLibraryEquation:self->linkedLibraryEquation];
    }//end if (![self->linkedLibraryEquation managedObjectContext] || [self->linkedLibraryEquation isDeleted])
    else if ([notification.userInfo[NSUpdatedObjectsKey] containsObject:self->linkedLibraryEquation])
    {
      [self applyLibraryEquation:self->linkedLibraryEquation];
      [self setDocumentTitle:self->linkedLibraryEquation.title];
      self.windowForSheet.representedFilename = self->linkedLibraryEquation.title;
    }//end if ([[[notification userInfo] objectForKey:NSUpdatedObjectsKey] containsObject:self->linkedLibraryEquation])
  }//end if (self->linkedLibraryEquation)
}
//end libraryDidChangeNotification:

-(NSImage*) _checkEasterEgg
{
  NSImage* easterEggImage = nil;
  
  BOOL forceEasterEggForDebugging = NO;
  
  NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
  NSDate* now = [NSDate date];
  NSDateComponents *nowComp = [cal componentsInTimeZone:[NSTimeZone localTimeZone] fromDate:now];
  NSString* easterEggString = nil;
  if (forceEasterEggForDebugging || ((nowComp.month == 4) && (nowComp.day == 1)))
    easterEggString = @"aprilfish";
    
  if (easterEggString)
  {
    NSDictionary* resources = @{@"aprilfish": @"poisson.pdf"};
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary* easterEggLastDates = [NSMutableDictionary dictionaryWithDictionary:[userDefaults dictionaryForKey:LastEasterEggsDatesKey]] ?: [NSMutableDictionary dictionary];
    if (!easterEggLastDates)
      easterEggLastDates = [NSMutableDictionary dictionary];
    NSDate* easterEggLastDate = easterEggLastDates[easterEggString];
    NSDateComponents *lastComp = [cal componentsInTimeZone:[NSTimeZone localTimeZone] fromDate:easterEggLastDate];
    if (forceEasterEggForDebugging || (!easterEggLastDate) || [now isLessThan:easterEggLastDate] ||
        (nowComp.year != lastComp.year))
    {
      NSString* resource = resources[easterEggString];
      NSString* filePath = resource ? [[NSBundle mainBundle] pathForResource:resource.stringByDeletingPathExtension
                                                                      ofType:resource.pathExtension] : nil;
      if (resource && filePath)
        easterEggImage = [[[NSImage alloc] initWithContentsOfFile:filePath] autorelease];
      easterEggLastDates[easterEggString] = [NSDate date];
    }
    [userDefaults setObject:easterEggLastDates forKey:LastEasterEggsDatesKey];
  }//end if (easterEggString)
  return easterEggImage;
}
//end _checkEasterEgg:

-(NSString*) descriptionForScript:(NSDictionary*)script
{
  NSMutableString* description = [NSMutableString string];
  if (script)
  {
    switch([script[CompositionConfigurationAdditionalProcessingScriptTypeKey] intValue])
    {
      case SCRIPT_SOURCE_STRING :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"Shell", @"Shell"),
          script[CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Body", @"Body"),
          script[CompositionConfigurationAdditionalProcessingScriptContentKey]];
        break;
      case SCRIPT_SOURCE_FILE :
        [description appendFormat:@"%@\t: %@\n%@\t:\n%@\n",
          NSLocalizedString(@"File", @"File"),
          script[CompositionConfigurationAdditionalProcessingScriptShellKey],
          NSLocalizedString(@"Content", @"Content"),
          script[CompositionConfigurationAdditionalProcessingScriptPathKey]];
        break;
    }//end switch
  }//end if script
  return description;
}
//end descriptionForScript:

-(void) setReducedTextArea:(BOOL)reduce
{
  if ((reduce != isReducedTextArea) && upperBox && lowerBox)
  {
    NSRect oldUpFrame  = self->upperBox.frame;
    NSRect oldLowFrame = self->lowerBox.frame;
    CGFloat margin = reduce ? self->lowerBoxSplitView.frame.size.height/2 : -self->lowerBoxSplitView.frame.size.height;
    NSRect newUpFrame  = NSMakeRect(oldUpFrame.origin.x, oldUpFrame.origin.y-margin, oldUpFrame.size.width, oldUpFrame.size.height+margin);
    NSRect newLowFrame = NSMakeRect(oldLowFrame.origin.x, oldLowFrame.origin.y, oldLowFrame.size.width, oldLowFrame.size.height-margin);
    NSViewAnimation* viewAnimation =
      [[[NSViewAnimation alloc] initWithViewAnimations:
        @[@{NSViewAnimationTargetKey: self->upperBox,
                                                     NSViewAnimationStartFrameKey: [NSValue valueWithRect:oldUpFrame],
                                                     NSViewAnimationEndFrameKey: [NSValue valueWithRect:newUpFrame]},
          @{NSViewAnimationTargetKey: self->lowerBox,
                                                     NSViewAnimationStartFrameKey: [NSValue valueWithRect:oldLowFrame],
                                                     NSViewAnimationEndFrameKey: [NSValue valueWithRect:newLowFrame]}]] autorelease];
    viewAnimation.duration = .5;
    viewAnimation.animationBlockingMode = NSAnimationNonblocking;
    [viewAnimation startAnimation];
    self->isReducedTextArea = reduce;
  }
}
//setReducedTextAreaState:

-(void) splitViewDidResizeSubviews:(NSNotification*)notification
{
  self->lowerBoxChangePreambleButton.hidden = (!self.preambleVisible || (self->lowerBoxPreambleTextView.superview.frame.size.height < self->lowerBoxChangePreambleButton.frame.size.height));
  NSRect frame = self->lowerBoxChangeBodyTemplateButton.frame;
  frame.origin = self->lowerBoxSourceTextView.superview.superview.frame.origin;
  frame.origin.y = self->lowerBoxSplitView.frame.size.height-
                   self->lowerBoxSourceTextView.superview.superview.frame.origin.y-
                   frame.size.height;
  frame.origin.x += self->lowerBoxSplitView.frame.origin.x;
  frame.origin.y += self->lowerBoxSplitView.frame.origin.y;
  self->lowerBoxChangeBodyTemplateButton.frame = frame;
  self->lowerBoxChangeBodyTemplateButton.hidden = (self->lowerBoxSourceTextView.superview.superview.frame.size.height < frame.size.height);
}
//end splitViewDidResizeSubviews:

-(void) popUpButtonWillPopUp:(NSNotification*)notification
{
  NSPopUpButtonCell* changePreambleButtonCell = self->lowerBoxChangePreambleButton.cell;
  NSPopUpButtonCell* changeBodyTemplateButtonCell = self->lowerBoxChangeBodyTemplateButton.cell;
  if (notification.object == changePreambleButtonCell)
  {
    NSAttributedString* currentPreamble = self->lowerBoxPreambleTextView.textStorage;
    NSArray* preambles                  = [PreferencesController sharedController].preambles;
    NSInteger defaultDocumentPreamble   = [PreferencesController sharedController].preambleDocumentIndex;
    NSInteger i = 0;
    NSDictionary* matchingPreamble = nil;
    for(i = 0 ; (unsigned)i<preambles.count ; ++i)
    {
      NSDictionary* preamble = preambles[i];
      id rawValue = preamble[@"value"];
      NSAttributedString* value = [rawValue isKindOfClass:[NSAttributedString class]] ? rawValue :
                                  [rawValue isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawValue] :
                                  nil;
      NSString* currentPreambleAsTrimmedString = [currentPreamble.string trim];
      NSString* candidatePreambleAsTrimmedString = [value.string trim];
      BOOL isMatching = [currentPreambleAsTrimmedString isEqualToString:candidatePreambleAsTrimmedString];
      if (isMatching && (!matchingPreamble || (i == defaultDocumentPreamble)))
        matchingPreamble = preamble;
    }
  
    [changePreambleButtonCell removeAllItems];
    NSMenu* menu = changePreambleButtonCell.menu;
    [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [menu addItemWithTitle:[NSString stringWithFormat:@"%@...", NSLocalizedString(@"Preambles", @"Preambles")]
      action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    NSEnumerator* enumerator = [preambles objectEnumerator];
    NSDictionary* preamble = nil;
    while((preamble = [enumerator nextObject]))
    {
      id item = [menu addItemWithTitle:preamble[@"name"] action:@selector(changePreamble:) keyEquivalent:@""];
      [item setRepresentedObject:preamble];
      if (preamble == matchingPreamble)
        [item setState:NSOnState];
    }
      
    menu.delegate = (id)self;
  }//end if ([notification object] == changePreambleButtonCell)
  if (notification.object == changeBodyTemplateButtonCell)
  {
    NSString* currentBody = self->lowerBoxSourceTextView.textStorage.string;
    NSInteger bodyTemplateDocumentIndex = [PreferencesController sharedController].bodyTemplateDocumentIndex;
    NSArray*  bodyTemplates = [PreferencesController sharedController].bodyTemplatesWithNone;
    NSInteger i = 0;
    NSInteger matchIndex = 0;
    for(i = 1 ; (unsigned)i<bodyTemplates.count ; ++i)//skip first one at 0 (which is "none")
    {
      NSDictionary* bodyTemplate = bodyTemplates[i];
      id rawHead = bodyTemplate[@"head"];
      NSAttributedString* head = [rawHead isKindOfClass:[NSAttributedString class]] ? rawHead :
                                 [rawHead isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawHead] :
                                 nil;
      id rawTail = bodyTemplate[@"tail"];
      NSAttributedString* tail = [rawTail isKindOfClass:[NSAttributedString class]] ? rawTail :
                                 [rawTail isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:rawTail] :
                                 nil;
      NSString* headString = head.string;
      NSString* tailString = tail.string;
      NSString* regexString = [NSString stringWithFormat:@"^[\\s\\n]*\\Q%@\\E[\\s\\n]*(.*)[\\s\\n]*\\Q%@\\E[\\s\\n]*$", headString, tailString];
      NSError*  error = nil;
      NSString* innerBody = [currentBody stringByMatching:regexString options:RKLMultiline|RKLDotAll inRange:NSMakeRange(0, currentBody.length)
                                                  capture:1 error:nil];
      BOOL isMatching = innerBody && !error;
      if (isMatching && (!matchIndex || (i == bodyTemplateDocumentIndex+1)))
        matchIndex = i;
    }//end for each body template
    NSDictionary* matchingBodyTemplate = bodyTemplates[matchIndex];
    [self->lastRequestedBodyTemplate release];
    self->lastRequestedBodyTemplate = [matchingBodyTemplate deepCopy];
  
    [changeBodyTemplateButtonCell removeAllItems];
    NSMenu* menu = changeBodyTemplateButtonCell.menu;
    [menu addItemWithTitle:@"" action:nil keyEquivalent:@""];
    [menu addItemWithTitle:[NSString stringWithFormat:@"%@...", NSLocalizedString(@"Body templates", @"Body templates")]
      action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    NSEnumerator* enumerator = [bodyTemplates objectEnumerator];
    NSDictionary* bodyTemplate = nil;
    while((bodyTemplate = [enumerator nextObject]))
    {
      id item = [menu addItemWithTitle:bodyTemplate[@"name"] action:@selector(changeBodyTemplate:) keyEquivalent:@""];
      [item setRepresentedObject:bodyTemplate];
      if (bodyTemplate == matchingBodyTemplate)
        [item setState:NSOnState];
    }
    menu.delegate = (id)self;
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
    NSAttributedString* preambleAttributedString = [NSKeyedUnarchiver unarchiveObjectWithData:preamble[@"value"]];
    [self setPreamble:preambleAttributedString];
  }
  else
    [[AppController appController] showPreferencesPaneWithItemIdentifier:TemplatesToolbarItemIdentifier options:@0]; 
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
    [[AppController appController] showPreferencesPaneWithItemIdentifier:TemplatesToolbarItemIdentifier options:@1]; 
}
//end changeBodyTemplate:

-(void) bodyTextDidChange:(NSNotification*)notification
{
  if (self.latexModeRequested == LATEX_MODE_AUTO)
    self.latexModeApplied = [self detectLatexMode];
}
//end bodyTextDidChange:

-(latex_mode_t) detectLatexMode
{
  latex_mode_t result = LATEX_MODE_DISPLAY;
  NSString* body = self->lowerBoxSourceTextView.textStorage.string;
  NSRange range = NSMakeRange(0, body.length);
  RKLRegexOptions options = RKLDotAll | RKLMultiline;
  if ([body isMatchedByRegex:@"\\$\\$(.+)\\$\\$" options:options inRange:range error:nil] ||
      [body isMatchedByRegex:@"\\$(.+)\\$" options:options inRange:range error:nil] ||
      [body isMatchedByRegex:@"\\[(.*)\\]" options:options inRange:range error:nil] ||
      [body isMatchedByRegex:@"\\\\begin\\{(.+)\\}(.*)\\\\end\\{\\1\\}" options:options inRange:range error:nil])
    result = LATEX_MODE_TEXT;
  else if ([body isMatchedByRegex:@"&" options:options inRange:range error:nil] ||
           [body isMatchedByRegex:@"\\\\\\\\" options:options inRange:range error:nil])
    result = LATEX_MODE_ALIGN;
  return result;
}
//end detectLatexMode

-(IBAction) fontSizeChange:(id)sender
{
  CGFloat fontSizeDelta = ([sender tag] == 1) ? -1 : 1;
  NSTextStorage* textStorage = self->lowerBoxSourceTextView.textStorage;
  NSRange fullRange = NSMakeRange(0, textStorage.length);
  NSArray* selectedRanges = self->lowerBoxSourceTextView.selectedRanges;
  if (!selectedRanges.count)
    selectedRanges = @[[NSValue valueWithRange:fullRange]];
  NSUInteger i = 0;
  for(i = 0 ; i<selectedRanges.count ; ++i)
  {
    NSRange range = [selectedRanges[i] rangeValue];
    NSRange effectiveRange = {0};
    NSFont* font = [[textStorage attribute:NSFontAttributeName atIndex:range.location effectiveRange:&effectiveRange] dynamicCastToClass:[NSFont class]];
    font = !font ? nil : [NSFont fontWithDescriptor:font.fontDescriptor size:font.pointSize+fontSizeDelta];
    if (font)
      [textStorage addAttribute:NSFontAttributeName value:font range:range];
  }//end for each range
}
//end fontSizeChange:

-(void) formatChangeAlignment:(alignment_mode_t)value
{
  NSString* string = self->lowerBoxSourceTextView.textStorage.string;
  NSRange fullRange = NSMakeRange(0, string.length);
  NSArray* selectedRanges = self->lowerBoxSourceTextView.selectedRanges;
  NSMutableArray* mutableSelectedRanges = [[selectedRanges mutableCopy] autorelease];
  if (!mutableSelectedRanges.count)
    [mutableSelectedRanges insertObject:[NSValue valueWithRange:fullRange] atIndex:0];
  //while([mutableSelectedRanges count])
  if(mutableSelectedRanges.count)//for now, only consider first selection
  {
    NSRange firstRange = [mutableSelectedRanges[0] rangeValue];
    NSRange searchRange = !firstRange.length ? fullRange : firstRange;
    NSValue* bestFound = nil;
    BOOL stop = !searchRange.length;
    while(!stop)
    {
      NSRange found = [string rangeOfRegex:@"\\\\begin\\{(.+)\\}(.*)\\\\end\\{\\1\\}" options:RKLMultiline|RKLDotAll inRange:searchRange capture:0 error:nil];
      if (found.location != NSNotFound)
      {
        if (!firstRange.length || NSRangeContains(found, firstRange.location))
          bestFound = [NSValue valueWithRange:found];
        NSUInteger searchRangeEnd = searchRange.location+searchRange.length;
        searchRange.location = found.location+found.length;
        searchRange.length = (searchRange.location > searchRangeEnd) ? 0 : (searchRangeEnd-searchRange.location);
      }//end if (found.location != NSNotFound)
      stop |= (found.location == NSNotFound);
      stop |= (searchRange.location > firstRange.location) || !searchRange.length;
    }//end while(!stop)
    if (!bestFound)
    {
      if ((value != ALIGNMENT_MODE_UNDEFINED) && (value != ALIGNMENT_MODE_NONE))
      {
        NSMutableAttributedString* attributedString1 = [[[NSMutableAttributedString alloc] initWithString:
          [NSString stringWithFormat:@"\\begin{%@}",
            (value == ALIGNMENT_MODE_LEFT) ? @"flushleft" :
            (value == ALIGNMENT_MODE_RIGHT) ? @"flushright" :
            (value == ALIGNMENT_MODE_CENTER) ? @"center" : @""]] autorelease];
        NSMutableAttributedString* attributedString2 = [[[NSMutableAttributedString alloc] initWithString:
          [NSString stringWithFormat:@"\\end{%@}",
            (value == ALIGNMENT_MODE_LEFT) ? @"flushleft" :
            (value == ALIGNMENT_MODE_RIGHT) ? @"flushright" :
            (value == ALIGNMENT_MODE_CENTER) ? @"center" : @""]] autorelease];
        NSMutableAttributedString* textStorage = [[self->lowerBoxSourceTextView.textStorage mutableCopy] autorelease];
        NSRange firstRangeAdapted = firstRange;
        if (!firstRangeAdapted.length)
          firstRangeAdapted = fullRange;
        BOOL isEmpty = !textStorage.length;
        NSDictionary* attributes1 = isEmpty ? nil : [textStorage attributesAtIndex:firstRangeAdapted.location effectiveRange:0];
        NSDictionary* attributes2 = isEmpty ? nil : [textStorage attributesAtIndex:!firstRangeAdapted.length ? 0 : (firstRangeAdapted.location+firstRangeAdapted.length-1) effectiveRange:0];
        if (attributes1)
          [attributedString1 setAttributes:attributes1 range:NSMakeRange(0, attributedString1.length)];
        if (attributes2)
          [attributedString2 setAttributes:attributes2 range:NSMakeRange(0, attributedString2.length)];
        [textStorage insertAttributedString:attributedString1 atIndex:firstRangeAdapted.location];
        [textStorage insertAttributedString:attributedString2 atIndex:firstRangeAdapted.location+firstRangeAdapted.length+attributedString1.length];
        [self setSourceText:textStorage];
        NSRange newSelectedRange = NSMakeRange(firstRangeAdapted.location, attributedString1.length+firstRangeAdapted.length+attributedString2.length);
        [self->lowerBoxSourceTextView setSelectedRange:newSelectedRange];
      }//end if ((value != ALIGNMENT_MODE_UNDEFINED) && (value != ALIGNMENT_MODE_NONE))
    }//end if (!bestFound)
    else//if (bestFound)
    {
      NSRange localSearchRange = bestFound.rangeValue;
      NSMutableAttributedString* textStorage = [[self->lowerBoxSourceTextView.textStorage mutableCopy] autorelease];      
      NSRange regexInnerRange =
        [textStorage.string rangeOfRegex:@"^\\\\begin\\{[^\\{\\}]+\\}(.*)\\\\end\\{[^\\{\\}]+\\}$" options:RKLMultiline|RKLDotAll inRange:localSearchRange capture:1 error:nil];
      if (value == ALIGNMENT_MODE_NONE)
      {
        [textStorage replaceOccurrencesOfRegex:@"\\\\begin\\{(.+)\\}(.*)\\\\end\\{\\1\\}" withString:@"$2" options:RKLMultiline|RKLDotAll range:bestFound.rangeValue error:nil];
        [self setSourceText:textStorage];
        [self->lowerBoxSourceTextView setSelectedRange:NSMakeRange(localSearchRange.location, regexInnerRange.length)];
      }//end if (value == ALIGNMENT_MODE_NONE)
      else if ((value == ALIGNMENT_MODE_LEFT) || (value == ALIGNMENT_MODE_RIGHT) || (value == ALIGNMENT_MODE_CENTER))
      {
        NSString* newAligmentCodeString =
            (value == ALIGNMENT_MODE_LEFT) ? @"flushleft" :
            (value == ALIGNMENT_MODE_RIGHT) ? @"flushright" :
            (value == ALIGNMENT_MODE_CENTER) ? @"center" : @"";
        NSString* newCodeBefore = [NSString stringWithFormat:@"\\begin{%@}", newAligmentCodeString];
        NSString* newCodeAfter  = [NSString stringWithFormat:@"\\end{%@}", newAligmentCodeString];
        [textStorage replaceOccurrencesOfRegex:@"\\\\begin\\{(.+)\\}(.*)\\\\end\\{\\1\\}"
          withString:[NSString stringWithFormat:@"\\\\begin{%@}$2\\\\end{%@}", newAligmentCodeString, newAligmentCodeString]
           options:RKLMultiline|RKLDotAll range:localSearchRange error:nil];
        [self setSourceText:textStorage];
        NSRange newSelectedRange = NSMakeRange(localSearchRange.location, newCodeBefore.length+regexInnerRange.length+newCodeAfter.length);
        [self->lowerBoxSourceTextView setSelectedRange:newSelectedRange];
      }//end if ((value != ALIGNMENT_MODE_UNDEFINED) && (value != ALIGNMENT_MODE_NONE))
    }//end if (bestFound)
    [mutableSelectedRanges removeObjectAtIndex:0];
  }//end while([mutableSelectedRanges count])
}
//end formatChangeAlignment:

-(void) formatComment:(id)sender
{
  NSMutableAttributedString* textStorage = [[self->lowerBoxSourceTextView.textStorage mutableCopy] autorelease];      
  NSMutableString* string = [[textStorage.string mutableCopy] autorelease];
  NSArray* selectedRanges = self->lowerBoxSourceTextView.selectedRanges;
  NSMutableArray* newSelectedRanges = [NSMutableArray arrayWithCapacity:selectedRanges.count];
  NSEnumerator* rangeEnumerator = [selectedRanges objectEnumerator];
  NSValue* selectedRangeValue = nil;
  while((selectedRangeValue = [rangeEnumerator nextObject]))
  {
    NSRange selectedRange = selectedRangeValue.rangeValue;
    BOOL stop = NO;
    while(!stop)
    {
      NSRange newLineRange = [string rangeOfString:@"\n" options:0 range:selectedRange];
      BOOL hasNewLine = (newLineRange.location != NSNotFound);
      if (!hasNewLine)
        [newSelectedRanges addObject:[NSValue valueWithRange:selectedRange]];
      else//if (hasNewLine)
      {
        NSRange subRange = NSMakeRange(selectedRange.location, newLineRange.location-selectedRange.location);
        if (subRange.length)
          [newSelectedRanges addObject:[NSValue valueWithRange:subRange]];
        NSUInteger headLength = newLineRange.location+1-selectedRange.location;
        selectedRange.location += headLength;
        selectedRange.length -= headLength;
      }//end if (hasNewLine)
      stop |= !selectedRange.length || !hasNewLine;
    }//end while(!stop)
  }//end for each selectedRange
  
  NSMutableArray* shiftedSelectedRanges = [NSMutableArray arrayWithCapacity:selectedRanges.count];

  NSUInteger currentShift = 0;
  NSRange lastLineRange = NSMakeRange(0, 0);
  rangeEnumerator = [newSelectedRanges objectEnumerator];
  selectedRangeValue = nil;
  while((selectedRangeValue = [rangeEnumerator nextObject]))
  {
    NSRange selectedRange = selectedRangeValue.rangeValue;
    NSRange shiftedSelectedRange = selectedRange;
    shiftedSelectedRange.location += currentShift;
    NSRange lineRange = [string lineRangeForRange:shiftedSelectedRange];
    if (!currentShift || !NSEqualRanges(lineRange, lastLineRange))
    {
      [string insertString:@"%" atIndex:lineRange.location];
      ++lineRange.length;
      ++currentShift;
      ++shiftedSelectedRange.location;
    }//end if (![lineRanges count] || !NSEqualRanges(lineRange, lastLineRange))
    lastLineRange = lineRange;
    [shiftedSelectedRanges addObject:[NSValue valueWithRange:shiftedSelectedRange]];
  }//end for each selectedRange

  [textStorage replaceCharactersInRange:NSMakeRange(0, textStorage.length) withString:string];
  [self setSourceText:textStorage];
  self->lowerBoxSourceTextView.selectedRanges = shiftedSelectedRanges;
}
//end formatComment:

-(void) formatUncomment:(id)sender
{
  NSMutableAttributedString* textStorage = [[self->lowerBoxSourceTextView.textStorage mutableCopy] autorelease];      
  NSMutableString* string = [[textStorage.string mutableCopy] autorelease];
  NSArray* selectedRanges = self->lowerBoxSourceTextView.selectedRanges;
  NSMutableArray* newSelectedRanges = [NSMutableArray arrayWithCapacity:selectedRanges.count];
  NSEnumerator* rangeEnumerator = [selectedRanges objectEnumerator];
  NSValue* selectedRangeValue = nil;
  while((selectedRangeValue = [rangeEnumerator nextObject]))
  {
    NSRange selectedRange = selectedRangeValue.rangeValue;
    BOOL stop = NO;
    while(!stop)
    {
      NSRange newLineRange = [string rangeOfString:@"\n" options:0 range:selectedRange];
      BOOL hasNewLine = (newLineRange.location != NSNotFound);
      if (!hasNewLine)
        [newSelectedRanges addObject:[NSValue valueWithRange:selectedRange]];
      else//if (hasNewLine)
      {
        NSRange subRange = NSMakeRange(selectedRange.location, newLineRange.location-selectedRange.location);
        if (subRange.length)
          [newSelectedRanges addObject:[NSValue valueWithRange:subRange]];
        NSUInteger headLength = newLineRange.location+1-selectedRange.location;
        selectedRange.location += headLength;
        selectedRange.length -= headLength;
      }//end if (hasNewLine)
      stop |= !selectedRange.length || !hasNewLine;
    }//end while(!stop)
  }//end for each selectedRange
  
  NSMutableArray* shiftedSelectedRanges = [NSMutableArray arrayWithCapacity:selectedRanges.count];
  
  NSUInteger currentShift = 0;
  NSRange lastLineRange = NSMakeRange(0, 0);
  rangeEnumerator = [newSelectedRanges objectEnumerator];
  selectedRangeValue = nil;
  while((selectedRangeValue = [rangeEnumerator nextObject]))
  {
    NSRange selectedRange = selectedRangeValue.rangeValue;
    NSRange shiftedSelectedRange = selectedRange;
    shiftedSelectedRange.location -= currentShift;
    NSRange lineRange = [string lineRangeForRange:shiftedSelectedRange];
    if (!currentShift || !NSEqualRanges(lineRange, lastLineRange))
    {
      if ([[string substringWithRange:lineRange] startsWith:@"%" options:0])
      {
        [string deleteCharactersInRange:NSMakeRange(lineRange.location, 1)];
        --lineRange.length;
        ++currentShift;
        --shiftedSelectedRange.location;
      }//end if ([[string substringWithRange:lineRange] startsWith:@"%" options:0])
    }//end if (![lineRanges count] || !NSEqualRanges(lineRange, lastLineRange))
    lastLineRange = lineRange;
    [shiftedSelectedRanges addObject:[NSValue valueWithRange:shiftedSelectedRange]];
  }//end for each selectedRange
  
  [textStorage replaceCharactersInRange:NSMakeRange(0, textStorage.length) withString:string];
  [self setSourceText:textStorage];
  self->lowerBoxSourceTextView.selectedRanges = shiftedSelectedRanges;
}
//end formatUncomment:

-(BOOL) hasBackSyncFile
{
  BOOL result = (self->backSyncFilePath != nil);
  return result;
}
//end hasBackSyncFile

-(void) closeBackSyncFile
{
  if (self->backSyncUkkQueue)
  {
    if (self->backSyncFilePath)
    {
      [self->backSyncUkkQueue removePath:self->backSyncFilePath];
      [self->backSyncUkkQueue removePath:self->backSyncFilePath.stringByDeletingLastPathComponent];
    }//end if (self->backSyncFilePath)
  }//end if (self->backSyncUkkQueue)
  [self->backSyncFilePath release];
  self->backSyncFilePath = nil;
  [self->backSyncFileLastModificationDate release];
  self->backSyncFileLastModificationDate = nil;
  NSString* filePath = self.fileURL.path;
  NSImage* icon = !filePath ? nil : [[NSWorkspace sharedWorkspace] iconForFile:filePath];
  [self.windowForSheet standardWindowButton:NSWindowDocumentIconButton].image = icon;
}
//end closeBackSyncFile

-(void) openBackSyncFile:(NSString*)path options:(NSDictionary*)options
{
  if (![path isEqualToString:self->backSyncFilePath])
    [self closeBackSyncFile];
  if (path)
  {
    if (!self->backSyncOptions)
      self->backSyncOptions = [[PropertyStorage alloc] initWithDictionary:options];
    else
      self->backSyncOptions.dictionary = options;
    self->backSyncFilePath = [path copy];
    self->backSyncFileLastModificationDate =
      [[[[NSFileManager defaultManager] attributesOfItemAtPath:self->backSyncFilePath error:nil]
        fileModificationDate] copy];
    if (!self->backSyncUkkQueue)
    {
      self->backSyncUkkQueue = [[UKKQueue alloc] init];
      self->backSyncUkkQueue.delegate = self;
    }//end if (!self->backSyncUkkQueue)
    [self->backSyncUkkQueue addPath:self->backSyncFilePath];
    [self->backSyncUkkQueue addPath:self->backSyncFilePath.stringByDeletingLastPathComponent];
    self.fileURL = [NSURL fileURLWithPath:self->backSyncFilePath];
    NSImage* icon = [NSImage imageNamed:@"backsync"];
    [self.windowForSheet standardWindowButton:NSWindowDocumentIconButton].image = icon;
    [self watcher:nil receivedNotification:UKFileWatcherWriteNotification forPath:self->backSyncFilePath];
  }//end if (path)
}
//end openBackSyncFile:

-(IBAction) save:(id)sender
{
  BOOL saveWithoutBackSync = self.fileURL && !self->backSyncFilePath;
  BOOL saveWithBackSync = (self->backSyncFilePath != nil);
  if (saveWithoutBackSync || saveWithBackSync)
  {
    NSString* preamble = [[self->lowerBoxPreambleTextView.string mutableCopy] autorelease];
    NSString* source = [[self->lowerBoxSourceTextView.string mutableCopy] autorelease];
    latex_mode_t latexMode = (latex_mode_t) self->lowerBoxControlsBoxLatexModeSegmentedControl.selectedSegmentTag;
    NSString* addSymbolLeft  =
    (latexMode == LATEX_MODE_ALIGN) ? @"\\begin{align*}" :
    (latexMode == LATEX_MODE_EQNARRAY) ? @"\\begin{eqnarray*}" :
    (latexMode == LATEX_MODE_DISPLAY) ? @"\\[" :
    (latexMode == LATEX_MODE_INLINE) ? @"$" :
    @"";
    NSString* addSymbolRight =
    (latexMode == LATEX_MODE_ALIGN) ? @"\\end{align*}" :
    (latexMode == LATEX_MODE_EQNARRAY) ? @"\\end{eqnarray*}" :
    (latexMode == LATEX_MODE_DISPLAY) ? @"\\]" :
    (latexMode == LATEX_MODE_INLINE) ? @"$" :
    @"";
    BOOL synchronizePreamble = saveWithBackSync &&
      [[self->backSyncOptions[@"synchronizePreamble"] dynamicCastToClass:[NSNumber class]] boolValue];
    BOOL synchronizeEnvironment = saveWithBackSync &&
      [[self->backSyncOptions[@"synchronizeEnvironment"] dynamicCastToClass:[NSNumber class]] boolValue];
    BOOL synchronizeBody = saveWithBackSync &&
      [[self->backSyncOptions[@"synchronizeBody"] dynamicCastToClass:[NSNumber class]] boolValue];
    NSMutableString* string = [NSMutableString string];
    if (preamble && (saveWithoutBackSync || synchronizePreamble))
      [string appendString:preamble];
    if (preamble && source && (saveWithoutBackSync || synchronizeEnvironment || synchronizeBody))
      [string appendString:@"\\begin{document}\n"];
    if (addSymbolLeft && (saveWithoutBackSync || synchronizeEnvironment))
      [string appendString:addSymbolLeft];
    if (source && (saveWithoutBackSync || synchronizeBody))
      [string appendString:source];
    if (addSymbolRight && (saveWithoutBackSync || synchronizeEnvironment))
      [string appendString:addSymbolRight];
    if (preamble && source && (saveWithoutBackSync || synchronizeEnvironment || synchronizeBody))
      [string appendString:@"\n\\end{document}"];

    NSData* data = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (saveWithBackSync)
      self->backSyncIsSaving = YES;
    @try{
      NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-%lu", (unsigned long)self->uniqueId];
      NSMutableString* fullLog = [NSMutableString string];
      NSDictionary* fullEnvironment = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];
      NSDictionary* extraEnvironment =
      @{@"CURRENTDIRECTORY": self->backSyncFilePath.stringByDeletingLastPathComponent,
       @"INPUTFILE": self->backSyncFilePath};
      NSMutableDictionary* environment1 = [NSMutableDictionary dictionaryWithDictionary:fullEnvironment];
      [environment1 addEntriesFromDictionary:extraEnvironment];
      PreferencesController* preferencesController = [PreferencesController sharedController];
      NSDictionary* synchronizationAdditionalScripts = preferencesController.synchronizationAdditionalScripts;
      LaTeXProcessor* latexProcessor = [LaTeXProcessor sharedLaTeXProcessor];
      NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
      NSDictionary* compositionConfiguration = preferencesController.compositionConfigurationDocument;
      
      NSDictionary* preprocessingscript = synchronizationAdditionalScripts[[NSString stringWithFormat:@"%d",SYNCHRONIZATION_SCRIPT_PLACE_SAVING_PREPROCESSING]];
      if (saveWithBackSync && preprocessingscript && [preprocessingscript[CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
      {
        DebugLog(1, @"Pre-processing on save");
        [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Pre-processing on save", @"Pre-processing on save")];
        [fullLog appendFormat:@"%@\n", [latexProcessor descriptionForScript:preprocessingscript]];
        [latexProcessor executeScript:preprocessingscript setEnvironment:environment1 logString:fullLog workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
             compositionConfiguration:compositionConfiguration];
      }//end if (saveWithBackSync && preprocessingscript && [[preprocessingscript objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])

      if (saveWithoutBackSync)
        [data writeToURL:self.fileURL atomically:YES];
      else if (saveWithBackSync)
        [data writeToFile:self->backSyncFilePath atomically:NO];
      
      NSDictionary* postprocessingscript = synchronizationAdditionalScripts[[NSString stringWithFormat:@"%d",SYNCHRONIZATION_SCRIPT_PLACE_SAVING_POSTPROCESSING]];
      if (saveWithBackSync && postprocessingscript && [postprocessingscript[CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
      {
        DebugLog(1, @"Post-processing on save");
        [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Post-processing on save", @"Post-processing on save")];
        [fullLog appendFormat:@"%@\n", [latexProcessor descriptionForScript:postprocessingscript]];
        [latexProcessor executeScript:postprocessingscript setEnvironment:environment1 logString:fullLog workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
             compositionConfiguration:compositionConfiguration];
      }//end if (saveWithBackSync && postprocessingscript && [[postprocessingscript objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
    }
    @finally {
      if (saveWithBackSync)
      {
        //invoke file watcher notifications before setting backyncIsSaving to NO
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate date]];
        [[NSRunLoop mainRunLoop] runUntilDate:[NSDate date]];
        [self performSelector:@selector(setBackSyncIsSaving:) withObject:@NO afterDelay:0.1];
        //self->backSyncIsSaving = NO;
      }
    }//end @finally
  }//end if (saveWithoutBackSync || saveWithBackSync)
}
//end saveToBackSyncFile

-(void) setBackSyncIsSaving:(NSNumber*)value
{
  self->backSyncIsSaving = value.boolValue;
}
//end setBackSyncIsSaving:

-(IBAction) saveAs:(id)sender
{
  if (!self->backSyncOptions)
    self->backSyncOptions =
      [[PropertyStorage alloc] initWithDictionary:
        @{@"synchronizeEnabled": @NO,
          @"synchronizePreamble": @YES,
          @"synchronizeEnvironment": @YES,
          @"synchronizeBody": @YES}];
  NSBox* accessoryView = [[[NSBox alloc] initWithFrame:NSZeroRect] autorelease];
  accessoryView.autoresizingMask = NSViewWidthSizable|NSViewHeightSizable;
  accessoryView.titlePosition = NSNoTitle;
  accessoryView.borderType = NSNoBorder;
  NSButton* synchronizeEnabledCheckBox = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
  [synchronizeEnabledCheckBox setButtonType:NSSwitchButton];
  [synchronizeEnabledCheckBox setTitle:NSLocalizedString(@"Continuously synchronize file content", @"Continuously synchronize file content")];
  [synchronizeEnabledCheckBox sizeToFit];
  [synchronizeEnabledCheckBox bind:NSValueBinding toObject:self->backSyncOptions withKeyPath:@"synchronizeEnabled" options:nil];
  [accessoryView addSubview:synchronizeEnabledCheckBox];
  NSButton* synchronizePreambleCheckBox = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
  [synchronizePreambleCheckBox setButtonType:NSSwitchButton];
  [synchronizePreambleCheckBox setTitle:NSLocalizedString(@"Synchronize preamble", @"Synchronize preamble")];
  [synchronizePreambleCheckBox sizeToFit];
  [synchronizePreambleCheckBox bind:NSValueBinding toObject:self->backSyncOptions withKeyPath:@"synchronizePreamble" options:nil];
  [synchronizePreambleCheckBox bind:NSEnabledBinding toObject:self->backSyncOptions withKeyPath:@"synchronizeEnabled" options:nil];
  [accessoryView addSubview:synchronizePreambleCheckBox];
  NSButton* synchronizeEnvironmentCheckBox = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
  [synchronizeEnvironmentCheckBox setButtonType:NSSwitchButton];
  [synchronizeEnvironmentCheckBox setTitle:NSLocalizedString(@"Synchronize environment", @"Synchronize environment")];
  [synchronizeEnvironmentCheckBox sizeToFit];
  [synchronizeEnvironmentCheckBox bind:NSValueBinding toObject:self->backSyncOptions withKeyPath:@"synchronizeEnvironment" options:nil];
  [synchronizeEnvironmentCheckBox bind:NSEnabledBinding toObject:self->backSyncOptions withKeyPath:@"synchronizeEnabled" options:nil];
  [accessoryView addSubview:synchronizeEnvironmentCheckBox];
  NSButton* synchronizeBodyCheckBox = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
  [synchronizeBodyCheckBox setButtonType:NSSwitchButton];
  [synchronizeBodyCheckBox setTitle:NSLocalizedString(@"Synchronize body", @"Synchronize body")];
  [synchronizeBodyCheckBox sizeToFit];
  [synchronizeBodyCheckBox bind:NSValueBinding toObject:self->backSyncOptions withKeyPath:@"synchronizeBody" options:nil];
  [synchronizeBodyCheckBox bind:NSEnabledBinding toObject:self->backSyncOptions withKeyPath:@"synchronizeEnabled" options:nil];
  [accessoryView addSubview:synchronizeBodyCheckBox];

  [synchronizeBodyCheckBox setFrameOrigin:NSMakePoint(8+20, 8)];
  [synchronizeEnvironmentCheckBox setFrameOrigin:NSMakePoint(8+20, CGRectGetMaxY(NSRectToCGRect(synchronizeBodyCheckBox.frame))+4)];
  [synchronizePreambleCheckBox setFrameOrigin:NSMakePoint(8+20, CGRectGetMaxY(NSRectToCGRect(synchronizeEnvironmentCheckBox.frame))+4)];
  [synchronizeEnabledCheckBox setFrameOrigin:NSMakePoint(8, CGRectGetMaxY(NSRectToCGRect(synchronizePreambleCheckBox.frame))+4)];
  [accessoryView sizeToFit];
  
  NSSavePanel *panel = [[NSSavePanel savePanel] retain];
  [panel setCanCreateDirectories:YES];
  [panel setCanSelectHiddenExtension:YES];
  panel.allowedFileTypes = @[@"tex"];
  [panel setAllowsOtherFileTypes:YES];
  [panel setExtensionHidden:NO];
  panel.accessoryView = accessoryView;
  panel.nameFieldStringValue = [NSLocalizedString(@"Untitled", @"Untitled") stringByAppendingPathExtension:@"tex"];
  [panel beginSheetModalForWindow:self.windowForSheet completionHandler:^(NSModalResponse returnCode) {
    [self saveAsDidEnd:panel returnCode:returnCode contextInfo:panel];
  }];
}
//end saveAsDidEnd:

-(void) saveAsDidEnd:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void*)contextInfo
{
  NSSavePanel* panel = (NSSavePanel*)contextInfo;
  BOOL synchronizeEnabled =
    [[self->backSyncOptions[@"synchronizeEnabled"] dynamicCastToClass:[NSNumber class]] boolValue];
  if (returnCode == NSFileHandlingPanelOKButton)
  {
    [self closeBackSyncFile];
    NSURL* filename = panel.URL;
    self.fileURL = filename;
    [self save:self];
    if (synchronizeEnabled)
    {
      [self openBackSyncFile:filename.path options:self->backSyncOptions.dictionary];
      [self watcher:nil receivedNotification:UKFileWatcherWriteNotification forPath:self->backSyncFilePath];
    }//end if (synchronizeEnabled)
  }//end if (returnCode == NSFileHandlingPanelOKButton)
  [panel release];
}
//end saveAsDidEnd:returnCode:contextInfo:

-(void) watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString*)nm forPath:(NSString*)fpath
{
  DebugLog(1, @"watcher:<%@> <%@>", nm, fpath);
  @synchronized(self)
  {
    BOOL shouldUpdate = NO;
    if (self->backSyncIsSaving)
      shouldUpdate = NO;
    else if ([fpath isEqualToString:self->backSyncFilePath.stringByDeletingLastPathComponent])
    {
      NSDate* newFileModificationDate = 
        [[[NSFileManager defaultManager] attributesOfItemAtPath:self->backSyncFilePath error:nil]
          fileModificationDate];
      shouldUpdate = newFileModificationDate && 
        (!self->backSyncFileLastModificationDate || [newFileModificationDate isGreaterThan:self->backSyncFileLastModificationDate]);
      if (shouldUpdate && self->backSyncFilePathLinkHasBeenBroken)
      {
        [self->backSyncUkkQueue addPath:self->backSyncFilePath];
        self->backSyncFilePathLinkHasBeenBroken = NO;
      }//end if (shouldUpdate && self->backSyncFilePathLinkHasBeenBroken)
    }//end if ([fpath isEqualToString:[self->backSyncFilePath stringByDeletingLastPathComponent]])
    else if ([nm isEqualToString:UKFileWatcherDeleteNotification])
    {
      self->backSyncFilePathLinkHasBeenBroken = YES;
      if (self->backSyncFilePath)
        [self->backSyncUkkQueue removePath:self->backSyncFilePath];
      shouldUpdate = NO;
    }//end if ([nm isEqualToString:UKFileWatcherDeleteNotification])
    else if ([nm isEqualToString:UKFileWatcherRenameNotification])
    {
      self->backSyncFilePathLinkHasBeenBroken = YES;
      if (self->backSyncFilePath)
        [self->backSyncUkkQueue removePath:self->backSyncFilePath];
      shouldUpdate = NO;
    }//end if ([nm isEqualToString:UKFileWatcherRenameNotification])
    else if ([nm isEqualToString:UKFileWatcherWriteNotification])
      shouldUpdate = YES;
    else if ([nm isEqualToString:UKFileWatcherAttributeChangeNotification])
      shouldUpdate = YES;
    if (shouldUpdate)
    {
      [self->backSyncFileLastModificationDate release];
      self->backSyncFileLastModificationDate =
        [[[[NSFileManager defaultManager] attributesOfItemAtPath:self->backSyncFilePath error:nil]
          fileModificationDate] copy];
      NSStringEncoding encoding;
      NSError* error = nil;

      BOOL shouldUseScripts = (kq != nil);
      NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-%lu", (unsigned long)self->uniqueId];
      NSMutableString* fullLog = [NSMutableString string];
      NSDictionary* fullEnvironment = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];
      NSDictionary* extraEnvironment =
        @{@"CURRENTDIRECTORY": self->backSyncFilePath.stringByDeletingLastPathComponent,
           @"INPUTFILE": self->backSyncFilePath};
      NSMutableDictionary* environment1 = [NSMutableDictionary dictionaryWithDictionary:fullEnvironment];
      [environment1 addEntriesFromDictionary:extraEnvironment];
      PreferencesController* preferencesController = [PreferencesController sharedController];
      NSDictionary* synchronizationAdditionalScripts = preferencesController.synchronizationAdditionalScripts;
      LaTeXProcessor* latexProcessor = [LaTeXProcessor sharedLaTeXProcessor];
      NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
      NSDictionary* compositionConfiguration = preferencesController.compositionConfigurationDocument;

      NSDictionary* preprocessingscript = synchronizationAdditionalScripts[[NSString stringWithFormat:@"%d",SYNCHRONIZATION_SCRIPT_PLACE_LOADING_PREPROCESSING]];
      if (shouldUseScripts && preprocessingscript && [preprocessingscript[CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
      {
        DebugLog(1, @"Pre-processing on load");
        [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Pre-processing on load", @"Pre-processing on load")];
        [fullLog appendFormat:@"%@\n", [latexProcessor descriptionForScript:preprocessingscript]];
        [latexProcessor executeScript:preprocessingscript setEnvironment:environment1 logString:fullLog workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
   compositionConfiguration:compositionConfiguration];
      }//end if (shouldUseScripts && preprocessingscript && [[preprocessingscript objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
      
      NSString* string = [NSString stringWithContentsOfFile:self->backSyncFilePath guessEncoding:&encoding error:&error];

      NSDictionary* postprocessingscript = synchronizationAdditionalScripts[[NSString stringWithFormat:@"%d",SYNCHRONIZATION_SCRIPT_PLACE_LOADING_POSTPROCESSING]];
      if (shouldUseScripts && postprocessingscript && [postprocessingscript[CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])
      {
        DebugLog(1, @"Post-processing on load");
        [fullLog appendFormat:@"\n\n>>>>>>>> %@ script <<<<<<<<\n", NSLocalizedString(@"Post-processing on load", @"Post-processing on load")];
        [fullLog appendFormat:@"%@\n", [latexProcessor descriptionForScript:preprocessingscript]];
        [latexProcessor executeScript:postprocessingscript setEnvironment:environment1 logString:fullLog workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
             compositionConfiguration:compositionConfiguration];
      }//end if (shouldUseScripts && postprocessingscript && [[postprocessingscript objectForKey:CompositionConfigurationAdditionalProcessingScriptEnabledKey] boolValue])

      BOOL synchronizePreamble =
        [[self->backSyncOptions[@"synchronizePreamble"] dynamicCastToClass:[NSNumber class]] boolValue];
      BOOL synchronizeEnvironment =
        [[self->backSyncOptions[@"synchronizeEnvironment"] dynamicCastToClass:[NSNumber class]] boolValue];
      BOOL synchronizeBody =
        [[self->backSyncOptions[@"synchronizeBody"] dynamicCastToClass:[NSNumber class]] boolValue];
      [self updateDocumentFromString:string updatePreamble:synchronizePreamble updateEnvironment:synchronizeEnvironment updateBody:synchronizeBody];
    }//end if ([nm isEqualToString:UKFileWatcherRenameNotification])
  }//end @synchronized(self)
}
//end watcher:receivedNotification:

-(void) updateDocumentFromString:(NSString*)string updatePreamble:(BOOL)updatePreamble updateEnvironment:(BOOL)updateEnvironment updateBody:(BOOL)updateBody
{
  if (string)
  {
    NSArray* components =
      [string captureComponentsMatchedByRegex:@"^\\s*(.*)\\s*\\\\begin\\{document\\}\\s*(.*)\\s*\\\\end\\{document\\}.*$"
                                      options:RKLDotAll range:NSMakeRange(0, string.length) error:nil];
    BOOL hasPreambleAndBody = (components.count == 3);
    NSString* preamble = !hasPreambleAndBody ? nil : components[1];
    NSString* body = !hasPreambleAndBody ? string : components[2];
    components = nil;
    latex_mode_t latexMode = LATEX_MODE_TEXT;
    if (updateEnvironment)
    {
      components = (latexMode != LATEX_MODE_TEXT) ? nil :
      [body captureComponentsMatchedByRegex:@"^\\s*\\\\begin\\{align\\*\\}(.*)\\\\end\\{align\\*\\}\\s*$"
                                    options:RKLDotAll range:NSMakeRange(0, body.length) error:nil];
      if (components && (components.count == 2))
      {
        latexMode = LATEX_MODE_ALIGN;
        body = components[1];
      }//end if (components && ([components count] == 2))
      
      components = (latexMode != LATEX_MODE_TEXT) ? nil :
      [body captureComponentsMatchedByRegex:@"^\\s*\\$\\$(.*)\\$\\$\\s*$"
                                    options:RKLDotAll range:NSMakeRange(0, body.length) error:nil];
      if (components && (components.count == 2))
      {
        latexMode = LATEX_MODE_DISPLAY;
        body = components[1];
      }//end if (components && ([components count] == 2))
      
      components = (latexMode != LATEX_MODE_TEXT) ? nil :
      [body captureComponentsMatchedByRegex:@"^\\s*\\$\\displayStyle(.*)\\$\\$\\s*$"
                                    options:RKLDotAll range:NSMakeRange(0, body.length) error:nil];
      if (components && (components.count == 2))
      {
        latexMode = LATEX_MODE_DISPLAY;
        body = components[1];
      }//end if (components && ([components count] == 2))
      
      components = (latexMode != LATEX_MODE_TEXT) ? nil :
      [body captureComponentsMatchedByRegex:@"^\\s*\\\\\\[(.*)\\\\\\]\\s*$"
                                    options:RKLDotAll range:NSMakeRange(0, body.length) error:nil];
      if (components && (components.count == 2))
      {
        latexMode = LATEX_MODE_DISPLAY;
        body = components[1];
      }//end if (components && ([components count] == 2))
      
      components = (latexMode != LATEX_MODE_TEXT) ? nil :
      [body captureComponentsMatchedByRegex:@"^\\s*\\$(.*)\\$\\s*$"
                                    options:RKLDotAll range:NSMakeRange(0, body.length) error:nil];
      if (components && (components.count == 2))
      {
        latexMode = LATEX_MODE_INLINE;
        body = components[1];
      }//end if (components && ([components count] == 2))
    }//end if (updateEnvironment)
    
    if (updatePreamble && [preamble trim].length)
      [self setPreamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]];
    if (updateBody && body)
      self->lowerBoxSourceTextView.string = body;
    self.latexModeApplied = latexMode;
  }//end if (string)
}
//end updateDocumentFromString:updatePreamble:updateEnvironment:updateBody:

@end
