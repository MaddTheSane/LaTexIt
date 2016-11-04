//  MyDocument.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.

// The main document of LaTeXiT. There is much to say !

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"
#import "UKKQueue.h"

@class AppController;
@class DocumentExtraPanelsController;
@class ExportFormatOptionsPanes;
@class ImagePopupButton;
@class LatexitEquation;
@class LibraryEquation;
@class LineCountTextView;
@class LinkBack;
@class LogTableView;
@class MyImageView;
@class MySplitView;
@class PropertyStorage;

@interface MyDocument : NSDocument
{
  IBOutlet NSBox*               upperBox;
  IBOutlet NSBox*               upperImageBox;
  IBOutlet MyImageView*         upperBoxImageView;
  IBOutlet LogTableView*        upperBoxLogTableView;
  IBOutlet NSProgressIndicator* upperBoxProgressIndicator;
  IBOutlet NSBox*               upperBoxZoomBox;
  IBOutlet NSSlider*            upperBoxZoomBoxSlider;

  IBOutlet NSBox*               lowerBox;
  IBOutlet MySplitView*         lowerBoxSplitView;
  IBOutlet LineCountTextView*   lowerBoxPreambleTextView;
  IBOutlet LineCountTextView*   lowerBoxSourceTextView;
  IBOutlet ImagePopupButton*    lowerBoxChangePreambleButton;
  IBOutlet ImagePopupButton*    lowerBoxChangeBodyTemplateButton;
  IBOutlet NSBox*               lowerBoxControlsBox;
  IBOutlet NSView*              lowerBoxControlsBoxLatexModeView;
  IBOutlet NSButton*            lowerBoxControlsBoxLatexModeAutoButton;
  IBOutlet NSSegmentedControl*  lowerBoxControlsBoxLatexModeSegmentedControl;
  IBOutlet NSTextField*         lowerBoxControlsBoxFontSizeLabel;
  IBOutlet NSTextField*         lowerBoxControlsBoxFontSizeTextField;
  IBOutlet NSTextField*         lowerBoxControlsBoxFontColorLabel;
  IBOutlet NSColorWell*         lowerBoxControlsBoxFontColorWell;
  IBOutlet NSButton*            lowerBoxLinkbackButton;
  IBOutlet NSButton*            lowerBoxLatexizeButton;

  IBOutlet NSNumberFormatter*   pointSizeFormatter;

  DocumentExtraPanelsController* documentExtraPanelsController;

  NSString*        documentTitle;  
  NSRect           documentFrameSaved;
  NSRect           unzoomedFrame;
  NSSize           documentNormalMinimumSize;
  NSSize           documentMiniMinimumSize;
  NSSize           lowerBoxControlsBoxLatexModeSegmentedControlMinimumSize;
  document_style_t documentStyle;
  latex_mode_t     latexModeRequested;
  latex_mode_t     latexModeApplied;
  NSUInteger       uniqueId;
  NSDictionary*    lastRequestedBodyTemplate;
  
  NSMutableString* lastExecutionLog;

  LinkBack*        linkBackLink;//linkBack link, may be nil (most of the time, in fact)
  LibraryEquation* linkedLibraryEquation;
  BOOL             isObservingLibrary;
  BOOL             linkBackAllowed;

  NSString* initialUTI;
  NSData*   initialData;
  NSString* initialPreamble;
  NSString* initialBody;
  
  LibraryEquation* lastAppliedLibraryEquation;
  BOOL             isReducedTextArea;
  NSString*        busyIdentifier;
  int              nbBackgroundLatexizations;
  BOOL             isClosed;
  NSMutableArray*  poolOfObsoleteUniqueIds;
  
  BOOL             currentEquationIsARecentLatexisation;
  NSResponder*     lastFirstResponder;
  
  BOOL shouldApplyToPasteboardAfterLatexization;
  
  UKKQueue* backSyncUkkQueue;
  NSString* backSyncFilePath;
  BOOL      backSyncFilePathLinkHasBeenBroken;
  NSDate*   backSyncFileLastModificationDate;
  PropertyStorage* backSyncOptions;
  BOOL      backSyncIsSaving;
}

//interface changing
-(BOOL) isReducedTextArea;
-(void) setReducedTextArea:(BOOL)reduce;
-(document_style_t) documentStyle;
-(void) setDocumentStyle:(document_style_t)value;
-(void) toggleDocumentStyle;

