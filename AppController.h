//  AppController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The AppController is a singleton, a unique instance that acts as a bridge between the menu and the documents.
//It is also responsible for shared operations (like utilities : finding a program)
//It is also a bridge for the application service : it creates a dummy, invisible document that will perform
//the latexisation
//It is also the LinkBack server

#import <Cocoa/Cocoa.h>

#ifdef PANTHER
#import <LinkBack-panther/LinkBack.h>
#else
#import <LinkBack/LinkBack.h>
#endif

//useful to differenciate the different latex modes : DISPLAY (\[...\]), INLINE ($...$) and TEXT (text)
typedef enum {LATEX_MODE_DISPLAY, LATEX_MODE_INLINE, LATEX_MODE_TEXT} latex_mode_t;

@class EncapsulationController;
@class HistoryController;
@class MarginController;
@class LatexPalettesController;
@class LibraryController;
@class MyDocument;
@class PreferencesController;

@interface AppController : NSObject <LinkBackServerDelegate> {  
  IBOutlet NSWindow*   readmeWindow;
  IBOutlet NSTextView* readmeTextView;
  
  //some info on current configuration
  BOOL isPdfLatexAvailable;
  BOOL isGsAvailable;
  BOOL isDvipdfAvailable;
  BOOL isXeLatexAvailable;
  BOOL isLatexAvailable;
  BOOL isColorStyAvailable;

  EncapsulationController* encapsulationController;
  HistoryController*       historyController;
  LatexPalettesController* latexPalettesController;
  LibraryController*       libraryController;
  MarginController*        marginController;
  PreferencesController*   preferencesController;
}

+(AppController*)           appController; //getting the unique instance of appController
+(NSDocument*)              currentDocument;
-(NSDocument*)              currentDocument;
-(EncapsulationController*) encapsulationController;
-(HistoryController*)       historyController;
-(LatexPalettesController*) latexPalettesController;
-(LibraryController*)       libraryController;
-(MarginController*)        marginController;
-(PreferencesController*)   preferencesController;

+(NSArray*) unixBins; //usual unix PATH
+(NSDictionary*) environmentDict; //environment useful to call programs on the command line

//the menu actions
-(IBAction) openWebSite:(id)sender;//ask for LaTeXiT's web site
-(IBAction) checkUpdates:(id)sender;//check for updates on LaTeXiT's web site

-(IBAction) copyEquation:(id)sender;
-(IBAction) paste:(id)sender;

-(IBAction) exportImage:(id)sender;
-(IBAction) makeLatex:(id)sender;
-(IBAction) displayLog:(id)sender;

-(IBAction) historyRemoveHistoryEntries:(id)sender;
-(IBAction) historyClearHistory:(id)sender;
-(IBAction) showOrHideHistory:(id)sender;

-(IBAction) libraryImportCurrent:(id)sender; //creates a library item with the current document state
-(IBAction) libraryNewFolder:(id)sender;     //creates a folder
-(IBAction) libraryRemoveSelectedItems:(id)sender;    //removes some items
-(IBAction) libraryRefreshItems:(id)sender;   //refresh an item
-(IBAction) libraryOpen:(id)sender;
-(IBAction) librarySaveAs:(id)sender;
-(IBAction) showOrHideLibrary:(id)sender;

-(IBAction) showOrHideColorInspector:(id)sender;
-(IBAction) showOrHidePreamble:(id)sender;
-(IBAction) showOrHideEncapsulation:(id)sender;
-(IBAction) showOrHideMargin:(id)sender;
-(IBAction) showOrHideLatexPalettes:(id)sender;
-(IBAction) latexPalettesClick:(id)sender;
-(IBAction) showPreferencesPane:(id)sender;
-(void)     showPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier;//showPreferencesPane + select one pane
-(IBAction) showHelp:(id)sender;

-(MyDocument*) dummyDocument;

//utility : finds a program in the unix environment. You can give an environment, and
//some "prefixes", that is to say an array of PATH in which the program could be
-(NSString*) findUnixProgram:(NSString*)programName tryPrefixes:(NSArray*)prefixes
                 environment:(NSDictionary*)environment;

//returns the default preamble. If color.sty is not available, it may add % in front of \usepackage{color}
-(NSAttributedString*) preamble;

//returns some configuration info
-(BOOL) isPdfLatexAvailable;
-(BOOL) isGsAvailable;
-(BOOL) isDvipdfAvailable;
-(BOOL) isXeLatexAvailable;
-(BOOL) isLatexAvailable;
-(BOOL) isColorStyAvailable;

//if the marginController is not loaded, just use the user defaults values
-(float) marginControllerTopMargin;
-(float) marginControllerBottomMargin;
-(float) marginControllerLeftMargin;
-(float) marginControllerRightMargin;

//modifies the \usepackage{color} line of the preamble in order to use the given color
-(NSString*) insertColorInPreamble:(NSString*)thePreamble color:(NSColor*)theColor;

//returns data representing data derived from pdfData, but in the format specified (pdf, eps, tiff, png...)
-(NSData*) dataForType:(NSString*)format pdfData:(NSData*)pdfData jpegColor:(NSColor*)color jpegQuality:(float)quality;

//returns a file icon to represent the given PDF data; if not specified (nil), the backcground color will be half-transparent
-(NSImage*) makeIconForData:(NSData*)pdfData backgroundColor:(NSColor*)backgroundColor;

//annotates data in LEE format
-(NSData*) annotatePdfDataInLEEFormat:(NSData*)data preamble:(NSString*)preamble source:(NSString*)source color:(NSColor*)color
                                 mode:(mode_t)mode magnification:(double)magnification baseline:(double)baseline
                                 backgroundColor:(NSColor*)backgroundColor;

//methods for the application service
-(void) serviceLatexisationDisplay:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationInline:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) changeServiceShortcut:(NSString*)shortCut forMode:(latex_mode_t)mode;

//LinkBackServerDelegateProtocol
-(void) linkBackDidClose:(LinkBack*)link;
-(void) linkBackClientDidRequestEdit:(LinkBack*)link;

@end
