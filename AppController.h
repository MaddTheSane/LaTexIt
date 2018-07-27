// AppController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//The AppController is a singleton, a unique instance that acts as a bridge between the menu and the documents.
//It is also responsible for shared operations (like utilities : finding a program)
//It is also a bridge for the application service : it creates a dummy, invisible document that will perform
//the latexisation
//It is also the LinkBack server

#import "PreferencesController.h"

#import <Cocoa/Cocoa.h>

#ifdef PANTHER
#import <LinkBack-panther/LinkBack.h>
#else
#import <LinkBack/LinkBack.h>
#endif

#import "LaTeXiTSharedTypes.h"

typedef enum {CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE,
              CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS,
              CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS,
              CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK} change_service_shortcuts_fallback_t;

@class AdditionalFilesController;
@class CompositionConfigurationController;
@class EncapsulationController;
@class HistoryController;
@class MarginController;
@class LatexPalettesController;
@class LibraryController;
@class MyDocument;
@class PreferencesController;
@class Semaphore;
@class SUUpdater;

@interface AppController : NSObject <LinkBackServerDelegate> {  
  IBOutlet NSWindow*      readmeWindow;
  IBOutlet NSTextView*    readmeTextView;
  IBOutlet NSPanel*       donationPanel;
  IBOutlet NSPanel*       updatesPanel;
  IBOutlet NSTextView*    updatesInformationTextView;
  IBOutlet NSWindow*      whiteColorWarningWindow;
  IBOutlet SUUpdater*     sparkleUpdater;
  IBOutlet NSView*        openFileTypeView;
  IBOutlet NSPopUpButton* openFileTypePopUp;
  NSOpenPanel*            openFileTypeOpenPanel;
  
  //some info on current configuration
  Semaphore* configurationSemaphore;
  BOOL isPdfLatexAvailable;
  BOOL isGsAvailable;
  BOOL isPs2PdfAvailable;
  BOOL isDvipdfAvailable;
  BOOL isXeLatexAvailable;
  BOOL isLatexAvailable;
  BOOL isColorStyAvailable;

  AdditionalFilesController* additionalFilesController;
  CompositionConfigurationController* compositionConfigurationController;
  EncapsulationController* encapsulationController;
  HistoryController*       historyController;
  LatexPalettesController* latexPalettesController;
  LibraryController*       libraryController;
  MarginController*        marginController;
}

+(AppController*)           appController; //getting the unique instance of appController
+(NSDocument*)              currentDocument;
+(NSString*)                latexitTemporaryPath;
-(NSDocument*)              currentDocument;
-(NSWindow*)                whiteColorWarningWindow;
-(AdditionalFilesController*) additionalFilesController;
-(CompositionConfigurationController*) compositionConfigurationController;
-(EncapsulationController*) encapsulationController;
-(HistoryController*)       historyController;
-(LatexPalettesController*) latexPalettesController;
-(LibraryController*)       libraryController;
-(MarginController*)        marginController;

+(NSArray*) unixBins; //usual unix PATH
+(NSDictionary*) fullEnvironmentDict; //environment useful to call programs on the command line
+(NSDictionary*) extraEnvironmentDict; //environment useful to call programs on the command line

//the menu actions
-(IBAction) makeDonation:(id)sender;//display info panel
-(IBAction) openWebSite:(id)sender;//ask for LaTeXiT's web site
-(IBAction) checkUpdates:(id)sender;//check for updates on LaTeXiT's web site

-(IBAction) newFromClipboard:(id)sender;
-(IBAction) copyAs:(id)sender;

-(IBAction) openFile:(id)sender;
-(IBAction) changeOpenFileType:(id)sender;
-(IBAction) exportImage:(id)sender;
-(IBAction) reexportImage:(id)sender;
-(IBAction) makeLatex:(id)sender;
-(IBAction) makeLatexAndExport:(id)sender;
-(IBAction) displayLog:(id)sender;

