// AppController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.

//The AppController is a singleton, a unique instance that acts as a bridge between the menu and the documents.
//It is also responsible for shared operations (like utilities : finding a program)
//It is also a bridge for the application service : it creates a dummy, invisible document that will perform
//the latexisation
//It is also the LinkBack server

#import <Cocoa/Cocoa.h>

#if !defined(CH_APP_EXTENSION) && !defined(CH_APP_XPC_SERVICE)
#import <LinkBack/LinkBack.h>
#endif

#import "LaTeXiTSharedTypes.h"

@class AdditionalFilesWindowController;
@class CompositionConfigurationsWindowController;
@class DragFilterWindowController;
@class EncapsulationsWindowController;
@class HistoryItem;
@class HistoryWindowController;
@class MarginsWindowController;
@class LatexitEquation;
@class LaTeXPalettesWindowController;
@class LibraryWindowController;
@class MyDocument;
@class PreferencesWindowController;
@class PropertyStorage;
@class SUUpdater;

@interface AppController : NSObject <LinkBackServerDelegate> {
  IBOutlet NSMenuItem*    editCopyImageAsMenuItem;
  IBOutlet NSWindow*      readmeWindow;
  IBOutlet NSTextView*    readmeTextView;
  IBOutlet NSPanel*       donationPanel;
  IBOutlet NSTextView*    updatesInformationTextView;
  IBOutlet NSWindow*      whiteColorWarningWindow;
  IBOutlet NSButton*      whiteColorWarningWindowCheckBox;
  IBOutlet SUUpdater*     sparkleUpdater;

  NSBox*                  openFileTypeView;
  NSOpenPanel*            openFileTypeOpenPanel;
  NSPopUpButton*          openFileTypePopUpButton;
  PropertyStorage*        openFileOptions;

  //some info on current configuration
  BOOL isPdfLaTeXAvailable;
  BOOL isXeLaTeXAvailable;
  BOOL isLuaLaTeXAvailable;
  BOOL isLaTeXAvailable;
  BOOL isDviPdfAvailable;
  BOOL isGsAvailable;
  BOOL isPsToPdfAvailable;
  BOOL isColorStyAvailable;
  BOOL isPdfToSvgAvailable;
  BOOL isPerlWithLibXMLAvailable;

  AdditionalFilesWindowController*           additionalFilesWindowController;
  CompositionConfigurationsWindowController* compositionConfigurationWindowController;
  DragFilterWindowController*                dragFilterWindowController;
  EncapsulationsWindowController*            encapsulationsWindowController;
  HistoryWindowController*                   historyWindowController;
  LaTeXPalettesWindowController*             latexPalettesWindowController;
  LibraryWindowController*                   libraryWindowController;
  MarginsWindowController*                   marginsWindowController;
  PreferencesWindowController*               preferencesWindowController;
    
  NSInteger checkLevel;
  BOOL updateGUIFlag;
  BOOL shouldOpenInstallLaTeXHelp;
}

+(AppController*)           appController; //getting the unique instance of appController
+(NSDocument*)              currentDocument;
-(NSDocument*)              currentDocument;
-(NSWindow*)                whiteColorWarningWindow;
-(AdditionalFilesWindowController*)           additionalFilesWindowController;
-(CompositionConfigurationsWindowController*) compositionConfigurationWindowController;
-(DragFilterWindowController*)                dragFilterWindowController;
-(EncapsulationsWindowController*)            encapsulationsWindowController;
-(HistoryWindowController*)                   historyWindowController;
-(LaTeXPalettesWindowController*)             latexPalettesWindowController;
-(LibraryWindowController*)                   libraryWindowController;
-(MarginsWindowController*)                   marginsWindowController;
-(PreferencesWindowController*)               preferencesWindowController;

-(HistoryItem*) addEquationToHistory:(LatexitEquation*)latexitEquation;
-(HistoryItem*) addHistoryItemToHistory:(HistoryItem*)latexitEquation;

//the menu actions
-(IBAction) displaySponsors:(id)sender;
-(IBAction) makeDonation:(id)sender;//display info panel
-(IBAction) openWebSite:(id)sender;//ask for LaTeXiT's web site
-(IBAction) checkUpdates:(id)sender;//check for updates on LaTeXiT's web site

-(IBAction) newFromClipboard:(id)sender;
-(IBAction) closeDocumentLinkBackLink:(id)sender;
-(IBAction) toggleDocumentLinkBackLink:(id)sender;
-(IBAction) copyAs:(id)sender;

-(IBAction) openFile:(id)sender;
-(IBAction) changeOpenFileType:(id)sender;
-(IBAction) exportImage:(id)sender;
-(IBAction) reexportImage:(id)sender;
-(IBAction) changeLatexMode:(id)sender;
-(IBAction) makeLatex:(id)sender;
-(IBAction) makeLatexAndExport:(id)sender;
-(IBAction) displayBaseline:(id)sender;
-(IBAction) displayLog:(id)sender;

-(IBAction) closeBackSync:(id)sender;
-(IBAction) saveAs:(id)sender;
-(IBAction) save:(id)sender;

