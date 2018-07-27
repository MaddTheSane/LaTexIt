//  MyDocument.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

// The main document of LaTeXiT. There is much to say !

#import <Cocoa/Cocoa.h>

#import "AppController.h"

@class HistoryItem;
@class ImagePopupButton;
@class LibraryFile;
@class LineCountTextView;
@class LinkBack;
@class LogTableView;
@class MyImageView;

@interface MyDocument : NSDocument
{
  IBOutlet NSBox*               upperBox;
  IBOutlet NSBox*               lowerBox;
  BOOL                          isReducedTextArea;

  IBOutlet ImagePopupButton*    changePreambleButton;
  IBOutlet NSSplitView*         splitView;
  IBOutlet LineCountTextView*   preambleTextView;
  IBOutlet LineCountTextView*   sourceTextView;
  IBOutlet MyImageView*         imageView;
  IBOutlet NSColorWell*         colorWell;
  IBOutlet NSTextField*         sizeText;
  IBOutlet NSButton*            makeLatexButton;
  IBOutlet LogTableView*        logTableView;
  IBOutlet NSSegmentedControl*  typeOfTextControl;
  IBOutlet NSWindow*            logWindow;
  IBOutlet NSTextView*          logTextView;
  IBOutlet NSProgressIndicator* progressIndicator;
  IBOutlet NSMenu*              copyAsContextualMenuItem;
  
  IBOutlet NSView*        saveAccessoryView;
  IBOutlet NSPopUpButton* saveAccessoryViewPopupFormat;
  IBOutlet NSButton*      saveAccessoryViewOptionsButton;
  IBOutlet NSPanel*       saveAccessoryViewOptionsPane;
  IBOutlet NSButton*      saveAccessoryViewJpegWarning;
  IBOutlet NSSlider*      jpegQualitySlider;
  IBOutlet NSTextField*   jpegQualityTextField;
  IBOutlet NSColorWell*   jpegColorWell;
  IBOutlet NSTextField*   saveAccessoryViewScaleAsPercentTextField;
  
  IBOutlet NSProgressIndicator* progressMessageProgressIndicator;
  IBOutlet NSTextField*         progressMessageTextField;

  NSString*    documentTitle;
  
  NSColor*     jpegColor;
  float        jpegQuality;
  NSSavePanel* currentSavePanel;
  
  NSString* initialPreamble;
  NSString* initialBody;
  NSData*   initialPdfData;
  
  BOOL isBusy;
  
  unsigned long uniqueId;
  
  LinkBack* linkBackLink;//linkBack link, may be nil (most of the time, in fact)
  
  LibraryFile* lastAppliedLibraryFile;
}

//interface changing
-(BOOL) isReducedTextArea;
-(void) setReducedTextArea:(BOOL)reduce;

//updates load progress indicator and messages
-(void) startMessageProgress:(NSString*)message;
-(void) stopMessageProgress;

//actions from menu (through the appController), or from self contained elements
-(IBAction) makeLatex:(id)sender;
-(IBAction) makeLatexAndExport:(id)sender;
-(IBAction) displayLastLog:(id)sender;

-(IBAction) exportImage:(id)sender;
-(IBAction) reexportImage:(id)sender;
-(IBAction) openOptions:(id)sender;
-(IBAction) closeOptionsPane:(id)sender;
-(IBAction) jpegQualitySliderDidChange:(id)sender;
-(IBAction) saveAccessoryViewPopupFormatDidChange:(id)sender;
-(IBAction) changePreamble:(id)sender;
-(IBAction) nullAction:(id)sender;

-(void) setNullId;//useful for dummy document of AppController
-(void) setDocumentTitle:(NSString*)title;

//some accessors useful sometimes
-(LineCountTextView*) sourceTextView;
-(NSButton*) makeLatexButton;
-(MyImageView*) imageView;

-(LibraryFile*) lastAppliedLibraryFile;
-(void) setLastAppliedLibraryFile:(LibraryFile*)libraryFile;

-(void) setLatexMode:(latex_mode_t)mode;
-(void) setColor:(NSColor*)color;
-(void) setMagnification:(float)magnification;
-(void) executeScript:(NSDictionary*)script setEnvironment:(NSDictionary*)environment logString:(NSMutableString*)logString;

//updates interface according to whether the latexisation is possible or not
-(void) updateAvailabilities:(NSNotification*)notification;
//tells whether the document is currently performing a latexisation
-(BOOL) isBusy;

-(void) resetSyntaxColoring;//reapply syntax coloring
-(void) setFont:(NSFont*)font;//changes the font of both preamble and sourceText views
-(void) setPreamble:(NSAttributedString*)aString;   //fills the preamble textfield
-(void) setSourceText:(NSAttributedString*)aString; //fills the body     textfield

-(BOOL) canReexport;
-(BOOL) hasImage;
-(BOOL) isPreambleVisible;
-(void) setPreambleVisible:(BOOL)visible;

//text actions in the first responder
-(NSString*) selectedText;
-(void) insertText:(NSString*)text;

-(HistoryItem*) historyItemWithCurrentState;        //creates a history item with the current state of the document
-(BOOL) applyPdfData:(NSData*)pdfData;              //updates the document according to the given pdfdata
-(void) applyLibraryFile:(LibraryFile*)libraryFile; //updates the document according to the given library file
-(void) applyHistoryItem:(HistoryItem*)historyItem; //updates the document according to the given history item
-(void) applyString:(NSString*)string;//updates the document according to the given source string, that is to be decomposed in preamble+body

//linkback live link management
-(LinkBack*) linkBackLink;
-(void) setLinkBackLink:(LinkBack*)link;
-(void) closeLinkBackLink:(LinkBack*)link;

@end