-(IBAction) historyRemoveHistoryEntries:(id)sender;
-(IBAction) historyClearHistory:(id)sender;
-(IBAction) showOrHideHistory:(id)sender;

-(IBAction) libraryImportCurrent:(id)sender; //creates a library item with the current document state
-(IBAction) libraryNewFolder:(id)sender;     //creates a folder
-(IBAction) libraryRemoveSelectedItems:(id)sender;    //removes some items
-(IBAction) libraryRenameItem:(id)sender;   //rename an item
-(IBAction) libraryRefreshItems:(id)sender;   //refresh an item
-(IBAction) libraryOpen:(id)sender;
-(IBAction) librarySaveAs:(id)sender;
-(IBAction) showOrHideLibrary:(id)sender;

-(IBAction) showOrHideColorInspector:(id)sender;
-(IBAction) showOrHidePreamble:(id)sender;
-(IBAction) showOrHideAdditionalFiles:(id)sender;
-(IBAction) showOrHideCompositionConfiguration:(id)sender;
-(IBAction) showOrHideEncapsulation:(id)sender;
-(IBAction) showOrHideMargin:(id)sender;
-(IBAction) showOrHideLatexPalettes:(id)sender;
-(IBAction) latexPalettesClick:(id)sender;
-(IBAction) showPreferencesPane:(id)sender;
-(void)     showPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier;//showPreferencesPane + select one pane
-(IBAction) showHelp:(id)sender;
-(void) showHelp:(id)sender section:(NSString*)section;
-(IBAction) reduceOrEnlargeTextArea:(id)sender;

-(IBAction) returnFromWhiteColorWarningWindow:(id)sender;

//updates the documents with a loading message
-(void) startMessageProgress:(NSString*)message;
-(void) stopMessageProgress;

//utility : finds a program in the unix environment. You can give an environment, and
//some "prefixes", that is to say an array of PATH in which the program could be
-(NSString*) findUnixProgram:(NSString*)programName tryPrefixes:(NSArray*)prefixes
                 environment:(NSDictionary*)environment;

//returns the default preamble. If color.sty is not available, it may add % in front of \usepackage{color}
-(NSAttributedString*) preambleForLatexisation;
-(NSAttributedString*) preambleForService;

//returns some configuration info
-(BOOL) isPdfLatexAvailable;
-(BOOL) isGsAvailable;
-(BOOL) isDvipdfAvailable;
-(BOOL) isPs2PdfAvailable;
-(BOOL) isXeLatexAvailable;
-(BOOL) isLatexAvailable;
-(BOOL) isColorStyAvailable;

//if the marginController is not loaded, just use the user defaults values
-(float) marginControllerTopMargin;
-(float) marginControllerBottomMargin;
-(float) marginControllerLeftMargin;
-(float) marginControllerRightMargin;

//returns data representing data derived from pdfData, but in the format specified (pdf, eps, tiff, png...)
-(NSString*) nameOfType:(export_format_t)format;
-(NSData*) dataForType:(export_format_t)format pdfData:(NSData*)pdfData jpegColor:(NSColor*)color jpegQuality:(float)quality scaleAsPercent:(float)scaleAsPercent;

//methods for the application service
-(void) serviceLatexisationEqnarray:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationDisplay:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationInline:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceDeLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(BOOL) changeServiceShortcutsWithDiscrepancyFallback:(change_service_shortcuts_fallback_t)discrepancyFallback
                               authenticationFallback:(change_service_shortcuts_fallback_t)authenticationFallback;

//LinkBackServerDelegateProtocol
-(void) linkBackDidClose:(LinkBack*)link;
-(void) linkBackClientDidRequestEdit:(LinkBack*)link;

//LatexPalette installation
-(BOOL) installLatexPalette:(NSString*)palettePath;

//Sparkle
-(SUUpdater*) sparkleUpdater;

@end
