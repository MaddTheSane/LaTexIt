//  AppController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005 PierreChatelier. All rights reserved.

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

@class EncapsulationController;
@class MarginController;
@class LatexPalettesController;
@class PreferencesController;

@interface AppController : NSObject <LinkBackServerDelegate> {
  //Shared Interface elements
  IBOutlet NSMenuItem* showPreambleMenuItem;
  IBOutlet NSMenuItem* showHistoryMenuItem;
  IBOutlet NSMenuItem* showLibraryMenuItem;
  
  IBOutlet NSWindow*   readmeWindow;
  IBOutlet NSTextView* readmeTextView;
  
  //some info on current configuration
  BOOL isPdfLatexAvailable;
  BOOL isGsAvailable;
  BOOL isDvipdfAvailable;
  BOOL isColorStyAvailable;

  EncapsulationController* encapsulationController;
  MarginController*        marginController;
  LatexPalettesController* latexPalettesController;
  PreferencesController*   preferencesController;
}

+(AppController*) appController; //getting the unique instance of appController

+(NSArray*) unixBins; //usual unix PATH
+(NSDictionary*) environmentDict; //environment useful to call programs on the command line

//the menu actions
-(IBAction) openWebSite:(id)sender;//ask for LaTeXiT's web site
-(IBAction) checkUpdates:(id)sender;//check for updates on LaTeXiT's web site

-(IBAction) paste:(id)sender;

-(IBAction) exportImage:(id)sender;
-(IBAction) makeLatex:(id)sender;
-(IBAction) displayLog:(id)sender;
-(IBAction) showOrHideColorInspector:(id)sender;
-(IBAction) showOrHidePreamble:(id)sender;
-(IBAction) showOrHideHistory:(id)sender;
-(IBAction) showOrHideLibrary:(id)sender;
-(IBAction) showOrHideEncapsulation:(id)sender;
-(IBAction) showOrHideMargin:(id)sender;
-(IBAction) showOrHideLatexPalettes:(id)sender;
-(IBAction) removeHistoryEntries:(id)sender;
-(IBAction) clearHistory:(id)sender;
-(IBAction) latexPalettesClick:(id)sender;
-(IBAction) showPreferencesPane:(id)sender;
-(void)     showPreferencesPaneWithIdentifier:(id)identifier;//showPreferencesPane + select one tab
-(IBAction) showHelp:(id)sender;

-(IBAction) addCurrentEquationToLibrary:(id)sender;
-(IBAction) newLibraryFolder:(id)sender;
-(IBAction) removeLibraryItems:(id)sender;
-(IBAction) refreshLibraryItems:(id)sender;
-(IBAction) loadLibrary:(id)sender;
-(IBAction) saveLibrary:(id)sender;

-(void) menuNeedsUpdate:(NSMenu*)menu;

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
-(BOOL) isColorStyAvailable;

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

//LinkBackServerDelegateProtocol
-(void) linkBackDidClose:(LinkBack*)link;
-(void) linkBackClientDidRequestEdit:(LinkBack*)link;

@end
