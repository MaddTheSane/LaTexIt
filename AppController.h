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

@class MyDocument;
@class MarginController;
@class PalettesController;
@class PreferencesController;

@interface AppController : NSObject <LinkBackServerDelegate> {
  //Shared Interface elements
  IBOutlet NSMenuItem* showHistoryMenuItem;
  IBOutlet NSMenuItem* showLibraryMenuItem;
  IBOutlet NSMenuItem* marginMenuItem;
  IBOutlet NSMenuItem* paletteMenuItem;
  
  IBOutlet NSWindow*   readmeWindow;
  IBOutlet NSTextView* readmeTextView;
  
  //some info on current configuration
  BOOL isPdfLatexAvailable;
  BOOL isGsAvailable;
  BOOL isColorStyAvailable;
  
  MyDocument* myDocumentServiceProvider; //dummy document for the application service
  MarginController*      marginController;
  PalettesController*    palettesController;
  PreferencesController* preferencesController;
}

+(AppController*) appController; //getting the unique instance of appController

+(NSArray*) unixBins; //usual unix PATH
+(NSDictionary*) environmentDict; //environment useful to call programs on the command line

//the menu actions
-(IBAction) openWebSite:(id)sender;//ask for LaTeXiT's web site

-(IBAction) exportImage:(id)sender;
-(IBAction) makeLatex:(id)sender;
-(IBAction) displayLog:(id)sender;
-(IBAction) showOrHideHistory:(id)sender;
-(IBAction) showOrHideLibrary:(id)sender;
-(IBAction) showOrHidePalette:(id)sender;
-(IBAction) showOrHideMargin:(id)sender;
-(IBAction) removeHistoryEntries:(id)sender;
-(IBAction) clearHistory:(id)sender;
-(IBAction) paletteClick:(id)sender;
-(IBAction) showPreferencesPane:(id)sender;
-(IBAction) showHelp:(id)sender;

-(IBAction) addCurrentEquationToLibrary:(id)sender;
-(IBAction) addLibraryFolder:(id)sender;
-(IBAction) removeLibraryItems:(id)sender;
-(IBAction) refreshLibraryItems:(id)sender;

-(void) menuNeedsUpdate:(NSMenu*)menu;

-(NSDocument*) currentDocument; //active document, nil if no document opened

//utility : finds a program in the unix environment. You can give an environment, and
//some "prefixes", that is to say an array of PATH in which the program could be
-(NSString*) findUnixProgram:(NSString*)programName tryPrefixes:(NSArray*)prefixes
                 environment:(NSDictionary*)environment;

//returns the default preamble. If color.sty is not available, it may add % in front of \usepackage{color}
-(NSAttributedString*) preamble;

//returns some configuration info
-(BOOL) isPdfLatexAvailable;
-(BOOL) isGsAvailable;
-(BOOL) isColorStyAvailable;

//modifies the \usepackage{color} line of the preamble in order to use the given color
-(NSString*) insertColorInPreamble:(NSString*)thePreamble color:(NSColor*)theColor;

//methods for the application service
-(void) serviceLatexisationDisplay:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationInline:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;

//LinkBackServerDelegateProtocol
-(void) linkBackDidClose:(LinkBack*)link;
-(void) linkBackClientDidRequestEdit:(LinkBack*)link;

@end