-(IBAction) fontSizeChange:(id)sender;

-(IBAction) formatChangeAlignment:(id)sender;
-(IBAction) formatComment:(id)sender;
-(IBAction) formatUncomment:(id)sender;

-(IBAction) historyRemoveHistoryEntries:(id)sender;
-(IBAction) historyClearHistory:(id)sender;
-(IBAction) historyChangeLock:(id)sender;
-(IBAction) historyOpen:(id)sender;
-(IBAction) historySaveAs:(id)sender;
-(IBAction) historyRelatexizeItems:(id)sender;
-(IBAction) historyCompact:(id)sender;
-(IBAction) showOrHideHistory:(id)sender;

-(IBAction) libraryOpenEquation:(id)sender;
-(IBAction) libraryOpenLinkedEquation:(id)sender;
-(IBAction) libraryImportCurrent:(id)sender; //creates a library item with the current document state
-(IBAction) libraryNewFolder:(id)sender;
-(IBAction) libraryRemoveSelectedItems:(id)sender;
-(IBAction) libraryRenameItem:(id)sender;
-(IBAction) libraryRefreshItems:(id)sender;
-(IBAction) libraryRelatexizeItems:(id)sender;
-(IBAction) libraryToggleCommentsPane:(id)sender;
-(IBAction) libraryOpen:(id)sender;
-(IBAction) librarySaveAs:(id)sender;
-(IBAction) libraryCompact:(id)sender;
-(IBAction) showOrHideLibrary:(id)sender;

-(IBAction) showOrHideColorInspector:(id)sender;
-(IBAction) showOrHidePreamble:(id)sender;
-(IBAction) showOrHideAdditionalFiles:(id)sender;
-(IBAction) showOrHideCompositionConfiguration:(id)sender;
-(IBAction) showOrHideEncapsulation:(id)sender;
-(IBAction) showOrHideMargin:(id)sender;
-(IBAction) showOrHideLatexPalettes:(id)sender;
-(IBAction) latexPalettesDoubleClick:(id)sender;
-(IBAction) showPreferencesPane:(id)sender;
-(void)     showPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier options:(id)options;//showPreferencesPane + select one pane
-(IBAction) showHelp:(id)sender;
-(void) showHelp:(id)sender section:(NSString*)section;
-(IBAction) reduceOrEnlargeTextArea:(id)sender;
-(IBAction) switchMiniWindow:(id)sender;

-(IBAction) returnFromWhiteColorWarningWindow:(id)sender;

//utility : finds a program in the unix environment. You can give an environment, and
//some "prefixes", that is to say an array of PATH in which the program could be
-(NSString*) findUnixProgram:(NSString*)programName tryPrefixes:(NSArray*)prefixes environment:(NSDictionary*)environment useLoginShell:(BOOL)useLoginShell;

//returns the default preamble. If color.sty is not available, it may add % in front of \usepackage{color}
-(NSAttributedString*) preambleLatexisationAttributedString;
-(NSAttributedString*) preambleServiceAttributedString;

//returns some configuration info
-(BOOL) isPdfLaTeXAvailable;
-(BOOL) isXeLaTeXAvailable;
-(BOOL) isLuaLaTeXAvailable;
-(BOOL) isLaTeXAvailable;
-(BOOL) isDviPdfAvailable;
-(BOOL) isGsAvailable;
-(BOOL) isPsToPdfAvailable;
-(BOOL) isColorStyAvailable;
-(BOOL) isPdfToSvgAvailable;
-(BOOL) isPerlWithLibXMLAvailable;

//if the marginWindowController is not loaded, just use the user defaults values
-(CGFloat) marginsCurrentTopMargin;
-(CGFloat) marginsCurrentBottomMargin;
-(CGFloat) marginsCurrentLeftMargin;
-(CGFloat) marginsCurrentRightMargin;

//if the additionalFilesWindowController is not loaded, just use the user defaults values
-(NSArray*) additionalFilesPaths;

//returns data representing data derived from pdfData, but in the format specified (pdf, eps, tiff, png...)
-(NSString*) nameOfType:(export_format_t)format;

//methods for the application service
-(void) serviceLatexisationAlign:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationAlignAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationEqnarray:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationEqnarrayAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationDisplay:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationDisplayAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationInline:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationInlineAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceLatexisationTextAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceMultiLatexisationAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) serviceDeLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;

//LinkBackServerDelegateProtocol
-(void) closeLinkBackLink:(LinkBack*)link;
-(void) linkBackDidClose:(LinkBack*)link;
-(void) linkBackClientDidRequestEdit:(LinkBack*)link;

//LatexPalette installation
-(BOOL) installLatexPalette:(NSURL*)palettePath;

//Sparkle
-(SUUpdater*) sparkleUpdater;

//NSApplicationDelegate
-(BOOL) application:(NSApplication*)theApplication openFile:(NSString*)filename;

//private
-(void) _findPathWithConfiguration:(id)configuration;
-(void) _checkPathWithConfiguration:(id)configuration;
@end
