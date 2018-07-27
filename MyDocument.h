//  MyDocument.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright Pierre Chatelier 2005 . All rights reserved.

// The main document of LaTeXiT. There is much to say !

#import <Cocoa/Cocoa.h>

@class HistoryItem;
@class LineCountTextView;
@class LinkBack;
@class LogTableView;
@class MyImageView;

//useful to differenciate the different latex modes : DISPLAY (\[...\]), INLINE ($...$) and TEXT (text)
typedef enum {DISPLAY, INLINE, TEXT} latex_mode_t;

@interface MyDocument : NSDocument
{
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
  
  IBOutlet NSView*        saveAccessoryView;
  IBOutlet NSPopUpButton* saveAccessoryViewPopupFormat;
  IBOutlet NSButton*      saveAccessoryViewOptionsButton;
  IBOutlet NSPanel*       saveAccessoryViewOptionsPane;
  IBOutlet NSButton*      saveAccessoryViewJpegWarning;
  IBOutlet NSSlider*      jpegQualitySlider;
  IBOutlet NSTextField*   jpegQualityTextField;
  IBOutlet NSColorWell*   jpegColorWell;

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
}

//actions from menu (through the appController), or from self contained elements
-(IBAction) makeLatex:(id)sender;
-(IBAction) displayLastLog:(id)sender;

-(IBAction) exportImage:(id)sender;
-(IBAction) openOptions:(id)sender;
-(IBAction) closeOptionsPane:(id)sender;
-(IBAction) jpegQualitySliderDidChange:(id)sender;
-(IBAction) saveAccessoryViewPopupFormatDidChange:(id)sender;

-(void) setNullId;//useful for dummy document of AppController
-(void) setDocumentTitle:(NSString*)title;

//some accessors useful sometimes
-(LineCountTextView*) sourceTextView;
-(NSButton*) makeLatexButton;

//latexise and returns the pdf result, cropped, magnified, coloured, with pdf meta-data
-(NSData*) latexiseWithPreamble:(NSString*)preamble body:(NSString*)body color:(NSColor*)color mode:(latex_mode_t)mode
                  magnification:(double)magnification;

//updates interface according to whether the latexisation is possible or not
-(void) updateAvailabilities;
//tells whether the document is currently performing a latexisation
-(BOOL) isBusy;

-(void) setFont:(NSFont*)font;//changes the font of both preamble and sourceText views
-(void) setPreamble:(NSAttributedString*)aString;   //fills the preamble textfield
-(void) setSourceText:(NSAttributedString*)aString; //fills the body     textfield

-(BOOL) hasImage;
-(BOOL) isPreambleVisible;
-(void) setPreambleVisible:(BOOL)visible;

//text actions in the first responder
-(NSString*) selectedText;
-(void) insertText:(NSString*)text;

-(HistoryItem*) historyItemWithCurrentState;        //creates a history item with the current state of the document
-(void) applyPdfData:(NSData*)pdfData;              //updates the document according to the given pdfdata
-(void) applyHistoryItem:(HistoryItem*)historyItem; //updates the document according to the given history item

//linkback live link management
-(LinkBack*) linkBackLink;
-(void) setLinkBackLink:(LinkBack*)link;
-(void) closeLinkBackLink:(LinkBack*)link;

@end