-(IBAction) changeLatexModeAuto:(id)sender;

//actions from menu (through the appController), or from self contained elements
-(IBAction) latexize:(id)sender;
-(IBAction) latexizeAndExport:(id)sender;
-(IBAction) displayLastLog:(id)sender;

-(IBAction) exportImage:(id)sender;
-(IBAction) reexportImage:(id)sender;
-(IBAction) changePreamble:(id)sender;
-(IBAction) changeBodyTemplate:(id)sender;

-(void) formatChangeAlignment:(alignment_mode_t)value;
-(void) formatComment:(id)sender;
-(void) formatUncomment:(id)sender;

-(MyImageView*) imageView;
-(NSButton*)    lowerBoxLatexizeButton;
-(NSResponder*) preferredFirstResponder;
-(NSResponder*) previousFirstResponder;

-(void) gotoLine:(int)row;

-(void) setNullId;//useful for dummy document of AppController
-(void) setDocumentTitle:(NSString*)title;

-(LibraryEquation*) lastAppliedLibraryEquation;
-(void) setLastAppliedLibraryEquation:(LibraryEquation*)value;

-(latex_mode_t) detectLatexMode;
-(latex_mode_t) latexModeApplied;
-(void) setLatexModeApplied:(latex_mode_t)value;
-(latex_mode_t) latexModeRequested;
-(void) setLatexModeRequested:(latex_mode_t)value;
-(void) setColor:(NSColor*)color;
-(void) setMagnification:(CGFloat)magnification;

//updates interface according to whether the latexisation is possible or not
-(void) updateGUIfromSystemAvailabilities;
//tells whether the document is currently performing a latexisation
-(BOOL) isBusy;
-(void) setBusyIdentifier:(NSString*)value;

-(void) setFont:(NSFont*)font;//changes the font of both preamble and sourceText views
-(void) setPreamble:(NSAttributedString*)aString;   //fills the preamble textfield
-(void) setSourceText:(NSAttributedString*)aString; //fills the body     textfield

-(void) setBodyTemplate:(NSDictionary*)bodyTemplate moveCursor:(BOOL)moveCursor;

-(BOOL) canReexport;
-(BOOL) hasImage;
-(BOOL) isPreambleVisible;
-(void) setPreambleVisible:(BOOL)visible animate:(BOOL)animate;

-(BOOL) shouldApplyToPasteboardAfterLatexization;
-(void) setShouldApplyToPasteboardAfterLatexization:(BOOL)value;

//text actions in the first responder
-(NSString*) selectedText;
-(void) insertText:(id)text;

-(LatexitEquation*) latexitEquationWithCurrentStateTransient:(BOOL)transient;
-(BOOL) applyData:(NSData*)data sourceUTI:(NSString*)sourceUTI; //updates the document according to the given data
-(void) applyLibraryEquation:(LibraryEquation*)libraryEquation;
-(void) applyLatexitEquation:(LatexitEquation*)latexitEquation isRecentLatexisation:(BOOL)isRecentLatexisation; //updates the document according to the given history item
-(void) applyString:(NSString*)string;//updates the document according to the given source string, that is to be decomposed in preamble+body
-(void) updateDocumentFromString:(NSString*)string updatePreamble:(BOOL)updatePreamble updateEnvironment:(BOOL)updateEnvironment updateBody:(BOOL)updateBody;

-(void) triggerSmartHistoryFeature;

//linkback live link management
-(LinkBack*) linkBackLink;
-(void) setLinkBackLink:(LinkBack*)link;
-(BOOL) linkBackAllowed;
-(void) setLinkBackAllowed:(BOOL)value;

-(LibraryEquation*) linkedLibraryEquation;
-(void) setLinkedLibraryEquation:(LibraryEquation*)libraryEquation;
-(void) closeLinkedLibraryEquation:(LibraryEquation*)libraryEquation;

//NSWindowDelegate
-(void) windowDidResize:(NSNotification*)notification;
//NSSplitViewDelegate
-(void) splitViewDidResizeSubviews:(NSNotification*)notification;

//backsync file
-(BOOL) hasBackSyncFile;
-(void) closeBackSyncFile;
-(void) openBackSyncFile:(NSString*)path options:(NSDictionary*)options;
-(IBAction) save:(id)sender;
-(IBAction) saveAs:(id)sender;

@end

@interface MyDocumentWindow : NSWindow
@end
