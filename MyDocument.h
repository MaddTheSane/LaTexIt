//  MyDocument.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

// The main document of LaTeXiT. There is much to say !

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class AppController;
@class DocumentExtraPanelsController;
@class ImagePopupButton;
@class LatexitEquation;
@class LibraryEquation;
@class LineCountTextView;
@class LinkBack;
@class LogTableView;
@class MyImageView;
@class MySplitView;

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
  IBOutlet NSSegmentedControl*  lowerBoxControlsBoxLatexModeSegmentedControl;
  IBOutlet NSTextField*         lowerBoxControlsBoxFontSizeLabel;
  IBOutlet NSTextField*         lowerBoxControlsBoxFontSizeTextField;
  IBOutlet NSTextField*         lowerBoxControlsBoxFontColorLabel;
  IBOutlet NSColorWell*         lowerBoxControlsBoxFontColorWell;
  IBOutlet NSButton*            lowerBoxLatexizeButton;

  DocumentExtraPanelsController* documentExtraPanelsController;

  NSString*        documentTitle;  
  NSRect           documentFrameSaved;
  NSRect           unzoomedFrame;
  NSSize           documentNormalMinimumSize;
  NSSize           documentMiniMinimumSize;
  NSSize           lowerBoxControlsBoxLatexModeSegmentedControlMinimumSize;
  document_style_t documentStyle;
  unsigned long    uniqueId;
  NSDictionary*    lastRequestedBodyTemplate;
  
  NSMutableString* lastExecutionLog;

  LinkBack* linkBackLink;//linkBack link, may be nil (most of the time, in fact)
  NSString* initialPreamble;
  NSString* initialBody;
  NSData*   initialPdfData;
  
  LibraryEquation* lastAppliedLibraryEquation;
  BOOL             isReducedTextArea;
  BOOL             isBusy;
}

//interface changing
-(BOOL) isReducedTextArea;
-(void) setReducedTextArea:(BOOL)reduce;
-(document_style_t) documentStyle;
-(void) setDocumentStyle:(document_style_t)value;

//actions from menu (through the appController), or from self contained elements
-(IBAction) latexize:(id)sender;
-(IBAction) latexizeAndExport:(id)sender;
-(IBAction) displayLastLog:(id)sender;

-(IBAction) exportImage:(id)sender;
-(IBAction) reexportImage:(id)sender;
-(IBAction) changePreamble:(id)sender;
-(IBAction) changeBodyTemplate:(id)sender;

-(MyImageView*) imageView;
-(NSButton*)    lowerBoxLatexizeButton;
-(NSResponder*) preferredFirstResponder;

-(void) gotoLine:(int)row;

-(void) setNullId;//useful for dummy document of AppController
-(void) setDocumentTitle:(NSString*)title;

-(LibraryEquation*) lastAppliedLibraryEquation;
-(void) setLastAppliedLibraryEquation:(LibraryEquation*)value;

-(latex_mode_t) latexMode;
-(void) setLatexMode:(latex_mode_t)mode;
-(void) setColor:(NSColor*)color;
-(void) setMagnification:(CGFloat)magnification;

//updates interface according to whether the latexisation is possible or not
-(void) updateGUIfromSystemAvailabilities;
//tells whether the document is currently performing a latexisation
-(BOOL) isBusy;

-(void) setFont:(NSFont*)font;//changes the font of both preamble and sourceText views
-(void) setPreamble:(NSAttributedString*)aString;   //fills the preamble textfield
-(void) setSourceText:(NSAttributedString*)aString; //fills the body     textfield

-(void) setBodyTemplate:(NSDictionary*)bodyTemplate moveCursor:(BOOL)moveCursor;

-(BOOL) canReexport;
-(BOOL) hasImage;
-(BOOL) isPreambleVisible;
-(void) setPreambleVisible:(BOOL)visible animate:(BOOL)animate;

//text actions in the first responder
-(NSString*) selectedText;
-(void) insertText:(NSString*)text;

-(LatexitEquation*) latexitEquationWithCurrentState;
-(BOOL) applyPdfData:(NSData*)pdfData;              //updates the document according to the given pdfdata
-(void) applyLibraryEquation:(LibraryEquation*)libraryEquation;
-(void) applyLatexitEquation:(LatexitEquation*)latexitEquation; //updates the document according to the given history item
-(void) applyString:(NSString*)string;//updates the document according to the given source string, that is to be decomposed in preamble+body

//linkback live link management
-(LinkBack*) linkBackLink;
-(void) setLinkBackLink:(LinkBack*)link;
-(void) closeLinkBackLink:(LinkBack*)link;

@end
