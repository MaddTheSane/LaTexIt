//  AppController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.

//The AppController is a singleton, a unique instance that acts as a bridge between the menu and the documents.
//It is also responsible for shared operations (like utilities : finding a program)
//It is also a bridge for the application service : it creates a dummy, invisible document that will perform
//the latexisation
//It is also the LinkBack server

#import "AppController.h"

#import "AdditionalFilesWindowController.h"
#import "CGPDFExtras.h"
#import "CompositionConfigurationsController.h"
#import "CompositionConfigurationsWindowController.h"
#import "DragFilterWindowController.h"
#import "EncapsulationsWindowController.h"
#import "HistoryController.h"
#import "HistoryWindowController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "HistoryView.h"
#import "IsEqualToTransformer.h"
#import "LatexitEquation.h"
#import "LaTeXPalettesWindowController.h"
#import "LaTeXProcessor.h"
#import "LibraryController.h"
#import "LibraryEquation.h"
#import "LibraryView.h"
#import "LibraryWindowController.h"
#import "LibraryManager.h"
#import "LineCountTextView.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSArrayExtended.h"
#import "NSAttributedStringExtended.h"
#import "NSColorExtended.h"
#import "NSDictionaryCompositionConfiguration.h"
#import "NSDictionaryExtended.h"
#import "NSFileManagerExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSMenuExtended.h"
#import "NSObjectExtended.h"
#import "NSOutlineViewExtended.h"
#import "NSSavePanelExtended.h"
#import "NSStringExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "NSWorkspaceExtended.h"
#import "MarginsWindowController.h"
#import "PaletteItem.h"
#import "PluginsManager.h"
#import "PreferencesController.h"
#import "PreferencesControllerMigration.h"
#import "PreferencesWindowController.h"
#import "PropertyStorage.h"
#import "Semaphore.h"
#import "ServiceRegularExpressionFiltersController.h"
#import "SystemTask.h"
#import "Utils.h"

#include <sys/types.h>
#include <sys/wait.h>

#import <Sparkle/Sparkle.h>

@interface MyTextAttachementCell : NSTextAttachmentCell
@end
@implementation MyTextAttachementCell
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)aView
{
  [[NSColor redColor] set];
  NSRectFill(cellFrame);
}
- (NSSize)cellSize
{
  return NSMakeSize(50, 10);
}
@end

@interface AppController (PrivateAPI)

-(void) beginCheckUpdates;
-(void) endCheckUpdates;
-(BOOL) isCheckUpdating;

-(void) updateGUIfromSystemAvailabilities;

//specialized quick version of _findUnixProgram... that does not take environment in account.
//It only looks for the existence of the file in the given paths, but does not look more.
-(NSString*) _findUnixProgram:(NSString*)programName inPrefixes:(NSArray*)prefixes;

-(void) _setEnvironment:(NSDictionary*)environment; //utility that calls setenv() with the current content of environmentPath

-(void) _checkPathWithConfiguration:(id)configuration;
-(void) _checkColorStyWithConfiguration:(id)configuration;
-(void) _findPathWithConfiguration:(id)configuration;

-(NSAttributedString*) adaptPreambleToCurrentConfiguration:(NSAttributedString*)preamble;

//private method factorizing the work of the different application service calls
-(void) _serviceLatexisation:(NSPasteboard*)pboard userData:(NSString*)userData mode:(latex_mode_t)mode putIntoClipBoard:(BOOL)putIntoClipBoard error:(NSString**)error;
-(void) _serviceMultiLatexisation:(NSPasteboard*)pboard userData:(NSString*)userData putIntoClipBoard:(BOOL)putIntoClipBoard error:(NSString**)error;
-(void) _serviceDeLatexisation:(NSPasteboard*)pboard userData:(NSString*)userData error:(NSString**)error;

-(MyDocument*) documentForLink:(LinkBack*)link;
@end

@implementation AppController

//the unique instance of the appController
static AppController* appControllerInstance = nil;

static NSMutableDictionary* cachePaths = nil;

+(void) initialize
{
  if (!cachePaths)
    cachePaths = [[NSMutableDictionary alloc] init];
}
//end initialize

+(AppController*) appController //access the unique instance of appController
{
  @synchronized(self)
  {
    //creates the unique instance of AppController
    if (!appControllerInstance)
      appControllerInstance = [[self  alloc] init];
  }
  return appControllerInstance;
}
//end appController

+(id) allocWithZone:(NSZone *)zone
{
  @synchronized(self)
  {
    if (!appControllerInstance)
       return [super allocWithZone:zone];
  }
  return appControllerInstance;
}
//end allocWithZone

-(id) copyWithZone:(NSZone *)zone
{
  return self;
}
//end copyWithZone:

-(id) retain
{
  return self;
}
//end retain

-(NSUInteger) retainCount
{
  return UINT_MAX;  //denotes an object that cannot be released
}
//end retainCount

-(oneway void) release
{
}
//end release

-(id) autorelease
{
  return self;
}
//end autorelease

-(id) init
{
  if (self && (self != appControllerInstance))
  {
    if ((!(self = [super init])))
      return nil;
    appControllerInstance = self;
    [self _setEnvironment:[[LaTeXProcessor sharedLaTeXProcessor] extraEnvironment]];//performs a setenv()

    [self beginCheckUpdates];
    Semaphore* configurationSemaphore = [[Semaphore alloc] initWithValue:7];
    NSDictionary* configuration = nil;
    configuration = [NSDictionary dictionaryWithObjectsAndKeys:
      @(NO), @"checkOnlyIfNecessary",
      @(YES), @"allowFindOnFailure",
      configurationSemaphore, @"semaphore",
      nil];
    [PreferencesController sharedController];//create out of thread
    /*disabled for now*/
    /*
    [PluginsManager sharedManager];//create out of thread
    */
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                                                 @[@"pdflatex"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isPdfLaTeXAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationXeLatexPathKey, @"path",
                                                                 @[@"xelatex"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isXeLaTeXAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLuaLatexPathKey, @"path",
                                                                 @[@"lualatex"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isLuaLaTeXAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                                                 @[@"latex"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isLaTeXAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                                                 @[@"dvipdf"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isDviPdfAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                                                 @[@"gs-noX11", @"gs"], @"executableNames",
                                                                 @"ghostscript", @"executableDisplayName",
                                                                 [NSValue valueWithPointer:&self->isGsAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                                                 @[@"ps2pdf"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isPsToPdfAvailable], @"monitor", nil]];
    /*[NSApplication detachDrawingThread:@selector(_checkColorStyWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:@"color.sty", @"path",
                                                                 [NSValue valueWithPointer:&self->isColorStyAvailable], @"monitor", nil]];*/
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:DragExportSvgPdfToSvgPathKey, @"path",
                                                                 @[@"pdf2svg"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isPdfToSvgAvailable], @"monitor", nil]];

    //check perlWithLibXMLAvailable
    {
      SystemTask* perlTask = [[SystemTask alloc] initWithWorkingDirectory:[[NSWorkspace sharedWorkspace] temporaryDirectory]];
      @try {
        [perlTask setArguments:@[@"-e", @"\"use XML::LibXML;\""]];
        [perlTask setEnvironment:[[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment]];
        [perlTask setLaunchPath:@"perl"];
        [perlTask setUsingLoginShell:YES];
        [perlTask launch];
        [perlTask waitUntilExit];
        int terminationStatus = [perlTask terminationStatus];
        self->isPerlWithLibXMLAvailable = (terminationStatus == 0);
      }
      @catch(NSException* e) {
      }
      @finally {
        [perlTask release];
      }
      
    }
    
    [configurationSemaphore Z];
    [configurationSemaphore release];
    configurationSemaphore = nil;

    configuration = [NSDictionary dictionaryWithObjectsAndKeys:
      @(YES), @"checkOnlyIfNecessary",
      @(YES), @"allowUIAlertOnFailure",
      @(YES), @"allowUIFindOnFailure",
      nil];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                                                 @[@"pdflatex"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isPdfLaTeXAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationXeLatexPathKey, @"path",
                                                                 @[@"xelatex"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isXeLaTeXAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLuaLatexPathKey, @"path",
                                                                 @[@"lualatex"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isLuaLaTeXAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                                                 @[@"latex"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isLaTeXAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                                                 @[@"dvipdf"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isDviPdfAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                                                 @[@"gs-noX11", @"gs"], @"executableNames",
                                                                 @"ghostscript", @"executableDisplayName",
                                                                 [NSValue valueWithPointer:&self->isGsAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                                                 @[@"ps2pdf"], @"executableNames",
                                                                 [NSValue valueWithPointer:&self->isPsToPdfAvailable], @"monitor", nil]];
    [self _checkColorStyWithConfiguration:configuration];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:DragExportSvgPdfToSvgPathKey, @"path",
                                                                 @[@"pdf2svg"], @"executableNames",
                                                                 @(NO), @"allowUIAlertOnFailure",
                                                                 @(NO), @"allowUIFindOnFailure",
                                                                 [NSValue valueWithPointer:&self->isPdfToSvgAvailable], @"monitor", nil]];

    //export to EPS needs ghostscript to be available
    PreferencesController* preferencesController = [PreferencesController sharedController];
    export_format_t exportFormat = [preferencesController exportFormatPersistent];
    if ((exportFormat == EXPORT_FORMAT_EPS) && !self->isGsAvailable)
      [preferencesController setExportFormatPersistent:EXPORT_FORMAT_PDF];
    if ((exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS) && (!self->isGsAvailable || !self->isPsToPdfAvailable))
      [preferencesController setExportFormatPersistent:EXPORT_FORMAT_PDF];
    if ((exportFormat == EXPORT_FORMAT_SVG) && !self->isPdfToSvgAvailable)
      [preferencesController setExportFormatPersistent:EXPORT_FORMAT_PDF];
    if ((exportFormat == EXPORT_FORMAT_MATHML) && !self->isPerlWithLibXMLAvailable)
      [preferencesController setExportFormatPersistent:EXPORT_FORMAT_PDF];
    [self endCheckUpdates];

    CompositionConfigurationsController* compositionConfigurationsController = [[PreferencesController sharedController] compositionConfigurationsController];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPdfLatexPathKey] options:0 context:nil];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationXeLatexPathKey] options:0 context:nil];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLuaLatexPathKey] options:0 context:nil];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationLatexPathKey] options:0 context:nil];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationDviPdfPathKey] options:0 context:nil];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationGsPathKey] options:0 context:nil];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPsToPdfPathKey] options:0 context:nil];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey] options:0 context:nil];

    NSUserDefaultsController* userDefaultsController = [NSUserDefaultsController sharedUserDefaultsController];
    [userDefaultsController addObserver:self
      forKeyPath:[userDefaultsController adaptedKeyPath:DragExportSvgPdfToSvgPathKey] options:0 context:nil];

    //declares the service. The service will be called on a dummy document (myDocumentServiceProvider), which is lazily created
    //when first used
    [NSApp setServicesProvider:self];
    NSUpdateDynamicServices();
  }//end if (self && (self != appControllerInstance))
  return self;
}
//end init

-(void) dealloc
{
  [self->additionalFilesWindowController release];
  [self->compositionConfigurationWindowController release];
  [self->encapsulationsWindowController release];
  [self->marginsWindowController release];
  [self->latexPalettesWindowController release];
  [self->libraryWindowController release];
  [self->historyWindowController release];
  [self->preferencesWindowController release];
  [self->openFileOptions release];
  [self->openFileTypeView release];
  [self->openFileTypePopUpButton release];
  [super dealloc];
}
//end dealloc

-(void) awakeFromNib
{
  //migrate to sparkle
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if ([userDefaults objectForKey:Old_CheckForNewVersionsKey])
  {
    [[self sparkleUpdater] setAutomaticallyChecksForUpdates:[userDefaults boolForKey:Old_CheckForNewVersionsKey]];
    [userDefaults removeObjectForKey:Old_CheckForNewVersionsKey];
  }
  //resolve some bindings
  [self->whiteColorWarningWindowCheckBox bind:NSValueBinding
    toObject:[NSUserDefaultsController sharedUserDefaultsController]
    withKeyPath:[NSUserDefaultsController adaptedKeyPath:ShowWhiteColorWarningKey]
        options:[NSDictionary dictionaryWithObjectsAndKeys:
                  NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption, nil]];
                  
  NSMenu* editCopyImageAsMenu = [self->editCopyImageAsMenuItem submenu];
  [editCopyImageAsMenu addItemWithTitle:NSLocalizedString(@"Default Format", @"") target:self action:@selector(copyAs:)
                         keyEquivalent:@"c" keyEquivalentModifierMask:NSCommandKeyMask|NSAlternateKeyMask tag:-1];
  [editCopyImageAsMenu addItem:[NSMenuItem separatorItem]];
  [editCopyImageAsMenu addItemWithTitle:@"PDF" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(NSInteger)EXPORT_FORMAT_PDF];
  [editCopyImageAsMenu addItemWithTitle:NSLocalizedString(@"PDF with outlined fonts", @"")
                                 target:self action:@selector(copyAs:)
                          keyEquivalent:@"c" keyEquivalentModifierMask:NSCommandKeyMask|NSShiftKeyMask|NSAlternateKeyMask
                                    tag:(NSInteger)EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS];
  [editCopyImageAsMenu addItemWithTitle:@"EPS" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(NSInteger)EXPORT_FORMAT_EPS];
  [editCopyImageAsMenu addItemWithTitle:@"SVG" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(NSInteger)EXPORT_FORMAT_SVG];
  [editCopyImageAsMenu addItemWithTitle:@"TIFF" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(NSInteger)EXPORT_FORMAT_TIFF];
  [editCopyImageAsMenu addItemWithTitle:@"PNG" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(NSInteger)EXPORT_FORMAT_PNG];
  [editCopyImageAsMenu addItemWithTitle:@"JPEG" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(NSInteger)EXPORT_FORMAT_JPEG];
  [editCopyImageAsMenu addItemWithTitle:@"MathML" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(NSInteger)EXPORT_FORMAT_MATHML];
  [editCopyImageAsMenu addItemWithTitle:@"Text" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(NSInteger)EXPORT_FORMAT_TEXT];
  [editCopyImageAsMenu addItemWithTitle:@"Rich text" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(NSInteger)EXPORT_FORMAT_RTFD];
}
//end awakeFromNib

+(NSDocument*) currentDocument
{
  NSDocument* document = [[NSDocumentController sharedDocumentController] currentDocument];
  if (!document)
  {
    NSArray* orderedDocument = [NSApp orderedDocuments];
    if ([orderedDocument count])
      document = [orderedDocument objectAtIndex:0];
  }
  if (!document)
  {
    NSArray* orderedWindows = [NSApp orderedWindows];
    if ([orderedWindows count])
      document = [[[orderedWindows objectAtIndex:0] windowController] document];
  }
  return document;
}
//end currentDocument

-(NSDocument*) currentDocument
{
  return [[self class] currentDocument];
}
//end currentDocument

-(SUUpdater*) sparkleUpdater
{
  return self->sparkleUpdater;
}
//end sparkleUpdater

-(NSWindow*) whiteColorWarningWindow
{
  return self->whiteColorWarningWindow;
}
//end whiteColorWarningWindow

-(HistoryItem*) addEquationToHistory:(LatexitEquation*)latexitEquation
{
  HistoryItem* result = nil;
  if (![[HistoryManager sharedManager] isLocked])
    result = [[[HistoryItem alloc] initWithEquation:latexitEquation insertIntoManagedObjectContext:nil] autorelease];
  if (result)
    result = [self addHistoryItemToHistory:result];
  [[HistoryManager sharedManager] saveHistory];
  return result;
}
//end addEquationToHistory:

-(HistoryItem*) addHistoryItemToHistory:(HistoryItem*)historyItem
{
  if (![[HistoryManager sharedManager] isLocked])
  {
    NSManagedObjectContext* managedObjectContext = [[HistoryManager sharedManager] managedObjectContext];
    [managedObjectContext disableUndoRegistration];
    [managedObjectContext safeInsertObject:historyItem];
    [managedObjectContext enableUndoRegistration];
    [[HistoryManager sharedManager] deleteOldEntries];
  }//end if (![[HistoryManager sharedManager] isLocked])
  return historyItem;
}
//end addHistoryItemToHistory:

#pragma mark observer

-(void) observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context
{
  NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSDictionary dictionaryWithObjectsAndKeys:
      CompositionConfigurationPdfLatexPathKey, @"path",
      [NSValue valueWithPointer:&self->isPdfLaTeXAvailable], @"monitor", nil],
    [@"selection." stringByAppendingString:CompositionConfigurationPdfLatexPathKey],
    [NSDictionary dictionaryWithObjectsAndKeys:
      CompositionConfigurationXeLatexPathKey, @"path",
      [NSValue valueWithPointer:&self->isXeLaTeXAvailable], @"monitor", nil],
    [@"selection." stringByAppendingString:CompositionConfigurationXeLatexPathKey],
    [NSDictionary dictionaryWithObjectsAndKeys:
     CompositionConfigurationLuaLatexPathKey, @"path",
     [NSValue valueWithPointer:&self->isLuaLaTeXAvailable], @"monitor", nil],
    [@"selection." stringByAppendingString:CompositionConfigurationLuaLatexPathKey],
    [NSDictionary dictionaryWithObjectsAndKeys:
      CompositionConfigurationLatexPathKey, @"path",
      [NSValue valueWithPointer:&self->isLaTeXAvailable], @"monitor", nil],
    [@"selection." stringByAppendingString:CompositionConfigurationLatexPathKey],
    [NSDictionary dictionaryWithObjectsAndKeys:
      CompositionConfigurationDviPdfPathKey, @"path",
      [NSValue valueWithPointer:&self->isDviPdfAvailable], @"monitor", nil],
    [@"selection." stringByAppendingString:CompositionConfigurationDviPdfPathKey],
    [NSDictionary dictionaryWithObjectsAndKeys:
      CompositionConfigurationGsPathKey, @"path",
      [NSValue valueWithPointer:&self->isGsAvailable], @"monitor", nil],
    [@"selection." stringByAppendingString:CompositionConfigurationGsPathKey],
    [NSDictionary dictionaryWithObjectsAndKeys:
      CompositionConfigurationPsToPdfPathKey, @"path",
      [NSValue valueWithPointer:&self->isPsToPdfAvailable], @"monitor", nil],
    [@"selection." stringByAppendingString:CompositionConfigurationPsToPdfPathKey],
      [NSDictionary dictionary],
    [@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey],
    [NSDictionary dictionaryWithObjectsAndKeys:
      DragExportSvgPdfToSvgPathKey, @"path",
      [NSValue valueWithPointer:&self->isPdfToSvgAvailable], @"monitor", nil],
      DragExportSvgPdfToSvgPathKey,
    nil];
  NSDictionary* configuration = [NSDictionary dictionaryWithObjectsAndKeys:
    @(YES), @"checkOnlyIfNecessary",
    @(YES), @"updateGUIfromSystemAvailabilities",
    nil];
  if ((object == NSApp) && [keyPath isEqualToString:@"effectiveAppearance"])
    [[NSNotificationCenter defaultCenter] postNotificationName:NSAppearanceDidChangeNotification object:self];
  else if ([[dict allKeys] containsObject:keyPath])
  {
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingDictionary:[dict objectForKey:keyPath]]];
  }//end if ([[dict allKeys] containsObject:keyPath])
}
//end observeValueForKeyPath:ofObject:change:context:

#pragma mark delegate

-(BOOL) applicationShouldOpenUntitledFile:(NSApplication*)sender
{
  BOOL result = NO;
  MyDocument* myDocument = (MyDocument*) [self currentDocument];
  result = !myDocument;
  return result;
}
//end applicationShouldOpenUntitledFile:

-(BOOL) application:(NSApplication *)application openFile:(NSString*)filename
{
  BOOL ok = NO;
  NSURL* fileURL = !filename ? nil : [NSURL fileURLWithPath:filename];
  NSString* type = [[filename pathExtension] lowercaseString];
  if ([type isEqualTo:@"latexpalette"])
  {
    ok = [self installLatexPalette:fileURL];
    if (ok)
      [self->latexPalettesWindowController reloadPalettes];
    ok = YES;
  }//end if ([type isEqualTo:@"latexpalette"])
  else if ([type isEqualTo:@"latexlib"] || [type isEqualTo:@"library"] || [type isEqualTo:@"plist"])
  {
    NSString* title =
      [NSString stringWithFormat:NSLocalizedString(@"Do you want to load the library <%@> ?", @""),
                                 [[filename pathComponents] lastObject]];
    NSAlert* alert = [NSAlert alertWithMessageText:title
                                     defaultButton:NSLocalizedString(@"Add to the library", @"")
                                   alternateButton:NSLocalizedString(@"Cancel", @"")
                                       otherButton:NSLocalizedString(@"Replace the library", @"")
                         informativeTextWithFormat:NSLocalizedString(@"If you choose <Replace the library>, the current library will be lost", @"")];
    NSInteger confirm = [alert runModal];
    if (confirm == NSAlertDefaultReturn)
      ok = [[LibraryManager sharedManager] loadFrom:filename option:LIBRARY_IMPORT_MERGE parent:nil];
    else if (confirm == NSAlertOtherReturn)
      ok = [[LibraryManager sharedManager] loadFrom:filename option:LIBRARY_IMPORT_OVERWRITE parent:nil];
    else
      ok = YES;
  }//end if ([type isEqualTo:@"latexlib", @"library", @"latexhist" or @"plist"])
  else if ([type isEqualTo:@"latexhist"])
  {
    NSString* title =
      [NSString stringWithFormat:NSLocalizedString(@"Do you want to load the history <%@> ?", @""),
                                 [[filename pathComponents] lastObject]];
    NSAlert* alert = [NSAlert alertWithMessageText:title
                                     defaultButton:NSLocalizedString(@"Add to the history", @"")
                                   alternateButton:NSLocalizedString(@"Cancel", @"")
                                       otherButton:NSLocalizedString(@"Replace the history", @"")
                         informativeTextWithFormat:NSLocalizedString(@"If you choose <Replace the history>, the current history will be lost", @"")];
    NSInteger confirm = [alert runModal];
    if (confirm == NSAlertDefaultReturn)
      ok = [[HistoryManager sharedManager] loadFrom:filename option:HISTORY_IMPORT_MERGE];
    else if (confirm == NSAlertOtherReturn)
      ok = [[HistoryManager sharedManager] loadFrom:filename option:HISTORY_IMPORT_OVERWRITE];
    else
      ok = YES;
  }//end if ([type isEqualTo:@"latexlib", @"library", @"latexhist" or @"plist"])
  else//latex document
  {
    NSDocumentController* documentController = [NSDocumentController sharedDocumentController];
    NSString* uti = [[NSFileManager defaultManager] UTIFromURL:fileURL];
    if (UTTypeConformsTo((CFStringRef)uti, CFSTR("public.svg-image")))
    {
      NSError* error = nil;
      NSData* data = [NSData dataWithContentsOfURL:fileURL options:NSUncachedRead error:&error];
      NSString* string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
      NSArray* equations = [string componentsMatchedByRegex:@"<svg(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</svg>"
                          options:RKLCaseless|RKLMultiline|RKLDotAll
                             range:string.range capture:0 error:&error];
      if (error)
        DebugLog(1, @"error : %@", error);
      NSUInteger equationsCount = [equations count];
      if (equationsCount == 1)
      {
        __block BOOL localOk = ok;
        [documentController openDocumentWithContentsOfURL:fileURL display:YES completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable localError) {
              if (error)
                DebugLog(1, @"error : %@", error);
              localOk = (document != nil);
         }];
         ok |= localOk;
      }//end if (equationsCount == 1)
      else if (equationsCount > 1)
      {
        NSEnumerator* enumerator = [equations objectEnumerator];
        NSString* equation = nil;
        while((equation = [enumerator nextObject]))
        {
          error = nil;
          MyDocument* document = (MyDocument*)[documentController openUntitledDocumentAndDisplay:YES error:&error];
          if (error)
            DebugLog(1, @"error : %@", error);
          [document applyData:[equation dataUsingEncoding:NSUTF8StringEncoding] sourceUTI:uti];
          [document setFileURL:fileURL];
          ok |= (document != nil);
        }//end for each equation
      }//end if (equationsCount > 1)
    }//end if (UTTypeConformsTo((CFStringRef)uti, CFSTR("public.svg-image")))
    else if (UTTypeConformsTo((CFStringRef)uti, CFSTR("public.html")))
    {
      NSError* error = nil;
      NSData* data = [NSData dataWithContentsOfURL:fileURL options:NSUncachedRead error:&error];
      NSString* string = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
      NSArray* equations_legacy = [string componentsMatchedByRegex:@"<blockquote(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</blockquote>"
                          options:RKLCaseless|RKLMultiline|RKLDotAll
                             range:string.range capture:0 error:&error];
      if (error)
        DebugLog(1, @"error : %@", error);
      error = nil;
      NSArray* equations_new = [string componentsMatchedByRegex:@"<math(.*?)>(.*?)<!--[[:space:]]*latexit:(.*?)-->(.*?)</math>"
                                                           options:RKLCaseless|RKLMultiline|RKLDotAll
                                                             range:string.range capture:0 error:&error];
      NSMutableArray* equations = [NSMutableArray arrayWithCapacity:([equations_legacy count]+[equations_new count])];
      if (equations_legacy)
        [equations addObjectsFromArray:equations_legacy];
      if (equations_new)
        [equations addObjectsFromArray:equations_new];
      if (error)
        DebugLog(1, @"error : %@", error);
      NSUInteger equationsCount = [equations count];
      if (equationsCount == 1)
      {
        __block BOOL localOk = ok;
        [documentController openDocumentWithContentsOfURL:fileURL display:YES
          completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable localError) {
            if (error)
              DebugLog(1, @"error : %@", error);
            localOk = (document != nil);
         }];
         ok |= localOk;
      }//end if (equationsCount == 1)
      else if (equationsCount > 1)
      {
        NSEnumerator* enumerator = [equations objectEnumerator];
        NSString* equation = nil;
        while((equation = [enumerator nextObject]))
        {
          error = nil;
          MyDocument* document = (MyDocument*)[documentController openUntitledDocumentAndDisplay:YES error:&error];
          if (error)
            DebugLog(1, @"error : %@", error);
          [document applyData:[equation dataUsingEncoding:NSUTF8StringEncoding] sourceUTI:uti];
          [document setFileURL:fileURL];
          ok |= (document != nil);
        }//end for each equation
      }//end if (equationsCount > 1)
    }//end if (UTTypeConformsTo((CFStringRef)uti, CFSTR("public.html")))
    else
    {
      NSError* error = nil;
      __block BOOL localOk = ok;
      [documentController openDocumentWithContentsOfURL:fileURL display:YES
        completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable localError) {
          if (error)
            DebugLog(1, @"error : %@", error);
          localOk = (document != nil);
       }];
       ok |= localOk;
    }
  }//end latex document
  return ok;
}
//end application:openFile:

//when the app is launched, the first document appears, then a dialog box can indicate if pdflatex and gs
//have been found or not. Then, the user has the ability to manually find them
//as delegate, no need to register for a notification
-(void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSString* resourcesPath = [[NSBundle mainBundle] resourcePath];
  NSString* applicationsPath = [[[resourcesPath stringByDeletingLastPathComponent]
    stringByAppendingPathComponent:@"Library"]
    stringByAppendingPathComponent:@"Applications"];
  NSString* latexitHelperFilePath = [applicationsPath stringByAppendingPathComponent:@"LaTeXiT Helper.app"];
  CFURLRef  latexitHelperURL = !latexitHelperFilePath ? 0  :
    CFURLCreateWithFileSystemPath(0, (CFStringRef)latexitHelperFilePath, kCFURLPOSIXPathStyle, FALSE);
  OSStatus status = !latexitHelperURL ? -1 : LSRegisterURL(latexitHelperURL, true);
  if (status != noErr)
    DebugLog(0, @"LSRegisterURL : %ld", (long int)status);
  if ([NSApp respondsToSelector:NSSelectorFromString(@"effectiveAppearance")])
    [NSApp addObserver:self forKeyPath:@"effectiveAppearance" options:NSKeyValueObservingOptionNew context:0];

  if (latexitHelperFilePath && (status == noErr))
  {
    //[[NSWorkspace sharedWorkspace] launchApplication:latexitHelperFilePath showIcon:NO autolaunch:NO];//because Keynote won't find it otherwise
    //[[NSWorkspace sharedWorkspace] openFile:nil withApplication:latexitHelperFilePath andDeactivate:NO];
    if (!isMacOS10_15OrAbove())
      [[NSWorkspace sharedWorkspace] openFile:nil withApplication:latexitHelperFilePath andDeactivate:NO];
    else//if (isMacOS10_15OrAbove())
    {
      if (@available(macOS 10.15, *))
      {
        NSWorkspaceOpenConfiguration* configuration = [NSWorkspaceOpenConfiguration configuration];
        configuration.activates = NO;
        NSURL* latexitHelperFileURL = [NSURL fileURLWithPath:latexitHelperFilePath];
        [[NSWorkspace sharedWorkspace] openApplicationAtURL:latexitHelperFileURL configuration:configuration completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        }];
      }//end if @available(macOS, 10.15)
    }//end if (isMacOS10_15OrAbove())
  }//end if (latexitHelperFilePath && (status == noErr))

  if (latexitHelperURL)
    CFRelease(latexitHelperURL);
  [LinkBack publishServerWithName:[[NSWorkspace sharedWorkspace] applicationName] delegate:self];

  if (self->isGsAvailable && (self->isPdfLaTeXAvailable || self->isLaTeXAvailable || self->isXeLaTeXAvailable || self->isLuaLaTeXAvailable) && !self->isColorStyAvailable)
    NSRunInformationalAlertPanel(NSLocalizedString(@"color.sty seems to be unavailable", @""),
                                 NSLocalizedString(@"Without the color.sty package, you won't be able to change the font color", @""),
                                 @"OK", nil, nil);

  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSDictionary* compositionConfiguration = [preferencesController compositionConfigurationDocument];
  if (self->isPdfLaTeXAvailable)
    [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:
      [[compositionConfiguration compositionConfigurationProgramPathPdfLaTeX] stringByDeletingLastPathComponent]];
  if (self->isXeLaTeXAvailable)
    [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:
      [[compositionConfiguration compositionConfigurationProgramPathXeLaTeX] stringByDeletingLastPathComponent]];
  if (self->isLuaLaTeXAvailable)
    [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:
     [[compositionConfiguration compositionConfigurationProgramPathLuaLaTeX] stringByDeletingLastPathComponent]];
  if (self->isLaTeXAvailable)
    [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:
      [[compositionConfiguration compositionConfigurationProgramPathLaTeX] stringByDeletingLastPathComponent]];
  if (self->isDviPdfAvailable)
    [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:
      [[compositionConfiguration compositionConfigurationProgramPathDviPdf] stringByDeletingLastPathComponent]];
  if (self->isGsAvailable)
    [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:
      [[compositionConfiguration compositionConfigurationProgramPathGs] stringByDeletingLastPathComponent]];
  if (self->isPsToPdfAvailable)
    [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:
      [[compositionConfiguration compositionConfigurationProgramPathPsToPdf] stringByDeletingLastPathComponent]];

  [self _setEnvironment:[[LaTeXProcessor sharedLaTeXProcessor] extraEnvironment]];

  //From LateXiT 1.13.0, move Library/LaTeXiT to Library/ApplicationSupport/LaTeXiT
  NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask , YES);
  paths = [paths count] ? [paths subarrayWithRange:NSMakeRange(0, 1)] : nil;
  NSArray* oldPaths = [paths arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:[[NSWorkspace sharedWorkspace] applicationName], nil]];
  NSArray* newPaths = [paths arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"Application Support", [[NSWorkspace sharedWorkspace] applicationName], nil]];
  NSString* oldPath = [NSString pathWithComponents:oldPaths];
  NSString* newPath = [NSString pathWithComponents:newPaths];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:newPath] && [fileManager fileExistsAtPath:oldPath])
    [fileManager copyItemAtPath:oldPath toPath:newPath error:0];

  //sets visible controllers
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  if ([userDefaults boolForKey:CompositionConfigurationsControllerVisibleAtStartupKey])
    [[self compositionConfigurationWindowController] showWindow:self];
  if ([userDefaults boolForKey:EncapsulationsControllerVisibleAtStartupKey])
    [[self encapsulationsWindowController] showWindow:self];
  if ([userDefaults boolForKey:HistoryControllerVisibleAtStartupKey])
    [[self historyWindowController] showWindow:self];
  if ([userDefaults boolForKey:LatexPalettesControllerVisibleAtStartupKey])
    [[self latexPalettesWindowController] showWindow:self];
  if ([userDefaults boolForKey:LibraryControllerVisibleAtStartupKey])
    [[self libraryWindowController] showWindow:self];
  if ([userDefaults boolForKey:MarginControllerVisibleAtStartupKey])
    [[self marginsWindowController] showWindow:self];
  if ([userDefaults boolForKey:AdditionalFilesWindowControllerVisibleAtStartupKey])
    [[self additionalFilesWindowController] showWindow:self];
  [[[self currentDocument] windowForSheet] makeKeyAndOrderFront:self];
  
  //initialize system services
  [preferencesController changeServiceShortcutsWithDiscrepancyFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK
                                                authenticationFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK];
                                                
  if (self->shouldOpenInstallLaTeXHelp)
  {
    self->shouldOpenInstallLaTeXHelp = NO;
    [self showHelp:self section:[NSString stringWithFormat:@"\n%@\n", NSLocalizedString(@"Install LaTeX", @"")]];
  }//end if (self->shouldOpenInstallLaTeXHelp)

  if ([self->sparkleUpdater automaticallyChecksForUpdates])
    [self->sparkleUpdater checkForUpdatesInBackground];
}
//end applicationDidFinishLaunching:

-(NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)sender
{
  NSApplicationTerminateReply result = NSTerminateNow;
  NSEnumerator* enumerator = [[NSApp orderedDocuments] objectEnumerator];
  MyDocument* document = nil;
  while((document = [enumerator nextObject]))
    [document setLinkBackLink:nil];
  return result;
}
//end applicationShouldTerminate

-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  if ([NSApp respondsToSelector:NSSelectorFromString(@"effectiveAppearance")])
    [NSApp removeObserver:self forKeyPath:@"effectiveAppearance"];
  [LinkBack retractServerWithName:[[NSWorkspace sharedWorkspace] applicationName]];
  
  [[NSWorkspace sharedWorkspace] closeApplicationWithBundleIdentifier:@"fr.club.ktd.LaTeXiT"];//LaTeXiT Helper
  
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  BOOL visible = NO;

  visible = compositionConfigurationWindowController && [[compositionConfigurationWindowController window] isVisible];
  [userDefaults setBool:visible forKey:CompositionConfigurationsControllerVisibleAtStartupKey];

  visible = [[self->encapsulationsWindowController window] isVisible];
  [userDefaults setBool:visible forKey:EncapsulationsControllerVisibleAtStartupKey];

  visible = [[self->latexPalettesWindowController window] isVisible];
  [userDefaults setBool:visible forKey:LatexPalettesControllerVisibleAtStartupKey];

  visible = [[self->historyWindowController window] isVisible];
  [userDefaults setBool:visible forKey:HistoryControllerVisibleAtStartupKey];

  visible = [[self->libraryWindowController window] isVisible];
  [userDefaults setBool:visible forKey:LibraryControllerVisibleAtStartupKey];

  visible = [[self->marginsWindowController window] isVisible];
  [userDefaults setBool:visible forKey:MarginControllerVisibleAtStartupKey];

  visible = [[self->additionalFilesWindowController window] isVisible];
  [userDefaults setBool:visible forKey:AdditionalFilesWindowControllerVisibleAtStartupKey];
  
  [[NSFileManager defaultManager] removeAllCreatedTemporaryPaths];
}
//end applicationWillTerminate:

#pragma mark menu

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  if ([sender action] == @selector(newFromClipboard:))
  {
    NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
    ok = ([pasteboard availableTypeFromArray:
            [NSArray arrayWithObjects:NSPDFPboardType,  kUTTypePDF,
                                      //@"com.apple.iWork.TSPNativeMetadata",             
                                      NSRTFDPboardType, kUTTypeRTFD,
                                      NSStringPboardType, @"public.utf8-plain-text", nil]] != nil);
    if (![pasteboard availableTypeFromArray:
           [NSArray arrayWithObjects:NSPDFPboardType, kUTTypePDF, 
                                     //@"com.apple.iWork.TSPNativeMetadata",
                                     NSStringPboardType, @"public.utf8-plain-text", nil]])//RTFD
    {
      NSData* rtfdData = [pasteboard dataForType:NSRTFDPboardType];
      if (!rtfdData) rtfdData = [pasteboard dataForType:(NSString*)kUTTypeRTFD];
      NSDictionary* docAttributes = nil;
      NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
      NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
      NSData* data = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
      [attributedString release];
      ok = (data != nil);
    }
  }
  else if ([sender action] == @selector(open:))
  {
    ok = YES;
  }//end if ([sender action] == @selector(open:))
  else if ([sender action] == @selector(closeBackSync:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = [myDocument hasBackSyncFile];
  }//end if ([sender action] == @selector(closeBackSync:))
  else if ([sender action] == @selector(saveAs:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil);
  }//end if ([sender action] == @selector(saveAs:))
  else if ([sender action] == @selector(save:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = ([myDocument fileURL] != nil);
  }//end if ([sender action] == @selector(save:):))
  else if ([sender action] == @selector(copyAs:))
  {
    if ([sender tag] == -1)//default
    {
      export_format_t defaultExportFormat = [[PreferencesController sharedController] exportFormatCurrentSession];
      [sender setTitle:[NSString stringWithFormat:@"%@ (%@)",
        NSLocalizedString(@"Default Format", @""),
        [[AppController appController] nameOfType:defaultExportFormat]]];
    }
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [myDocument hasImage];
    if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      ok &= self->isGsAvailable && self->isPsToPdfAvailable;
    if ([sender tag] == EXPORT_FORMAT_SVG)
      ok &= self->isPdfToSvgAvailable;
    if ([sender tag] == EXPORT_FORMAT_MATHML)
      ok &= self->isPerlWithLibXMLAvailable;
    if ([sender tag] == -1)//default
    {
      export_format_t exportFormat = (export_format_t)[[NSUserDefaults standardUserDefaults] integerForKey:DragExportTypeKey];
      [sender setTitle:[NSString stringWithFormat:@"%@ (%@)",
        NSLocalizedString(@"Default Format", @""),
        [self nameOfType:exportFormat]]];
    }
  }
  else if ([sender action] == @selector(closeDocumentLinkBackLink:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = ([myDocument linkBackLink] != nil);
  }
  else if ([sender action] == @selector(toggleDocumentLinkBackLink:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = ([myDocument linkBackLink] != nil);
    [sender setTitle:(!ok || [myDocument linkBackAllowed]) ?
      NSLocalizedString(@"Suspend Linkback link", @"") :
      NSLocalizedString(@"Resume Linkback link", @"")];
  }
  else if ([sender action] == @selector(exportImage:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [myDocument hasImage];
  }
  else if ([sender action] == @selector(reexportImage:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [myDocument hasImage] && [myDocument canReexport];
  }
  else if ([sender action] == @selector(changeLatexMode:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy];
    latex_mode_t latexMode = [myDocument latexModeRequested];
    if ([sender tag] == 1)
      [sender setState:(myDocument && (latexMode == LATEX_MODE_ALIGN)) ? NSOnState : NSOffState];
    else if ([sender tag] == 2)
      [sender setState:(myDocument && (latexMode == LATEX_MODE_DISPLAY)) ? NSOnState : NSOffState];
    else if ([sender tag] == 3)
      [sender setState:(myDocument && (latexMode == LATEX_MODE_INLINE)) ? NSOnState : NSOffState];
    else if ([sender tag] == 4)
      [sender setState:(myDocument && (latexMode == LATEX_MODE_TEXT)) ? NSOnState : NSOffState];
    else if ([sender tag] == 5)
      [sender setState:(myDocument && (latexMode == LATEX_MODE_AUTO)) ? NSOnState : NSOffState];
  }
  else if ([sender action] == @selector(makeLatex:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    [sender setTitle:((myDocument != nil) && [myDocument isBusy]) ? NSLocalizedString(@"Stop", @"") :
                     NSLocalizedString(@"LaTeX it!", @"")];
    ok = (myDocument != nil) && [self isPdfLaTeXAvailable];
  }
  else if ([sender action] == @selector(makeLatexAndExport:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [self isPdfLaTeXAvailable] && [[myDocument fileURL] path];
  }
  else if ([sender action] == @selector(displayLog:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil);
  }
  else if ([sender action] == @selector(displayBaseline:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    LatexitEquation* equation = [myDocument latexitEquationWithCurrentStateTransient:NO];
    ok = (equation != nil);
  }
  else if ([sender action] == @selector(showOrHidePreamble:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    BOOL isPreambleVisible = (myDocument && [myDocument isPreambleVisible]);
    ok = (myDocument != nil) && ![myDocument isBusy] && !([myDocument documentStyle] == DOCUMENT_STYLE_MINI);
    if (isPreambleVisible)
      [sender setTitle:NSLocalizedString(@"Hide preamble", @"")];
    else
      [sender setTitle:NSLocalizedString(@"Show preamble", @"")];
  }
  else if ([sender action] == @selector(fontSizeChange:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy];
  }
  else if ([sender action] == @selector(formatChangeAlignment:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy];// && ([myDocument latexModeApplied] == LATEX_MODE_TEXT);
    if ([sender tag] == ALIGNMENT_MODE_NONE)
      [sender setKeyEquivalentModifierMask:[sender keyEquivalentModifierMask]|NSAlternateKeyMask];
  }
  else if ([sender action] == @selector(formatComment:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy];// && ([myDocument latexModeApplied] == LATEX_MODE_TEXT);
  }
  else if ([sender action] == @selector(formatUncomment:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy];// && ([myDocument latexModeApplied] == LATEX_MODE_TEXT);
  }
  else if ([sender action] == @selector(showOrHideHistory:))
  {
    BOOL isHistoryVisible = [[self->historyWindowController window] isVisible];
    if (isHistoryVisible)
      [sender setTitle:NSLocalizedString(@"Hide History", @"")];
    else
      [sender setTitle:NSLocalizedString(@"Show History", @"")];
  }
  else if ([sender action] == @selector(historyRemoveHistoryEntries:))
  {
    ok = [[self->historyWindowController window] isVisible] && [self->historyWindowController canRemoveEntries];
  }
  else if ([sender action] == @selector(historyClearHistory:))
  {
    ok = ([[HistoryManager sharedManager] numberOfItems] > 0);
  }
  else if ([sender action] == @selector(historyChangeLock:))
  {
    [sender setTitle:[[HistoryManager sharedManager] isLocked] ?
                    NSLocalizedString(@"Unlock", @"") : NSLocalizedString(@"Lock", @"")];
    ok = YES;
  }
  else if ([sender action] == @selector(historyOpen:))
  {
    ok = [[self->historyWindowController window] isVisible];
  }
  else if ([sender action] == @selector(historySaveAs:))
  {
    ok = [[self->historyWindowController window] isVisible];
  }
  else if ([sender action] == @selector(historyRelatexizeItems:))
  {
    [sender setTitle:NSLocalizedString(@"latexize selection again", @"")];
    ok = [[self->historyWindowController window] isVisible] && ([[[self->historyWindowController historyView] selectedItems] count] != 0);
  }
  else if ([sender action] == @selector(showOrHideLibrary:))
  {
    BOOL isLibraryVisible = [[self->libraryWindowController window] isVisible];
    if (isLibraryVisible)
      [sender setTitle:NSLocalizedString(@"Hide Library", @"")];
    else
      [sender setTitle:NSLocalizedString(@"Show Library", @"")];
  }
  else if ([sender action] == @selector(libraryOpenEquation:))
  {
    ok = [[self->libraryWindowController window] isVisible] &&
         ([[[[self->libraryWindowController libraryView] selectedItems] filteredArrayWithItemsOfClass:[LibraryEquation class] exactClass:NO] count] != 0);
  }
  else if ([sender action] == @selector(libraryOpenLinkedEquation:))
  {
    ok = [[self->libraryWindowController window] isVisible] &&
         ([[[[self->libraryWindowController libraryView] selectedItems] filteredArrayWithItemsOfClass:[LibraryEquation class] exactClass:NO] count] != 0);
  }
  else if ([sender action] == @selector(libraryNewFolder:))
  {
    ok = [[self->libraryWindowController window] isVisible] &&
         ![[[self->libraryWindowController libraryView] libraryController] filterPredicate];
  }
  else if ([sender action] == @selector(libraryImportCurrent:))
  {
    MyDocument* document = (MyDocument*) [self currentDocument];
    ok = [[self->libraryWindowController window] isVisible] && document && [document hasImage] &&
         ![[[self->libraryWindowController libraryView] libraryController] filterPredicate];
  }
  else if ([sender action] == @selector(libraryRenameItem:))
  {
    ok = [[self->libraryWindowController window] isVisible] && [self->libraryWindowController canRenameSelectedItems];
  }
  else if ([sender action] == @selector(libraryRemoveSelectedItems:))
  {
    ok = [[self->libraryWindowController window] isVisible] && [self->libraryWindowController canRemoveSelectedItems];
  }
  else if ([sender action] == @selector(libraryRefreshItems:))
  {
    ok = [[self->libraryWindowController window] isVisible] && [self->libraryWindowController canRefreshItems];
  }
  else if ([sender action] == @selector(libraryRelatexizeItems:))
  {
    [sender setTitle:NSLocalizedString(@"latexize selection again", @"")];
    ok = [[self->libraryWindowController window] isVisible] && ([[[self->libraryWindowController libraryView] selectedItems] count] != 0);
  }
  else if ([sender action] == @selector(libraryToggleCommentsPane:))
  {
    ok = [[self->libraryWindowController window] isVisible];
    [sender setTitle:
       ok && [self->libraryWindowController isCommentsPaneOpen] ?
         NSLocalizedString(@"Hide comments pane", @"") :
         NSLocalizedString(@"Show comments pane", @"")];
  }
  else if ([sender action] == @selector(libraryOpen:))
  {
    ok = [[self->libraryWindowController window] isVisible];
  }
  else if ([sender action] == @selector(librarySaveAs:))
  {
    ok = [[self->libraryWindowController window] isVisible];
  }
  else if ([sender action] == @selector(showOrHideColorInspector:))
    [sender setState:[[NSColorPanel sharedColorPanel] isVisible] ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideAdditionalFiles:))
    [sender setState:[[self->additionalFilesWindowController window] isVisible] ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideCompositionConfiguration:))
    [sender setState:(compositionConfigurationWindowController && [[compositionConfigurationWindowController window] isVisible]) ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideEncapsulation:))
    [sender setState:[[self->encapsulationsWindowController window] isVisible] ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideMargin:))
    [sender setState:[[self->marginsWindowController window] isVisible] ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideLatexPalettes:))
    [sender setState:[[self->latexPalettesWindowController window] isVisible] ? NSOnState : NSOffState];
  else if ([sender action] == @selector(reduceOrEnlargeTextArea:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    BOOL isReducedTextArea = (myDocument && [myDocument isReducedTextArea]);
    ok = (myDocument != nil);
    if (isReducedTextArea)
      [sender setTitle:NSLocalizedString(@"Enlarge the text area", @"")];
    else
      [sender setTitle:NSLocalizedString(@"Reduce the text area", @"")];
  }
  else if ([sender action] == @selector(switchMiniWindow:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    BOOL isMini = myDocument && ([myDocument documentStyle] == DOCUMENT_STYLE_MINI);
    ok = (myDocument != nil);
    if (isMini)
      [sender setTitle:NSLocalizedString(@"Switch to normal window", @"")];
    else
      [sender setTitle:NSLocalizedString(@"Switch to mini-window", @"")];
  }
  return ok;
}
//end validateMenuItem:

-(IBAction) displaySponsors:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://pierre.chachatelier.fr/latexit/latexit-sponsors.php"]];
}
//end makeDonation:

-(IBAction) makeDonation:(id)sender//display info panel
{
  if (![donationPanel isVisible])
    [donationPanel center];
  [donationPanel orderFront:sender];
}
//end makeDonation:

-(IBAction) showPreferencesPane:(id)sender
{
  NSWindow* window = [[self preferencesWindowController] window];
  [window makeKeyAndOrderFront:self];
}
//end showPreferencesPane:

-(void) showPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier options:(id)options//showPreferencesPane + select one pane
{
  [self showPreferencesPane:self];
  [[self preferencesWindowController] selectPreferencesPaneWithItemIdentifier:itemIdentifier options:options];
}
//end showPreferencesPaneWithItemIdentifier:

-(IBAction) newFromClipboard:(id)sender
{
  NSColor* color = nil;
  NSData* data = nil;
  NSString* filename = NSLocalizedString(@"clipboard", @"");
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:(NSString*)NSPDFPboardType]])
  {
    filename = [filename stringByAppendingPathExtension:@"pdf"];
    data = [pasteboard dataForType:NSPDFPboardType];
  }
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:(NSString*)kUTTypePDF]])
  {
    filename = [filename stringByAppendingPathExtension:@"pdf"];
    data = [pasteboard dataForType:(NSString*)kUTTypePDF];
  }
  /*else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:@"com.apple.iWork.TSPNativeMetadata"]])
  {
    filename = nil;
    data = [pasteboard dataForType:@"com.apple.iWork.TSPNativeMetadata"];
  }*/
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSRTFDPboardType]])
  {
    filename = [filename stringByAppendingPathExtension:@"pdf"];
    NSData* rtfdData = [pasteboard dataForType:NSRTFDPboardType];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    data = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    if (!data && [attributedString length])
    {
      NSRange range = NSMakeRange(0, 0);
      color = [attributedString attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:&range];
      filename = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"tex"];
      data = [[attributedString string] dataUsingEncoding:NSUTF8StringEncoding];
    }
    [attributedString release];
  }
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:(NSString*)kUTTypeRTFD]])
  {
    filename = [filename stringByAppendingPathExtension:@"pdf"];
    NSData* rtfdData = [pasteboard dataForType:(NSString*)kUTTypeRTFD];
    NSDictionary* docAttributes = nil;
    NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
    data = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
    if (!data && [attributedString length])
    {
      NSRange range = NSMakeRange(0, 0);
      color = [attributedString attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:&range];
      filename = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"tex"];
      data = [[attributedString string] dataUsingEncoding:NSUTF8StringEncoding];
    }
    [attributedString release];
  }
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
  {
    filename = [filename stringByAppendingPathExtension:@"tex"];
    data = [pasteboard dataForType:NSStringPboardType];
  }
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:@"public.utf8-plain-text"]])
  {
    filename = [filename stringByAppendingPathExtension:@"tex"];
    data = [pasteboard dataForType:@"public.utf8-plain-text"];
  }
  
  NSString* filepath = nil;
  if (filename)
  {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSString* folderPath  = [[NSWorkspace sharedWorkspace] temporaryDirectory];
    NSString* filePrefix  = [filename stringByDeletingPathExtension];
    NSString* extension   = [filename pathExtension];
    NSString* newFileName = filename;
    NSString* newFilePath = [folderPath stringByAppendingPathComponent:newFileName];
    unsigned long i = 1;
    //we try to compute a name that is not already in use
    while (i && [fileManager fileExistsAtPath:newFilePath])
    {
      newFileName = [NSString stringWithFormat:@"%@-%lu.%@", filePrefix, (unsigned long)i++, extension];
      newFilePath = [folderPath stringByAppendingPathComponent:newFileName];
    } 
    filepath = newFilePath;
    [fileManager registerTemporaryPath:filepath];
  }//end if (filename)

  BOOL ok = (data && filepath) ? [data writeToFile:filepath atomically:YES] : NO;
  if (ok)
  {
    __block MyDocument* myDocument = nil;
    NSURL* fileURL = !filepath ? nil : [NSURL fileURLWithPath:filepath];
    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:NO completionHandler:^(NSDocument * _Nullable document, BOOL documentWasAlreadyOpen, NSError * _Nullable error) {
      myDocument = [document dynamicCastToClass:[MyDocument class]];
    }];
    ok = (myDocument != nil);
    if (!ok)
      [myDocument close];
    else
    {
      [myDocument makeWindowControllers];
      [[myDocument windowControllers] makeObjectsPerformSelector:@selector(window)];//force loading nib file
      if (color)
        [myDocument setColor:color];
      [myDocument showWindows];
    }//end if (ok)
  }//end if (ok)
  else if (data && !filepath)
  {
    NSError* error = nil;
    MyDocument* document = [[NSDocumentController sharedDocumentController] makeUntitledDocumentOfType:@"MyDocumentType" error:&error];
    [document makeWindowControllers];
    [[document windowControllers] makeObjectsPerformSelector:@selector(window)];//force loading nib file
    if (color)
      [document setColor:color];
    [[document imageView] paste:self];
    [document showWindows];
  }//end if (data && !filepath)
}
//end newFromClipboard:

-(IBAction) closeDocumentLinkBackLink:(id)sender
{
  MyDocument* myDocument = (MyDocument*) [self currentDocument];
  [myDocument setLinkBackLink:nil];
}
//end closeDocumentLinkBackLink:

-(IBAction) toggleDocumentLinkBackLink:(id)sender
{
  MyDocument* myDocument = (MyDocument*) [self currentDocument];
  [myDocument setLinkBackAllowed:![myDocument linkBackAllowed]];
}
//end toggleDocumentLinkBackLink:

-(IBAction) openFile:(id)sender
{
  if (!self->openFileOptions)
    self->openFileOptions =
      [[PropertyStorage alloc] initWithDictionary:
        [NSDictionary dictionaryWithObjectsAndKeys:
          @(NO), @"synchronizeAvailable",
          @(NO), @"synchronizeEnabled",
          @(NO), @"synchronizePreamble",
          @(NO), @"synchronizeEnvironment",
          @(NO), @"synchronizeBody",
          nil]];
  if (!self->openFileTypeView)
  {
    NSString* NSEnabled2Binding = [NSEnabledBinding stringByAppendingString:@"2"];

    self->openFileTypeView = [[NSBox alloc] initWithFrame:NSZeroRect];
    [self->openFileTypeView setBorderType:NSNoBorder];
    [self->openFileTypeView setTitlePosition:NSNoTitle];

    NSTextField* openFileTypeLabel = [[[NSTextField alloc] initWithFrame:NSZeroRect] autorelease];
    [openFileTypeLabel setEditable:NO];
    [openFileTypeLabel setSelectable:NO];
    [openFileTypeLabel setBordered:NO];
    [openFileTypeLabel setBezeled:NO];
    [openFileTypeLabel setDrawsBackground:NO];
    [openFileTypeLabel setStringValue:[NSString stringWithFormat:@"%@ :", NSLocalizedString(@"File type", @"")]];
    [openFileTypeLabel sizeToFit];
    [self->openFileTypeView addSubview:openFileTypeLabel];

    self->openFileTypePopUpButton = [[NSPopUpButton alloc] initWithFrame:NSZeroRect];
    [self->openFileTypePopUpButton addItemsWithTitles:[NSArray arrayWithObjects:
      NSLocalizedString(@"PDF Equation", @""),
      NSLocalizedString(@"Text file", @""),
      NSLocalizedString(@"LaTeXiT library", @""),
      NSLocalizedString(@"LaTeX Equation Editor library", @""),
      NSLocalizedString(@"LaTeXiT history", @""),
      NSLocalizedString(@"LaTeXiT LaTeX Palette", @""), nil]];
    [self->openFileTypePopUpButton setTarget:self];
    [self->openFileTypePopUpButton setAction:@selector(changeOpenFileType:)];
    [self->openFileTypePopUpButton selectItemAtIndex:0];
    [self->openFileTypePopUpButton sizeToFit];
    [self->openFileTypeView addSubview:self->openFileTypePopUpButton];
    
    NSButton* openFileSynchronizeCheckBox = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
    [openFileSynchronizeCheckBox setButtonType:NSSwitchButton];
    [openFileSynchronizeCheckBox setTitle:NSLocalizedString(@"Continuously synchronize file content", @"")];
    [openFileSynchronizeCheckBox bind:NSHiddenBinding toObject:self->openFileOptions
                          withKeyPath:@"synchronizeAvailable"
                              options:[NSDictionary dictionaryWithObjectsAndKeys:
                                       NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption,
                                       nil]];
    [openFileSynchronizeCheckBox bind:NSEnabledBinding toObject:self->openFileOptions
                          withKeyPath:@"synchronizeAvailable"
                              options:nil];
    [openFileSynchronizeCheckBox bind:NSValueBinding toObject:self->openFileOptions
                          withKeyPath:@"synchronizeEnabled"
                              options:nil];
    [openFileSynchronizeCheckBox sizeToFit];
    [self->openFileTypeView addSubview:openFileSynchronizeCheckBox];

    NSButton* openFileSynchronizePreambleCheckBox = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
    [openFileSynchronizePreambleCheckBox setButtonType:NSSwitchButton];
    [openFileSynchronizePreambleCheckBox setTitle:NSLocalizedString(@"Synchronize preamble", @"")];
    [openFileSynchronizePreambleCheckBox bind:NSHiddenBinding toObject:self->openFileOptions
                                  withKeyPath:@"synchronizeAvailable"
                                      options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption,
                                                nil]];
    [openFileSynchronizePreambleCheckBox bind:NSEnabledBinding toObject:self->openFileOptions
                          withKeyPath:@"synchronizeAvailable"
                              options:nil];
    [openFileSynchronizePreambleCheckBox bind:NSEnabled2Binding toObject:self->openFileOptions
                                  withKeyPath:@"synchronizeEnabled"
                                      options:nil];
    [openFileSynchronizePreambleCheckBox bind:NSValueBinding toObject:self->openFileOptions
                          withKeyPath:@"synchronizePreamble"
                              options:nil];
    [openFileSynchronizePreambleCheckBox sizeToFit];
    [self->openFileTypeView addSubview:openFileSynchronizePreambleCheckBox];
    
    NSButton* openFileSynchronizeEnvironmentCheckBox = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
    [openFileSynchronizeEnvironmentCheckBox setButtonType:NSSwitchButton];
    [openFileSynchronizeEnvironmentCheckBox setTitle:NSLocalizedString(@"Synchronize environment", @"")];
    [openFileSynchronizeEnvironmentCheckBox bind:NSHiddenBinding toObject:self->openFileOptions
                                  withKeyPath:@"synchronizeAvailable"
                                      options:[NSDictionary dictionaryWithObjectsAndKeys:
                                               NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption,
                                               nil]];
    [openFileSynchronizeEnvironmentCheckBox bind:NSEnabledBinding toObject:self->openFileOptions
                                  withKeyPath:@"synchronizeAvailable"
                                      options:nil];
    [openFileSynchronizeEnvironmentCheckBox bind:NSEnabled2Binding toObject:self->openFileOptions
                                  withKeyPath:@"synchronizeEnabled"
                                      options:nil];
    [openFileSynchronizeEnvironmentCheckBox bind:NSValueBinding toObject:self->openFileOptions
                                  withKeyPath:@"synchronizeEnvironment"
                                      options:nil];
    [openFileSynchronizeEnvironmentCheckBox sizeToFit];
    [self->openFileTypeView addSubview:openFileSynchronizeEnvironmentCheckBox];
    
    NSButton* openFileSynchronizeBodyCheckBox = [[[NSButton alloc] initWithFrame:NSZeroRect] autorelease];
    [openFileSynchronizeBodyCheckBox setButtonType:NSSwitchButton];
    [openFileSynchronizeBodyCheckBox setTitle:NSLocalizedString(@"Synchronize body", @"")];
    [openFileSynchronizeBodyCheckBox bind:NSHiddenBinding toObject:self->openFileOptions
                                     withKeyPath:@"synchronizeAvailable"
                                         options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  NSNegateBooleanTransformerName, NSValueTransformerNameBindingOption,
                                                  nil]];
    [openFileSynchronizeBodyCheckBox bind:NSEnabledBinding toObject:self->openFileOptions
                                     withKeyPath:@"synchronizeAvailable"
                                         options:nil];
    [openFileSynchronizeBodyCheckBox bind:NSEnabled2Binding toObject:self->openFileOptions
                                     withKeyPath:@"synchronizeEnabled"
                                         options:nil];
    [openFileSynchronizeBodyCheckBox bind:NSValueBinding toObject:self->openFileOptions
                                     withKeyPath:@"synchronizeBody"
                                         options:nil];
    [openFileSynchronizeBodyCheckBox sizeToFit];
    [self->openFileTypeView addSubview:openFileSynchronizeBodyCheckBox];
    
    [openFileSynchronizeBodyCheckBox setFrameOrigin:NSMakePoint(8+20, 8)];
    [openFileSynchronizeEnvironmentCheckBox setFrameOrigin:NSMakePoint(8+20, CGRectGetMaxY(NSRectToCGRect([openFileSynchronizeBodyCheckBox frame]))+4)];
    [openFileSynchronizePreambleCheckBox setFrameOrigin:NSMakePoint(8+20, CGRectGetMaxY(NSRectToCGRect([openFileSynchronizeEnvironmentCheckBox frame]))+4)];
    [openFileSynchronizeCheckBox setFrameOrigin:NSMakePoint(8, CGRectGetMaxY(NSRectToCGRect([openFileSynchronizePreambleCheckBox frame]))+4)];
    [openFileTypeLabel setFrameOrigin:NSMakePoint(8, CGRectGetMaxY(NSRectToCGRect([openFileSynchronizeCheckBox frame]))+4)];
    [self->openFileTypePopUpButton setFrameOrigin:NSMakePoint(CGRectGetMaxX(NSRectToCGRect([openFileTypeLabel frame]))+8,
                                                              CGRectGetMinY(NSRectToCGRect([openFileTypeLabel frame]))+
                                                              ([openFileTypeLabel frame].size.height-[self->openFileTypePopUpButton frame].size.height)/2)];
    [self->openFileTypeView sizeToFit];

    [self->openFileOptions setObject:@(NO) forKey:@"synchronizeEnabled"];
    [self->openFileOptions setObject:@(YES) forKey:@"synchronizePreamble"];
    [self->openFileOptions setObject:@(YES) forKey:@"synchronizeEnvironment"];
    [self->openFileOptions setObject:@(YES) forKey:@"synchronizeBody"];
  }//end if (!self->openFileTypeView)
  [self->openFileOptions setObject:@(NO) forKey:@"synchronizeEnabled"];
  self->openFileTypeOpenPanel = [NSOpenPanel openPanel];
  [self changeOpenFileType:openFileTypePopUpButton];
  [self->openFileTypeOpenPanel setAllowsMultipleSelection:NO];
  [self->openFileTypeOpenPanel setCanChooseDirectories:NO];
  [self->openFileTypeOpenPanel setCanChooseFiles:YES];
  [self->openFileTypeOpenPanel setCanCreateDirectories:NO];
  [self->openFileTypeOpenPanel setResolvesAliases:YES];
  [self->openFileTypeOpenPanel setAccessoryView:self->openFileTypeView];
  [self->openFileTypeOpenPanel setDelegate:(id)self];//panel:shouldShowFilename:
  NSInteger result = [self->openFileTypeOpenPanel runModal];
  if (result == NSOKButton)
  {
    NSString* filePath = [[[self->openFileTypeOpenPanel URLs] lastObject] path];
    BOOL synchronizeAvailable =
      [[[self->openFileOptions objectForKey:@"synchronizeAvailable"] dynamicCastToClass:[NSNumber class]] boolValue];
    BOOL synchronizeEnabled =
      [[[self->openFileOptions objectForKey:@"synchronizeEnabled"] dynamicCastToClass:[NSNumber class]] boolValue];
    if (synchronizeAvailable && synchronizeEnabled)
    {
      [[NSDocumentController sharedDocumentController] newDocument:nil];
      MyDocument* document = (MyDocument*) [self currentDocument];
      [document openBackSyncFile:filePath options:[self->openFileOptions dictionary]];
    }//end if (synchronizeAvailable && synchronizeEnabled)
    else
      [self application:NSApp openFile:filePath];
  }
  self->openFileTypeOpenPanel = nil;
}
//end openFile:

-(IBAction) changeOpenFileType:(id)sender
{
  NSPopUpButton* openFilePopupButton = [sender dynamicCastToClass:[NSPopUpButton class]];
  if (self->openFileTypeOpenPanel && openFilePopupButton)
  {
    NSInteger selectedIndex = [openFilePopupButton indexOfSelectedItem];
    if (selectedIndex == 0)
      [self->openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:(NSString*)kUTTypePDF, nil]];
    else if (selectedIndex == 1)
      [self->openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:(NSString*)kUTTypeText, nil]];
    else if (selectedIndex == 2)
      [self->openFileTypeOpenPanel setAllowedFileTypes:@[@"latexlib"]];
    else if (selectedIndex == 3)
      [self->openFileTypeOpenPanel setAllowedFileTypes:@[@"library"]];
    else if (selectedIndex == 4)
      [self->openFileTypeOpenPanel setAllowedFileTypes:@[@"latexhist"]];
    else if (selectedIndex == 5)
      [self->openFileTypeOpenPanel setAllowedFileTypes:@[@"latexpalette"]];
    else
      [self->openFileTypeOpenPanel setAllowedFileTypes:nil];
    [self->openFileTypeOpenPanel validateVisibleColumns2];
    [self->openFileOptions setObject:@(selectedIndex == 1) forKey:@"synchronizeAvailable"];
  }//end if (self->openFileTypeOpenPanel && openFilePopupButton)
}
//end changeOpenFileType:

-(BOOL) panel:(id)sender shouldEnableURL:(NSURL*)url
{
  BOOL result = YES;
  if (sender == self->openFileTypeOpenPanel)
  {
    NSString* filename = [url path];
    NSArray* allowedFileTypes = [self->openFileTypeOpenPanel allowedFileTypes];
    BOOL isDirectory = NO;
    result = ([[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory &&
              ![[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename]) ||
    [allowedFileTypes containsObject:[filename pathExtension]];
    NSEnumerator* enumerator = [allowedFileTypes objectEnumerator];
    NSString* itemUTI = nil;
    [url getResourceValue:&itemUTI forKey:NSURLTypeIdentifierKey error:nil];
    NSString* uti = nil;
    if (!result)
    {
      while(!result && ((uti = [enumerator nextObject])))
        result |= UTTypeConformsTo((CFStringRef)itemUTI, (CFStringRef)uti);
    }//end if (!result)
  }//end if (sender == self->openFileTypeOpenPanel)
  return result;
}
//end panel:shouldEnableURL:

-(IBAction) closeBackSync:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  [document closeBackSyncFile];
}
//end closeBackSync:

-(IBAction) saveAs:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  [document saveAs:sender];
}
//end saveAs:

-(IBAction) save:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  [document save:sender];
}
//end save:

-(IBAction) copyAs:(id)sender
{
  [[(MyDocument*)[self currentDocument] imageView] copy:sender]; 
}
//end copyAs:

-(IBAction) changeLatexMode:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
  {
    latex_mode_t mode = LATEX_MODE_TEXT;
    switch([sender tag])
    {
      case 1 : mode = LATEX_MODE_ALIGN; break;
      case 2 : mode = LATEX_MODE_DISPLAY; break;
      case 3 : mode = LATEX_MODE_INLINE; break;
      case 4 : mode = LATEX_MODE_TEXT; break;
      case 5 : mode = LATEX_MODE_AUTO; break;
      default: mode = LATEX_MODE_TEXT; break;
    }
    [document setLatexModeRequested:mode];
  }//end if (document)
}
//end makeLatexAndExport:

-(BOOL) isContinuousSpellCheckingAvailable
{
  BOOL result = NO;
  id firstResponder = [[NSApp keyWindow] firstResponder];
  result = [firstResponder respondsToSelector:@selector(setContinuousSpellCheckingEnabled:)];
  return result;
}
//end isContinuousSpellCheckingEnabled

-(IBAction) fontSizeChange:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
  {
    [document fontSizeChange:sender];
  }//end if (document)
}
//end fontSizeChange:

-(IBAction) formatChangeAlignment:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
  {
    alignment_mode_t alignment = ALIGNMENT_MODE_NONE;
    switch([sender tag])
    {
      case 0 : alignment = ALIGNMENT_MODE_UNDEFINED; break;
      case 1 : alignment = ALIGNMENT_MODE_NONE; break;
      case 2 : alignment = ALIGNMENT_MODE_LEFT; break;
      case 3 : alignment = ALIGNMENT_MODE_CENTER; break;
      case 4 : alignment = ALIGNMENT_MODE_RIGHT; break;
      default: alignment = ALIGNMENT_MODE_NONE; break;
    }
    [document formatChangeAlignment:alignment];
  }//end if (document)
}
//end formatChangeAlignment:

-(IBAction) formatComment:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document formatComment:sender];
}
//end formatComment:

-(IBAction) formatUncomment:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document formatUncomment:sender];
}
//end formatUncomment:

-(IBAction) makeLatexAndExport:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document latexizeAndExport:sender];
}
//end makeLatexAndExport:

-(IBAction) exportImage:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document exportImage:sender];
}
//end exportImage:

-(IBAction) reexportImage:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document reexportImage:sender];
}
//end reexportImage:

-(IBAction) makeLatex:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
  {
    [document setShouldApplyToPasteboardAfterLatexization:([sender tag] == 2)];
    [[document lowerBoxLatexizeButton] performClick:self];
    [document setShouldApplyToPasteboardAfterLatexization:NO];
  }
}
//end makeLatex:

-(IBAction) displayLog:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document displayLastLog:sender];
}
//end displayLog:

-(IBAction) displayBaseline:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document displayBaseline:sender];
}
//end displayBaseline:

-(IBAction) returnFromWhiteColorWarningWindow:(id)sender
{
  [NSApp stopModalWithCode:([sender tag] == 0) ? NSCancelButton : NSOKButton];
  [self->whiteColorWarningWindow close];
}
//end returnFromWhiteColorWarningWindow:

-(IBAction) historyRemoveHistoryEntries:(id)sender
{
  [[[self historyWindowController] historyView] removeSelection:sender];
}
//end historyRemoveHistoryEntries:

-(IBAction) historyClearHistory:(id)sender
{
  [[self historyWindowController] clearHistory:sender];
}
//end historyClearHistory:

-(IBAction) historyChangeLock:(id)sender
{
  [[HistoryManager sharedManager] setLocked:![[HistoryManager sharedManager] isLocked]];
}
//end historyLock:

-(IBAction) historyOpen:(id)sender
{
  [[self historyWindowController] open:sender];
}
//end libraryOpen:

-(IBAction) historySaveAs:(id)sender
{
  [[self historyWindowController] saveAs:sender];
}
//end historySaveAs:

-(IBAction) historyRelatexizeItems:(id)sender
{
  [[self historyWindowController] relatexizeSelectedItems:sender];
}
//end historyRelatexizeItems

-(IBAction) historyCompact:(id)sender
{
  [[HistoryManager sharedManager] vacuum];
}
//end historyCompact:

-(IBAction) showOrHideHistory:(id)sender
{
  NSWindowController* controller = [self historyWindowController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideHistory:

-(IBAction) libraryOpenEquation:(id)sender
{
  [[self libraryWindowController] openEquation:sender];
}
//end libraryImportCurrent:

-(IBAction) libraryOpenLinkedEquation:(id)sender
{
  [[self libraryWindowController] openLinkedEquation:sender];
}
//end libraryImportCurrent:

-(IBAction) libraryImportCurrent:(id)sender //creates a library item with the current document state
{
  [[self libraryWindowController] importCurrent:sender];
}
//end libraryImportCurrent:

-(IBAction) libraryNewFolder:(id)sender
{
  [[self libraryWindowController] newFolder:sender];
}
//end libraryNewFolder:

-(IBAction) libraryRemoveSelectedItems:(id)sender
{
  [[self libraryWindowController] removeSelectedItems:sender];
}
//end libraryRemoveSelectedItems:

-(IBAction) libraryRelatexizeItems:(id)sender
{
  [[self libraryWindowController] relatexizeSelectedItems:sender];
}
//end libraryRelatexizeItems

-(IBAction) libraryRenameItem:(id)sender
{
  [[self libraryWindowController] renameItem:sender];
}
//end libraryRenameItem:

-(IBAction) libraryRefreshItems:(id)sender
{
  [[self libraryWindowController] refreshItems:sender];
}
//end libraryRefreshItems:

-(IBAction) libraryToggleCommentsPane:(id)sender
{
  [[self libraryWindowController] toggleCommentsPane:sender];
}
//end libraryToggleCommentsPane:

-(IBAction) libraryOpen:(id)sender
{
  [[self libraryWindowController] open:sender];
}
//end libraryOpen:

-(IBAction) librarySaveAs:(id)sender
{
  [[self libraryWindowController] saveAs:sender];
}
//end librarySaveAs:

-(IBAction) libraryCompact:(id)sender
{
  [[LibraryManager sharedManager] vacuum];
}
//end libraryCompact

-(IBAction) showOrHideLibrary:(id)sender
{
  NSWindowController* controller = [self libraryWindowController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideLibrary:

-(IBAction) showOrHideColorInspector:(id)sender
{
  NSColorPanel* colorPanel = [NSColorPanel sharedColorPanel];
  if ([colorPanel isVisible])
    [colorPanel close];
  else
    [colorPanel orderFront:self];
}
//end showOrHideColorInspector:

-(IBAction) showOrHidePreamble:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
  {
    BOOL invertedPreambleVisibleState = ![document isPreambleVisible];
    [document setPreambleVisible:invertedPreambleVisibleState animate:YES];
  }//end if (document)
}
//end showOrHidePreamble:

-(IBAction) showOrHideLatexPalettes:(id)sender
{
  NSWindowController* controller = [self latexPalettesWindowController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideLatexPalettes:

-(IBAction) showOrHideAdditionalFiles:(id)sender
{
  NSWindowController* controller = [self additionalFilesWindowController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideAdditionalFiles:

-(IBAction) showOrHideCompositionConfiguration:(id)sender
{
  NSWindowController* controller = [self compositionConfigurationWindowController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideCompositionConfiguration:

-(IBAction) showOrHideEncapsulation:(id)sender
{
  NSWindowController* controller = [self encapsulationsWindowController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideEncapsulation:

-(IBAction) showOrHideMargin:(id)sender
{
  NSWindowController* controller = [self marginsWindowController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideMargin:

-(IBAction) reduceOrEnlargeTextArea:(id)sender
{
  [(MyDocument*)[self currentDocument] setReducedTextArea:![(MyDocument*)[self currentDocument] isReducedTextArea]];
}
//end reduceOrEnlargeTextArea:

-(IBAction) switchMiniWindow:(id)sender
{
  MyDocument* currentDocument = (MyDocument*)[self currentDocument];
  [currentDocument setDocumentStyle:([currentDocument documentStyle] == DOCUMENT_STYLE_NORMAL) ? DOCUMENT_STYLE_MINI : DOCUMENT_STYLE_NORMAL];
}
//end switchMiniWindow:

//ask for LaTeXiT's web site
-(IBAction) openWebSite:(id)sender
{
  NSMutableString* urlString =
    [NSMutableString stringWithString:NSLocalizedString(@"https://pierre.chachatelier.fr/latexit/index.php", @"")];
  if ([sender respondsToSelector:@selector(tag)] && ([sender tag] == 1))
    urlString =
      [NSMutableString stringWithString:NSLocalizedString(@"https://pierre.chachatelier.fr/latexit/latexit-donations.php", @"")];
  NSURL* webSiteURL = [NSURL URLWithString:urlString];

  BOOL ok = [[NSWorkspace sharedWorkspace] openURL:webSiteURL];
  if (!ok)
  {
    NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                   [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to reach %@.\n You should check your network.", @""),
                                              [webSiteURL absoluteString]],
                    @"OK", nil, nil);
  }
}
//end openWebSite:

//check for updates on LaTeXiT's web site
//if <sender> is nil, it's considered as a background task and will only present a panel if a new version is available.
-(IBAction) checkUpdates:(id)sender
{
  if (!sender)
    [self->sparkleUpdater checkForUpdatesInBackground];
  else
    [self->sparkleUpdater checkForUpdates:sender];
}
//end checkUpdates:

-(IBAction) showHelp:(id)sender
{
  BOOL ok = YES;
  NSString* string = [self->readmeTextView string];
  if (!string || ![string length])
  {
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* file = [mainBundle pathForResource:NSLocalizedString(@"Read Me", @"") ofType:@"rtfd"];
    ok = (file != nil);
    if (ok)
    {
      [self->readmeTextView readRTFDFromFile:file];
      [self->readmeTextView setBackgroundColor:[NSColor textBackgroundColor]];
      [self->readmeTextView setTextColor:[NSColor textColor]];
    }//end if (ok)
  }//end if (!string || ![string length])
  if (ok)
  {
    if (![self->readmeWindow isVisible])
      [self->readmeWindow center];
    [self->readmeWindow makeKeyAndOrderFront:self];
  }//end if (ok)
}
//end showHelp:

-(void) showHelp:(id)sender section:(NSString*)section
{
  [self showHelp:sender];
  NSString* helpString = [self->readmeTextView string];
  NSRange sectionRange = [helpString rangeOfString:section];
  [self->readmeTextView scrollRangeToVisible:sectionRange];
}
//end showHelp:section:

#pragma mark private engine helpers

-(NSString*) nameOfType:(export_format_t)format
{
  NSString* result = nil;
  switch(format)
  {
    case EXPORT_FORMAT_PDF : result = @"PDF";   break;
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS : result = NSLocalizedString(@"PDF with outlined fonts", @""); break;
    case EXPORT_FORMAT_EPS : result = @"EPS";   break;
    case EXPORT_FORMAT_TIFF : result = @"TIFF"; break;
    case EXPORT_FORMAT_PNG : result = @"PNG";   break;
    case EXPORT_FORMAT_JPEG : result = @"JPEG"; break;
    case EXPORT_FORMAT_MATHML : result = @"MATHML"; break;
    case EXPORT_FORMAT_SVG : result = @"SVG"; break;
    case EXPORT_FORMAT_TEXT : result = @"TEXT"; break;
    case EXPORT_FORMAT_RTFD : result = @"RTFD"; break;
  }//end switch(format)
  return result;
}
//end nameOfType:

-(void) _setEnvironment:(NSDictionary*)environment
{
  NSEnumerator* keyEnumerator = [environment keyEnumerator];
  NSString* key = nil;
  while((key = [keyEnumerator nextObject]))
  {
    NSString* value = [environment objectForKey:key];
    if (value)
      setenv([key UTF8String], [value UTF8String], 1);
  }//end for each environment key
}
//end _setEnvironment:

//looks for a programName in the given PATHs. Just tests that the file exists
-(NSString*) _findUnixProgram:(NSString*)programName inPrefixes:(NSArray*)prefixes
{
  NSString* path = nil;
  @synchronized(cachePaths)
  {
    path = [cachePaths objectForKey:programName];
  }//end @synchronized(cachePaths)
  if (!path && prefixes)
  {
    NSFileManager* fileManager = [NSFileManager defaultManager];
    NSEnumerator* enumerator = [prefixes objectEnumerator];
    NSString* prefix = nil;
    while(!path && (prefix = [enumerator nextObject]))
    {
      NSString* fullpath = [prefix stringByAppendingPathComponent:programName];
      BOOL isDirectory = NO;
      if ([fileManager fileExistsAtPath:fullpath isDirectory:&isDirectory] && !isDirectory &&
          [fileManager isExecutableFileAtPath:fullpath])
        path = fullpath;
    }
    if (path)
    {
      @synchronized(cachePaths)
      {
        [cachePaths setObject:path forKey:programName];
      }//end @synchronized(cachePaths)
    }//end if (path)
  }//end if (!path && prefixes)
  return path;  
}
//end _findUnixProgram:inPrefixes:

//looks for a programName in the environment.
-(NSString*) findUnixProgram:(NSString*)programName tryPrefixes:(NSArray*)prefixes environment:(NSDictionary*)environment useLoginShell:(BOOL)useLoginShell
{
  //first, it may be simply found in the common, usual, path
  NSString* path = nil;
  @synchronized(cachePaths)
  {
    [cachePaths objectForKey:programName];
  }//end @synchronized(cachePaths)
  if (!path)
    path = [self _findUnixProgram:programName inPrefixes:prefixes];

  if (!path) //if it is not...
  {
    //try to find it thanks to a "which" command
    NSString* whichPath = [self _findUnixProgram:@"which" inPrefixes:[[LaTeXProcessor sharedLaTeXProcessor] unixBins]];
    SystemTask* whichTask = [[SystemTask alloc] initWithWorkingDirectory:[[NSWorkspace sharedWorkspace] temporaryDirectory]];
    @try {
      [whichTask setArguments:[NSArray arrayWithObject:programName]];
      [whichTask setEnvironment:environment];
      [whichTask setLaunchPath:whichPath];
      [whichTask setUsingLoginShell:useLoginShell];
      [whichTask launch];
      [whichTask waitUntilExit];
      NSData* data = [whichTask dataForStdOutput];
      path = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
      if ([path length])
      {
        path = [path stringByDeletingLastPathComponent];
        path = [path stringByAppendingPathComponent:programName];
      }
    }
    @catch(NSException* e) {
    }
    @finally {
      [whichTask release];
    }
    if (path)
    {
      @synchronized(cachePaths)
      {
        [cachePaths setObject:path forKey:programName];
      }//end @synchronized(cachePaths)
    }//end if (path)
  }//end if (!path)
  return path;
}
//end findUnixProgram:tryPrefixes:environment:useLoginShell:

//returns the preamble that should be used, according to the fact that color.sty is available or not
-(NSAttributedString*) preambleLatexisationAttributedString
{
  NSAttributedString* result = [self adaptPreambleToCurrentConfiguration:[[PreferencesController sharedController] preambleDocumentAttributedString]];
  return result;
}
//end preambleLatexisationAttributedString

-(NSAttributedString*) preambleServiceAttributedString
{
  NSAttributedString* result = [self adaptPreambleToCurrentConfiguration:[[PreferencesController sharedController] preambleServiceAttributedString]];
  return result;
}
//end preambleServiceAttributedString

-(NSAttributedString*) adaptPreambleToCurrentConfiguration:(NSAttributedString*)preamble
{
  NSMutableAttributedString* mutablePreamble = [[preamble mutableCopy] autorelease];
  NSString* preambleString = [mutablePreamble string];
  if (![self isColorStyAvailable])
  {
    NSRange pdftexColorRange = [preambleString rangeOfString:@"{color}"];
    if (pdftexColorRange.location != NSNotFound)
    {
      NSRange lineRange = [preambleString lineRangeForRange:pdftexColorRange];
      if (lineRange.location != NSNotFound)
        [mutablePreamble insertAttributedString:[[[NSAttributedString alloc] initWithString:@"%"] autorelease]
                                       atIndex:lineRange.location];
    }//end if (pdftexColorRange.location != NSNotFound)
  }//end if (![self isColorStyAvailable])
  return mutablePreamble;
}
//end adaptPreambleToCurrentConfiguration:

-(BOOL) isGsAvailable
{
  return self->isGsAvailable;
}
//end isGsAvailable

-(BOOL) isDviPdfAvailable
{
  return self->isDviPdfAvailable;
}
//end isDvipdfAvailable

-(BOOL) isPdfLaTeXAvailable
{
  return self->isPdfLaTeXAvailable;
}
//end isPdfLatexAvailable

-(BOOL) isPsToPdfAvailable
{
  return self->isPsToPdfAvailable;
}
//end isPs2PdfAvailable

-(BOOL) isXeLaTeXAvailable
{
  return self->isXeLaTeXAvailable;
}
//end isXeLatexAvailable

-(BOOL) isLuaLaTeXAvailable
{
  return self->isLuaLaTeXAvailable;
}
//end isLuaLatexAvailable

-(BOOL) isLaTeXAvailable
{
  return self->isLaTeXAvailable;
}
//end isLaTeXAvailable

-(BOOL) isColorStyAvailable
{
  return self->isColorStyAvailable;
}
//end isColorStyAvailable

-(BOOL) isPdfToSvgAvailable
{
  return self->isPdfToSvgAvailable;
}
//end isPdfToSvgAvailable

-(BOOL) isPerlWithLibXMLAvailable
{
  return self->isPerlWithLibXMLAvailable;
}
//end isPerlWithLibXMLAvailable

//try to find gs program, searching by its name
-(void) _findPathWithConfiguration:(id)configuration
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSString*      pathKey         = [configuration objectForKey:@"path"];
  NSArray*       executableNames = [configuration objectForKey:@"executableNames"];
  NSFileManager* fileManager     = [NSFileManager defaultManager];
  NSString*      proposedPath    = nil;
  BOOL           useLoginShell   = NO;
  @synchronized(preferencesController){
    proposedPath  = !pathKey ? nil : 
                    [pathKey isEqualToString:DragExportSvgPdfToSvgPathKey] ? [preferencesController exportSvgPdfToSvgPath] :
                    [[preferencesController compositionConfigurationDocument] objectForKey:pathKey];
    useLoginShell = [[[preferencesController compositionConfigurationDocument] objectForKey:CompositionConfigurationUseLoginShellKey] boolValue];
  }//end @synchronized(preferencesController)
  NSMutableArray* prefixes = [NSMutableArray arrayWithArray:[[LaTeXProcessor sharedLaTeXProcessor] unixBins]];
  [prefixes addObjectsFromArray:[NSArray arrayWithObjects:[proposedPath stringByDeletingLastPathComponent], nil]];
  NSEnumerator* executableNameEnumerator = [executableNames objectEnumerator];
  NSString* executableName = nil;
  BOOL found = NO;
  while(!found && ((executableName = [executableNameEnumerator nextObject])))
  {
    BOOL isDirectory = NO;
    if (![fileManager fileExistsAtPath:proposedPath isDirectory:&isDirectory] || isDirectory ||
        ![fileManager isExecutableFileAtPath:proposedPath])
      proposedPath = [self findUnixProgram:executableName tryPrefixes:prefixes environment:[[LaTeXProcessor sharedLaTeXProcessor] extraEnvironment] useLoginShell:useLoginShell];
    if ([fileManager fileExistsAtPath:proposedPath])
    {
      found = YES;
      @synchronized(preferencesController){
        if ([pathKey isEqualToString:DragExportSvgPdfToSvgPathKey])
          [preferencesController setExportSvgPdfToSvgPath:proposedPath];
        else if (pathKey)
          [preferencesController setCompositionConfigurationDocumentProgramPath:proposedPath forKey:pathKey];
      }//end @synchronized(preferencesController)
    }//end @synchronized(preferencesController)
  }//end for each executableName
}
//end _findPathWithConfiguration:(id)configuration

-(void) _checkPathWithConfiguration:(id)configuration
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSDictionary* compositionConfiguration = nil;
  @synchronized(preferencesController){
    compositionConfiguration = [preferencesController compositionConfigurationDocument];
  }
  Semaphore* semaphore = [configuration objectForKey:@"semaphore"];
  composition_mode_t compositionMode = [compositionConfiguration compositionConfigurationCompositionMode];
  NSString* pathKey = [configuration objectForKey:@"path"];
  BOOL checkOnlyIfNecessary = [[configuration objectForKey:@"checkOnlyIfNecessary"] boolValue];
  BOOL shouldCheck =
    !pathKey ||
    [pathKey isEqualToString:DragExportSvgPdfToSvgPathKey] ||
    ([pathKey isEqualToString:CompositionConfigurationPdfLatexPathKey] && (!checkOnlyIfNecessary || (compositionMode == COMPOSITION_MODE_PDFLATEX))) ||
    ([pathKey isEqualToString:CompositionConfigurationXeLatexPathKey] && (!checkOnlyIfNecessary || (compositionMode == COMPOSITION_MODE_XELATEX))) ||
    ([pathKey isEqualToString:CompositionConfigurationLuaLatexPathKey] && (!checkOnlyIfNecessary || (compositionMode == COMPOSITION_MODE_LUALATEX))) ||
    ([pathKey isEqualToString:CompositionConfigurationLatexPathKey] && (!checkOnlyIfNecessary || (compositionMode == COMPOSITION_MODE_LATEXDVIPDF))) ||
    ([pathKey isEqualToString:CompositionConfigurationDviPdfPathKey] && (!checkOnlyIfNecessary || (compositionMode == COMPOSITION_MODE_LATEXDVIPDF))) ||
    ([pathKey isEqualToString:CompositionConfigurationGsPathKey]) ||
    ([pathKey isEqualToString:CompositionConfigurationPsToPdfPathKey]);
  BOOL* monitor = !shouldCheck ? 0 : (BOOL*)[[configuration objectForKey:@"monitor"] pointerValue];
  @try{
    if (monitor)
    {
      NSString* pathProposed = nil;
      @synchronized(preferencesController){
        pathProposed = !pathKey ? nil :
          [pathKey isEqualToString:DragExportSvgPdfToSvgPathKey] ? [preferencesController exportSvgPdfToSvgPath] :
          [[preferencesController compositionConfigurationDocument] objectForKey:pathKey];
      }
      BOOL pathProposedIsEmpty = !pathProposed || [pathProposed isEqualToString:@""];
      BOOL isDirectory = NO;
      BOOL ok = !pathProposedIsEmpty &&
                [[NSFileManager defaultManager] fileExistsAtPath:pathProposed isDirectory:&isDirectory] && !isDirectory &&
                [[NSFileManager defaultManager] isExecutableFileAtPath:pathProposed];
      //currently, the only check is the option -v, at least to see if the program can be executed
      NSString* options = (!pathKey || [pathKey isEqualToString:DragExportSvgPdfToSvgPathKey]
                                    || [pathKey isEqualToString:CompositionConfigurationPsToPdfPathKey]) ? @"" : @"-v";
      NSString* command = [NSString stringWithFormat:@"%@ %@ 1>|/dev/null 2>&1", pathProposed, options];
      int error = !ok ? 127 : system([command UTF8String]);
      BOOL useExitStatus = (pathKey != nil);
      error = (!ok || WIFSIGNALED(error) || !WIFEXITED(error) || WIFSTOPPED(error)) ? 127 :
              (!useExitStatus ? 0 : WEXITSTATUS(error));
      ok = ok &&
           ((error < 127) || ([pathKey isEqualToString:DragExportSvgPdfToSvgPathKey] && (error == ((unsigned char)-2))));
      *monitor = ok;

      NSDictionary* recursiveConfiguration =
        [configuration subDictionaryWithKeys:@[@"path", @"executableNames", @"monitor"]];
      BOOL allowFindOnFailure = [[configuration objectForKey:@"allowFindOnFailure"] boolValue];
      BOOL shouldFind = !ok && allowFindOnFailure;// && !pathProposedIsEmpty;
      if (shouldFind)
      {
        [self _findPathWithConfiguration:recursiveConfiguration];
        [self _checkPathWithConfiguration:recursiveConfiguration];
        ok = (*monitor);
      }//end if (shouldFind)

      BOOL allowUIAlertOnFailure =
        !self->shouldOpenInstallLaTeXHelp && [[configuration objectForKey:@"allowUIAlertOnFailure"] boolValue];
      BOOL allowUIFindOnFailure  =
        !self->shouldOpenInstallLaTeXHelp && [[configuration objectForKey:@"allowUIFindOnFailure"] boolValue];
      BOOL retry = !(*monitor) && allowUIAlertOnFailure;
      NSArray* executableNames = !retry ? nil : [configuration objectForKey:@"executableNames"];
      NSString* executableDisplayName = [configuration objectForKey:@"executableDisplayName"];
      if (!executableDisplayName)
        executableDisplayName = [executableNames firstObject];
      while (retry)
      {
        retry = NO;
        NSString* additionalInfo = ![executableDisplayName isEqualToString:@"ghostscript"] ? @"" :
          [NSString stringWithFormat:@"\n%@",
            NSLocalizedString(@"Unless you have installed X11, you should be sure that you use a version of ghostscript that does not require it (usually gs-nox11 instead of gs).", @"")];
        NSInteger returnCode =
          NSRunAlertPanel(
            [NSString stringWithFormat:
              NSLocalizedString(@"%@ not found or does not work as expected", @""), executableDisplayName],
            [NSString stringWithFormat:
              NSLocalizedString(@"The current configuration of LaTeXiT requires %@ to work.%@", @""), executableDisplayName, additionalInfo],
            !allowUIFindOnFailure ? @"OK" : [NSString stringWithFormat:NSLocalizedString(@"Find %@...", @""), executableDisplayName],
            !allowUIFindOnFailure ? nil : NSLocalizedString(@"Cancel", @""),
            !allowUIFindOnFailure ? nil : NSLocalizedString(@"What's that ?", @""),
            nil);
        if (allowUIFindOnFailure && (returnCode == NSAlertOtherReturn))
        {
          returnCode = NSRunAlertPanel(
            NSLocalizedString(@"What's that ?", @""),
            NSLocalizedString(@"LaTeXiT relies on a functional LaTeX installation. But if you do not know what LaTeX is, you may find it difficult to find and install it. A help section of the documentation is dedicated to that part.", @""),
            NSLocalizedString(@"See help...", @""),
            NSLocalizedString(@"Cancel", @""),
            nil);
          self->shouldOpenInstallLaTeXHelp |= (returnCode == NSAlertDefaultReturn);
        }//end if (allowUIFindOnFailure && (returnCode == NSAlertOtherReturn))
        else if (allowUIFindOnFailure && (returnCode == NSAlertDefaultReturn))
        {
          NSFileManager* fileManager = [NSFileManager defaultManager];
          NSOpenPanel* openPanel = [NSOpenPanel openPanel];
          [openPanel setResolvesAliases:NO];
          [openPanel setDirectoryURL:[NSURL fileURLWithPath:@"/usr" isDirectory:YES]];
          NSInteger ret2 = [openPanel runModal];
          ok = (ret2 == NSOKButton) && ([[openPanel URLs] count]);
          if (ok)
          {
            NSString* filepath = [[[openPanel URLs] objectAtIndex:0] path];
            if (![fileManager fileExistsAtPath:filepath])
              retry = YES;
            else
            {
              [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:[filepath stringByDeletingLastPathComponent]];
              @synchronized(preferencesController){
                if ([pathKey isEqualToString:DragExportSvgPdfToSvgPathKey])
                  [preferencesController setExportSvgPdfToSvgPath:pathKey];
                else if (pathKey)
                  [preferencesController setCompositionConfigurationDocumentProgramPath:filepath forKey:pathKey];
              }//end @synchronized(preferencesController)
              [self _checkPathWithConfiguration:recursiveConfiguration];
              ok = (*monitor);
              retry = !ok;
            }//end if ([fileManager fileExistsAtPath:filepath])
          }//end if (ok)
        }//end if (allowUIFindOnFailure && (returnCode == NSAlertDefaultReturn))
      }//end while(retry)

      *monitor = ok;
    }//end if (monitor)

    BOOL updateGUIfromSystemAvailabilities = [[configuration objectForKey:@"updateGUIfromSystemAvailabilities"] boolValue];
    if (updateGUIfromSystemAvailabilities)
      [self performSelectorOnMainThread:@selector(updateGUIfromSystemAvailabilities) withObject:nil waitUntilDone:YES];
  }
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
    if (monitor) *monitor = NO;
  }
  [semaphore P];
}
//end _checkPathWithConfiguration:

//checks if color.sty is available, by compiling a simple latex string that uses it
-(void) _checkColorStyWithConfiguration:(id)configuration
{
  Semaphore* semaphore = [configuration objectForKey:@"semaphore"];
  @try{
    BOOL ok = YES;

    PreferencesController* preferencesController = [PreferencesController sharedController];
    //first try with kpsewhich
    BOOL useLoginShell = NO;
    @synchronized(preferencesController){
      useLoginShell = [[[preferencesController compositionConfigurationDocument] objectForKey:CompositionConfigurationUseLoginShellKey] boolValue];
    }
    NSString* kpseWhichPath = [self findUnixProgram:@"kpsewhich" tryPrefixes:[[LaTeXProcessor sharedLaTeXProcessor] unixBins] environment:[[LaTeXProcessor sharedLaTeXProcessor] extraEnvironment] useLoginShell:useLoginShell];
    ok = kpseWhichPath && ![kpseWhichPath isEqualToString:@""];
    if (ok)
    {
      SystemTask* kpseWhichTask = [[SystemTask alloc] init];
      @try{
        NSString* directory      = [[NSWorkspace sharedWorkspace] temporaryDirectory];
        //NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
        [kpseWhichTask setCurrentDirectoryPath:directory];
        NSString* launchPath = kpseWhichPath;
        BOOL isDirectory = YES;
        if ([[NSFileManager defaultManager] fileExistsAtPath:launchPath isDirectory:&isDirectory] && !isDirectory)
        {
          [kpseWhichTask setEnvironment:[[LaTeXProcessor sharedLaTeXProcessor] extraEnvironment]];
          [kpseWhichTask setLaunchPath:launchPath];
          [kpseWhichTask setArguments:[NSArray arrayWithObject:@"color.sty"]];
          [kpseWhichTask setTimeOut:3.0];
          [kpseWhichTask launch];
          [kpseWhichTask waitUntilExit];
          ok = ([kpseWhichTask terminationStatus] == 0);
        }//end if ([[NSFileManager defaultManager] fileExistsAtPath:launchPath isDirectory:&isDirectory] && !isDirectory)
      }
      @catch(NSException* e) {
        ok = NO;
      }
      [kpseWhichTask release];
    }//end check kpsewhich

    /*
    ok = kpseWhichPath  && [kpseWhichPath length] &&
           (system([[NSString stringWithFormat:@"%@ %@ 1>|/dev/null 2>&1", kpseWhichPath, @"color.sty"] UTF8String]) == 0);
    */

    //perhaps second try without kpsewhich
    if (!ok)
    {
      NSArray* latexProgramsPathsKeys =
        [NSArray arrayWithObjects:CompositionConfigurationPdfLatexPathKey,
                                  CompositionConfigurationLatexPathKey,
                                  CompositionConfigurationXeLatexPathKey,
                                  CompositionConfigurationLuaLatexPathKey,
                                  nil];
      NSEnumerator* enumerator = [latexProgramsPathsKeys objectEnumerator];
      NSString* pathKey = nil;
      while(!ok && ((pathKey = [enumerator nextObject])))
      {
        NSTask* checkTask = [[NSTask alloc] init];
        @try
        {
          NSDictionary* compositionConfiguration = nil;
          @synchronized(preferencesController){
            compositionConfiguration = [preferencesController compositionConfigurationDocument];
          }
          NSString* testString = @"\\documentclass[10pt]{article}\\usepackage{color}\\begin{document}\\end{document}";
          NSString* directory      = [[NSWorkspace sharedWorkspace] temporaryDirectory];
          NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
          [checkTask setCurrentDirectoryPath:directory];
          NSString* launchPath = nil;
          @synchronized(preferencesController){
            launchPath = [[preferencesController compositionConfigurationDocument] objectForKey:pathKey];
          }
          BOOL isDirectory = YES;
          if ([[NSFileManager defaultManager] fileExistsAtPath:launchPath isDirectory:&isDirectory] && !isDirectory)
          {
            [checkTask setEnvironment:[[LaTeXProcessor sharedLaTeXProcessor] extraEnvironment]];
            [checkTask setLaunchPath:launchPath];
            [checkTask setArguments:[[compositionConfiguration compositionConfigurationProgramArgumentsForKey:pathKey] arrayByAddingObjectsFromArray:
              [NSArray arrayWithObjects:@"--interaction", @"nonstopmode", testString, nil]]];
            [checkTask setStandardOutput:nullDevice];
            [checkTask setStandardError:nullDevice];
            [checkTask launch];
            [checkTask waitUntilExit];
            ok = ([checkTask terminationStatus] == 0);
          }
        }
        @catch(NSException* e) {
          DebugLog(0, @"exception : %@", e);
          ok = NO;
        }
        [checkTask release];
      }//end for each latex executable
    }//end if kpsewhich failed

    self->isColorStyAvailable = ok;
  }
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
    self->isColorStyAvailable = NO;
  }
  [semaphore P];
}
//end _checkColorSty:

-(void) beginCheckUpdates
{
  ++self->checkLevel;
}
//end beginCheckUpdates

-(void) endCheckUpdates
{
  --self->checkLevel;
  if (self->updateGUIFlag)
  {
    self->updateGUIFlag = NO;
    [self updateGUIfromSystemAvailabilities];
  }
}
//end endCheckUpdates

-(BOOL) isCheckUpdating
{
  BOOL result = (self->checkLevel != 0);
  return result;
}
//end isCheckUpdating

-(void) updateGUIfromSystemAvailabilities
{
  if ([self isCheckUpdating])
    self->updateGUIFlag = YES;
  else
    [[NSApp orderedDocuments] makeObjectsPerformSelector:@selector(updateGUIfromSystemAvailabilities)];
}
//end updateGUIfromSystemAvailabilities

#pragma mark linkback

-(MyDocument*) documentForLink:(LinkBack*)link
{
  MyDocument* result = nil;
  NSEnumerator* enumerator = !link ? nil : [[NSApp orderedDocuments] objectEnumerator];
  MyDocument* document = nil;
  while((document = [enumerator nextObject]))
  {
    LinkBack* documentLink = [document linkBackLink];
    if ((documentLink == link) || [[documentLink itemKey] isEqual:[link itemKey]])
      result = document;
    if (result)
      break;
  }//for each document
  return result;
}
//end documentForLink:

-(void) closeLinkBackLink:(LinkBack*)link
{
  MyDocument* document = [self documentForLink:link];
  [document setLinkBackLink:nil];
}
//end closeLinkBackLink:

-(void) linkBackDidClose:(LinkBack*)link
{
  [self closeLinkBackLink:link];
}
//end linkBackDidClose:

//a link back request will create a new document thanks to the available data, as historyItems
-(void) linkBackClientDidRequestEdit:(LinkBack*)link
{
  NSData* linkbackItemsData = [[[link pasteboard] propertyListForType:LinkBackPboardType] linkBackAppData];
  NSError* decodingError = nil;
  NSArray* linkbackItems = !linkbackItemsData ? nil :
    isMacOS10_13OrAbove() ? [[NSKeyedUnarchiver unarchivedObjectOfClasses:[HistoryItem allowedSecureDecodedClasses] fromData:linkbackItemsData error:&decodingError] dynamicCastToClass:[NSArray class]] :
    [[NSKeyedUnarchiver unarchiveObjectWithData:linkbackItemsData] dynamicCastToClass:[NSArray class]];
  if (decodingError != nil)
    DebugLog(0, @"decoding error : %@", decodingError);
  id firstLinkBackItem = (linkbackItems && [linkbackItems count]) ? [linkbackItems objectAtIndex:0] : nil;
  HistoryItem* historyItem = [firstLinkBackItem isKindOfClass:[HistoryItem class]] ? firstLinkBackItem : nil;
  LatexitEquation* latexitEquation =
    historyItem ? [historyItem equation] :
    [firstLinkBackItem isKindOfClass:[LatexitEquation class]] ? firstLinkBackItem :
    nil;

  MyDocument* document = [self documentForLink:link];
  if (!document)
  {
    NSDocumentController* documentController = [NSDocumentController sharedDocumentController];
    //document = (MyDocument*)[documentController openUntitledDocumentOfType:@"MyDocumentType" display:YES];
    document = (MyDocument*)[documentController makeUntitledDocumentOfType:@"MyDocumentType" error:nil];
    if (document != nil)
    {
      [documentController addDocument:document];
      [document makeWindowControllers];
      [document showWindows];
    }//end if (document != nil)
  }//end if (!document)
  if (document && latexitEquation)
  {
    if ([document linkBackLink] != link)
      [document setLinkBackLink:link];//automatically closes previous links
    [document applyLatexitEquation:latexitEquation isRecentLatexisation:NO]; //defines the state of the document
    [NSApp activateIgnoringOtherApps:YES];
    NSArray* windows = [document windowControllers];
    NSWindow* window = [[windows lastObject] window];
    [document setDocumentTitle:NSLocalizedString(@"Equation linked with another application", @"")];
    [window makeKeyAndOrderFront:self];
    [window makeFirstResponder:[document preferredFirstResponder]];
  }//end if (document && latexitEquation)
}
//end linkBackClientDidRequestEdit:

#pragma mark service

-(void) serviceLatexisationAlign:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_ALIGN putIntoClipBoard:NO error:error];
}
//end serviceLatexisationAlign:userData:error:

-(void) serviceLatexisationAlignAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_ALIGN putIntoClipBoard:YES error:error];
}
//end serviceLatexisationAlignAndPutIntoClipBoard:userData:error:

-(void) serviceLatexisationEqnarray:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_EQNARRAY putIntoClipBoard:NO error:error];
}
//end serviceLatexisationEqnarray:userData:error:

-(void) serviceLatexisationEqnarrayAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_EQNARRAY putIntoClipBoard:YES error:error];
}
//end serviceLatexisationEqnarrayAndPutIntoClipBoard:userData:error:

-(void) serviceLatexisationDisplay:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_DISPLAY putIntoClipBoard:NO error:error];
}
//end serviceLatexisationDisplay:userData:error:

-(void) serviceLatexisationDisplayAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_DISPLAY putIntoClipBoard:YES error:error];
}
//end serviceLatexisationDisplayAndPutIntoClipBoard:userData:error:

-(void) serviceLatexisationInline:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_INLINE putIntoClipBoard:NO error:error];
}
//end serviceLatexisationInline:userData:error:

-(void) serviceLatexisationInlineAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_INLINE putIntoClipBoard:YES error:error];
}
//end serviceLatexisationInlineAndPutIntoClipBoard:userData:error:

-(void) serviceLatexisationText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_TEXT putIntoClipBoard:NO error:error];
}
//end serviceLatexisationText:userData:error:

-(void) serviceLatexisationTextAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_TEXT putIntoClipBoard:YES error:error];
}
//end serviceLatexisationTextAndPutIntoClipBoard:userData:error:

-(void) serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceMultiLatexisation:pboard userData:userData putIntoClipBoard:NO error:error];
}
//end serviceMultiLatexisation:userData:error:

-(void) serviceMultiLatexisationAndPutIntoClipBoard:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceMultiLatexisation:pboard userData:userData putIntoClipBoard:YES error:error];
}
//end serviceMultiLatexisationAndPutIntoClipBoard:userData:error:

-(void) serviceDeLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceDeLatexisation:pboard userData:userData error:error];
}
//end serviceDeLatexisation:userData:error:

//performs the application service
-(void) _serviceLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData mode:(latex_mode_t)mode putIntoClipBoard:(BOOL)putIntoClipBoard
                       error:(NSString **)error
{
  if (!self->isPdfLaTeXAvailable || !self->isGsAvailable)
  {
    NSString* message = NSLocalizedString(@"LaTeXiT cannot be run properly, please check its configuration", @"");
    *error = message;
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), message, @"OK", nil, nil);
  }
  else
  {
    @synchronized(self) //one latexisation at a time
    {
      NSArray* types = [[[pboard types] mutableCopy] autorelease];
      NSMutableDictionary* dummyPboard = [NSMutableDictionary dictionary];

      NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
      BOOL useColor     = [userDefaults boolForKey:ServiceRespectsColorKey];
      BOOL useBaseline  = [userDefaults boolForKey:ServiceRespectsBaselineKey];
      BOOL usePointSize = [userDefaults boolForKey:ServiceRespectsPointSizeKey];
      CGFloat pointSizeFactor = [userDefaults floatForKey:ServicePointSizeFactorKey];
      double defaultPointSize = [userDefaults floatForKey:DefaultPointSizeKey];
      
      //in the case of RTF input, we may deduce size, color, and change baseline
      if ([types containsObject:NSRTFPboardType] || [types containsObject:(NSString*)kUTTypeRTF])
      {
        NSDictionary* documentAttributes = nil;
        NSData* pboardData = [pboard dataForType:NSRTFPboardType];
        if (!pboardData)
          pboardData = [pboard dataForType:(NSString*)kUTTypeRTF];
        NSAttributedString* attrString = [[[NSAttributedString alloc] initWithRTF:pboardData
                                                               documentAttributes:&documentAttributes] autorelease];

        //remove textlists at the beginning of the text
        NSMutableAttributedString* attrString2 = [[attrString mutableCopy] autorelease];
        NSRange prange;
        NSMutableParagraphStyle*   pStyle = [[[attrString2 attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:&prange] mutableCopy] autorelease];
        NSArray* textLists = [pStyle textLists];
        NSEnumerator* enumerator = [textLists objectEnumerator];
        NSTextList* textList = nil;
        while((textList = [enumerator nextObject]))
        {
          NSString* attrStringAsString = [attrString2 string];
          NSInteger itemNumber  = [attrString itemNumberInTextList:textList atIndex:0];
          NSString* header = [textList markerForItemNumber:itemNumber];
          NSRange range1 = [attrStringAsString rangeOfString:header];
          NSRange range2 = [attrStringAsString rangeOfString:[NSString stringWithFormat:@"\t%@\t",header]];
          if (!range1.location) [attrString2 deleteCharactersInRange:range1];
          if (!range2.location) [attrString2 deleteCharactersInRange:range2];
        }//end for each textList
        attrString = attrString2;
        
        NSDictionary* contextAttributes = [attrString attributesAtIndex:0 effectiveRange:NULL];
        NSFont*  font  = usePointSize ? [contextAttributes objectForKey:NSFontAttributeName] : nil;
        CGFloat pointSize = font ? [font pointSize]*pointSizeFactor : defaultPointSize;
        CGFloat magnification = pointSize;
        NSColor* color = useColor ? [contextAttributes objectForKey:NSForegroundColorAttributeName] : nil;
        if (!color) color = [NSColor colorWithData:[userDefaults objectForKey:DefaultColorKey]];
        CGFloat originalBaseline = (CGFloat)[[[contextAttributes objectForKey:NSBaselineOffsetAttributeName] dynamicCastToClass:[NSNumber class]] doubleValue];
        NSString* pboardString = [attrString string];
        NSString* preamble = [[LaTeXProcessor sharedLaTeXProcessor] insertColorInPreamble:[[self preambleServiceAttributedString] string] color:color isColorStyAvailable:[self isColorStyAvailable]];
        NSString* body = pboardString;
        
        //perform effective latexisation
        NSData* pdfData = nil;
        NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
        NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-service"];
        NSDictionary* fullEnvironment  = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];

        PreferencesController* preferencesController = [PreferencesController sharedController];
        CGFloat leftMargin   = [self marginsCurrentLeftMargin];
        CGFloat rightMargin  = [self marginsCurrentRightMargin];
        CGFloat bottomMargin = [self marginsCurrentBottomMargin];
        CGFloat topMargin    = [self marginsCurrentTopMargin];
        [[LaTeXProcessor sharedLaTeXProcessor] latexiseWithPreamble:preamble body:body color:color mode:mode
          magnification:magnification
          compositionConfiguration:[preferencesController compositionConfigurationDocument]
          backgroundColor:nil
                    title:nil
          leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin
          additionalFilesPaths:[self additionalFilesPaths]
          workingDirectory:workingDirectory fullEnvironment:fullEnvironment
          uniqueIdentifier:uniqueIdentifier
          outFullLog:nil outErrors:nil outPdfData:&pdfData];
        //if it has worked, put back data in the service pasteboard
        if ([pdfData length])
        {
          //we will create the image file that will be attached to the rtfd
          NSString* directory          = [[NSWorkspace sharedWorkspace] temporaryDirectory];
          NSString* filePrefix         = [NSString stringWithFormat:@"latexit-%d", 0];
          NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
          export_format_t exportFormat = (export_format_t)[userDefaults integerForKey:DragExportTypeKey];
          NSString* extension = nil;
          switch(exportFormat)
          {
            case EXPORT_FORMAT_PDF:
            case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
              extension = @"pdf";
              break;
            case EXPORT_FORMAT_EPS:
              extension = @"eps";
              break;
            case EXPORT_FORMAT_TIFF:
              extension = @"tiff";
              break;
            case EXPORT_FORMAT_PNG:
              extension = @"png";
              break;
            case EXPORT_FORMAT_JPEG:
              extension = @"jpeg";
              break;
            case EXPORT_FORMAT_MATHML:
              extension = @"html";
              break;
            case EXPORT_FORMAT_SVG:
              extension = @"svg";
              break;
            case EXPORT_FORMAT_TEXT:
              extension = @"tex";
              break;
            case EXPORT_FORMAT_RTFD:
              extension = @"rtfd";
              break;
          }//end switch(exportFormat)

          NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @([preferencesController exportJpegQualityPercent]), @"jpegQuality",
                                         @([preferencesController exportScalePercent]), @"scaleAsPercent",
                                         @([preferencesController exportIncludeBackgroundColor]), @"exportIncludeBackgroundColor",
                                         @([preferencesController exportTextExportPreamble]), @"textExportPreamble",
                                         @([preferencesController exportTextExportEnvironment]), @"textExportEnvironment",
                                         @([preferencesController exportTextExportBody]), @"textExportBody",
                                         [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                         nil];
          NSString* attachedFile     = [NSString stringWithFormat:@"%@.%@", filePrefix, extension];
          NSString* attachedFilePath = [directory stringByAppendingPathComponent:attachedFile];
          NSURL*    attachedFileURL  = !attachedFilePath ? nil : [NSURL fileURLWithPath:attachedFilePath];
          NSData*   attachedData     = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData
                                         exportOptions:exportOptions
                                         compositionConfiguration:[preferencesController compositionConfigurationDocument]
                                         uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];

          //Now we must feed the pasteboard
          //[pboard declareTypes:[NSArray array] owner:nil];

           //we try to make RTFD data only if the user wants to use the baseline, because there is
           //a side-effect : it "disables" LinkBack (can't click on an image embedded in RTFD)
          if (useBaseline)
          {
            //extracts the baseline of the equation, if possible
            CGFloat newBaseline = originalBaseline;
            if (useBaseline)
              newBaseline -= [[[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:&pdfData] objectForKey:@"baseline"] doubleValue];//[LatexitEquation baselineFromData:pdfData];

            //creates a mutable attributed string containing the image file
            [attachedData writeToFile:attachedFilePath atomically:NO];
            NSFileWrapper*      fileWrapperOfImage        = [[[NSFileWrapper alloc] initWithURL:attachedFileURL options:0 error:nil] autorelease];
            NSTextAttachment*   textAttachmentOfImage     = [[[NSTextAttachment alloc] initWithFileWrapper:fileWrapperOfImage] autorelease];
            NSAttributedString* attributedStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachmentOfImage];
            NSMutableAttributedString* mutableAttributedStringWithImage =
              [[[NSMutableAttributedString alloc] initWithAttributedString:attributedStringWithImage] autorelease];
              
            //changes the baseline of the attachment to align it with the surrounding text
            [mutableAttributedStringWithImage addAttribute:NSBaselineOffsetAttributeName
                                                     value:@(newBaseline)
                                                     range:mutableAttributedStringWithImage.range];
            
            //add a space after the image, to restore the baseline of the surrounding text
            //Gee! It works with TextEdit but not with Pages. That is to say, in Pages, if I put this space, the baseline of
            //the equation is reset. And if do not put this space, the cursor stays in "tuned baseline" mode.
            //However, it works with Nisus Writer Express, so that I think it is a bug in Pages
            const unichar invisibleSpace = 0xFEFF;
            NSString* invisibleSpaceString = [[[NSString alloc] initWithCharacters:&invisibleSpace length:1] autorelease];
            NSMutableAttributedString* spaceWithoutCustomBaseline =
              [[[NSMutableAttributedString alloc] initWithString:invisibleSpaceString] autorelease];
            [spaceWithoutCustomBaseline setAttributes:contextAttributes range:spaceWithoutCustomBaseline.range];
            NSMutableAttributedString* spaceWithCustomBaseline = [[spaceWithoutCustomBaseline mutableCopy] autorelease];
            [spaceWithCustomBaseline addAttribute:NSBaselineOffsetAttributeName value:@(newBaseline) range:spaceWithCustomBaseline.range];
            [mutableAttributedStringWithImage insertAttributedString:spaceWithCustomBaseline atIndex:0];
            [mutableAttributedStringWithImage appendAttributedString:spaceWithCustomBaseline];
            [mutableAttributedStringWithImage appendAttributedString:spaceWithoutCustomBaseline];

            //finally creates the rtdfData
            NSData* rtfdData = [mutableAttributedStringWithImage RTFDFromRange:mutableAttributedStringWithImage.range
                                                            documentAttributes:documentAttributes];
            //RTFd data
            //[pboard addTypes:[NSArray arrayWithObject:NSRTFDPboardType] owner:nil];
            //[pboard setData:rtfdData forType:NSRTFDPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:kUTTypeRTFD] owner:nil];
            //[pboard setData:rtfdData forType:kUTTypeRTFD];
            if (rtfdData)
            {
              [dummyPboard setObject:rtfdData forKey:NSRTFDPboardType];
              [dummyPboard setObject:rtfdData forKey:(NSString*)kUTTypeRTFD];
            }//end if (rtfdData)
          }//end if useBaseline

          //LinkBack data
          NSAttributedString* attributedPreamble = [[NSAttributedString alloc] initWithString:preamble];
          LatexitEquation* latexitEquation =
            [[LatexitEquation alloc] initWithPDFData:pdfData preamble:attributedPreamble
                                         sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                              color:[NSColor blackColor] pointSize:defaultPointSize date:[NSDate date] mode:mode
                                    backgroundColor:nil title:nil];
          [attributedPreamble release];
          HistoryItem* historyItem = [[HistoryItem alloc] initWithEquation:latexitEquation insertIntoManagedObjectContext:nil];
          NSArray* historyItemArray = [NSArray arrayWithObjects:historyItem, nil];
          [historyItem release];
          [latexitEquation release];
          NSData* historyItemData = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
          NSDictionary* linkBackPlist = [NSDictionary linkBackDataWithServerName:[[NSWorkspace sharedWorkspace] applicationName] appData:historyItemData];
          if ([[PreferencesController sharedController] historySaveServicesResultsEnabled])//we may add the item to the history
            [self addHistoryItemToHistory:historyItem];
        
          //[pboard addTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:nil];
          //[pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];
            if (linkBackPlist)
              [dummyPboard setObject:linkBackPlist forKey:LinkBackPboardType];

          //and additional data according to the export type (pdf, eps, tiff, jpeg, png...)
          if ([extension isEqualToString:@"pdf"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:nil];
            //[pboard setData:pdfData forType:NSPDFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:(NSString*)kUTTypePDF] owner:nil];
            //[pboard setData:pdfData forType:(NSString*)kUTTypePDF];
            if (pdfData)
            {
              [dummyPboard setObject:pdfData forKey:NSPDFPboardType];
              [dummyPboard setObject:pdfData forKey:(NSString*)kUTTypePDF];
            }//end if (pdfData)
          }//end if ([extension isEqualToString:@"pdf"])
          else if ([extension isEqualToString:@"eps"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSPostScriptPboardType] owner:nil];
            //[pboard setData:attachedData forType:NSPostScriptPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:@"com.adobe.encapsulated-postscript"] owner:nil];
            //[pboard setData:attachedData forType:@"com.adobe.encapsulated-postscript"];
            if (attachedData)
            {
              [dummyPboard setObject:attachedData forKey:NSPostScriptPboardType];
              [dummyPboard setObject:attachedData forKey:@"com.adobe.encapsulated-postscript"];
            }//end if (attachedData)
          }//end if ([extension isEqualToString:@"eps"])
          else if ([extension isEqualToString:@"png"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:(NSString*)kUTTypePNG] owner:nil];
            //[pboard setData:attachedData forType:(NSString*)kUTTypePNG];
            if (attachedData)
              [dummyPboard setObject:attachedData forKey:(NSString*)kUTTypePNG];
          }//end if ([extension isEqualToString:@"png"])
          else if ([extension isEqualToString:@"tiff"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            //[pboard setData:attachedData forType:NSTIFFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:(NSString*)kUTTypeTIFF] owner:nil];
            //[pboard setData:attachedData forType:(NSString*)kUTTypeTIFF];
            if (attachedData)
            {
              [dummyPboard setObject:attachedData forKey:NSTIFFPboardType];
              [dummyPboard setObject:attachedData forKey:(NSString*)kUTTypeTIFF];
            }//end if (attachedData)
          }//end if ([extension isEqualToString:@"tiff"])
          else if ([extension isEqualToString:@"jpeg"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            //[pboard setData:attachedData forType:NSTIFFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:kUTTypeJPEG] owner:nil];
            //[pboard setData:attachedData forType:kUTTypeJPEG];
            if (attachedData)
            {
              [dummyPboard setObject:attachedData forKey:NSTIFFPboardType];
              [dummyPboard setObject:attachedData forKey:(NSString*)kUTTypeJPEG];
            }//end if (attachedData)
          }//end if ([extension isEqualToString:@"jpeg"])
        }//end if ([pdfData length])
        else//if (![pdfData length])
        {
          NSString* message = NSLocalizedString(@"This text is not LaTeX compliant; or perhaps it is a preamble problem ? You can check it in LaTeXiT", @"");
          *error = message;
          [NSApp activateIgnoringOtherApps:YES];
          NSInteger choice = NSRunAlertPanel(NSLocalizedString(@"Error", @""), message, NSLocalizedString(@"Cancel", @""),
                                       NSLocalizedString(@"Open in LaTeXiT", @""), nil);
          if (choice == NSAlertAlternateReturn)
          {
            NSDocumentController* documentController = [NSDocumentController sharedDocumentController];
            //MyDocument* document = [documentController openUntitledDocumentOfType:@"MyDocumentType" display:YES];
            MyDocument* document = (MyDocument*)[documentController makeUntitledDocumentOfType:@"MyDocumentType" error:nil];
            if (document != nil)
            {
              [documentController addDocument:document];
              [document makeWindowControllers];
              [document showWindows];
            }//end if (document != nil)
            [document setSourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]];
            [document setLatexModeRequested:mode];
            [document setColor:color];
            [document setMagnification:magnification];
            [[document windowForSheet] makeFirstResponder:[document preferredFirstResponder]];
            [document latexize:self];
          }//end if (choice == NSAlertAlternateReturn)
        }//end //if (![pdfData length])
      }
      //if the input is not RTF but just string, we will use default color and size
      else if ([types containsObject:NSStringPboardType] || [types containsObject:NSPDFPboardType])
      {
        NSAttributedString* preamble = [self preambleServiceAttributedString];
        NSString* pboardString = nil;
        if ([types containsObject:NSPDFPboardType])
        {
          NSData* pdfData = [pboard dataForType:NSPDFPboardType];
          NSString* pdfString = CGPDFDocumentCreateStringRepresentationFromData(pdfData);
          pboardString = pdfString;
        }//end if ([types containsObject:NSPDFPboardType])
        else if ([types containsObject:(NSString*)kUTTypePDF])
        {
          NSData* pdfData = [pboard dataForType:NSPDFPboardType];
          NSString* pdfString = CGPDFDocumentCreateStringRepresentationFromData(pdfData);
          pboardString = pdfString;
        }//end if ([types containsObject:(NSString*)kUTTypePDF])
        if (!pboardString)
          pboardString = [pboard stringForType:NSStringPboardType];
        if (!pboardString)
          pboardString = [pboard stringForType:@"public.utf8-plain-text"];
        NSString* body = pboardString;

        //perform effective latexisation
        NSData* pdfData = nil;
        NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
        NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-service"];
        NSDictionary* fullEnvironment  = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];

        PreferencesController* preferencesController = [PreferencesController sharedController];
        CGFloat leftMargin   = [self marginsCurrentLeftMargin];
        CGFloat rightMargin  = [self marginsCurrentRightMargin];
        CGFloat bottomMargin = [self marginsCurrentBottomMargin];
        CGFloat topMargin    = [self marginsCurrentTopMargin];
        [[LaTeXProcessor sharedLaTeXProcessor] latexiseWithPreamble:[preamble string] body:body color:[NSColor blackColor]
          mode:mode magnification:defaultPointSize
          compositionConfiguration:[preferencesController compositionConfigurationDocument]
          backgroundColor:nil
                    title:nil
          leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin
          additionalFilesPaths:[self additionalFilesPaths]
          workingDirectory:workingDirectory fullEnvironment:fullEnvironment
          uniqueIdentifier:uniqueIdentifier
          outFullLog:nil outErrors:nil outPdfData:&pdfData];

        //if it has worked, put back data in the service pasteboard
        if ([pdfData length])
        {
          //translates the data to the right format
          NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
          export_format_t exportFormat = (export_format_t)[userDefaults integerForKey:DragExportTypeKey];
          NSString* extension = nil;
          switch(exportFormat)
          {
            case EXPORT_FORMAT_PDF:
            case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
              extension = @"pdf";
              break;
            case EXPORT_FORMAT_EPS:
              extension = @"eps";
              break;
            case EXPORT_FORMAT_TIFF:
              extension = @"tiff";
              break;
            case EXPORT_FORMAT_PNG:
              extension = @"png";
              break;
            case EXPORT_FORMAT_JPEG:
              extension = @"jpeg";
              break;
            case EXPORT_FORMAT_MATHML:
              extension = @"html";
              break;
            case EXPORT_FORMAT_SVG:
              extension = @"svg";
              break;
            case EXPORT_FORMAT_TEXT:
              extension = @"tex";
              break;
            case EXPORT_FORMAT_RTFD:
              extension = @"rtfd";
              break;
          }//end switch(exportFormat)

          NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                         @([preferencesController exportJpegQualityPercent]), @"jpegQuality",
                                         @([preferencesController exportScalePercent]), @"scaleAsPercent",
                                         @([preferencesController exportIncludeBackgroundColor]), @"exportIncludeBackgroundColor",
                                         @([preferencesController exportTextExportPreamble]), @"textExportPreamble",
                                         @([preferencesController exportTextExportEnvironment]), @"textExportEnvironment",
                                         @([preferencesController exportTextExportBody]), @"textExportBody",
                                         [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                         nil];
          NSData* data = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData
                           exportOptions:exportOptions
                           compositionConfiguration:[preferencesController compositionConfigurationDocument]
                           uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];

          //now feed the pasteboard
          //[pboard declareTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:nil];
          //LinkBack data
          LatexitEquation* latexitEquation =
            [[LatexitEquation alloc] initWithPDFData:pdfData preamble:preamble
                                         sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                              color:[NSColor blackColor] pointSize:defaultPointSize date:[NSDate date] mode:mode
                                    backgroundColor:nil title:nil];
          HistoryItem* historyItem = [[HistoryItem alloc] initWithEquation:latexitEquation insertIntoManagedObjectContext:nil];
          NSArray* historyItemArray = [NSArray arrayWithObjects:historyItem, nil];
          [historyItem release];
          [latexitEquation release];
          NSData* historyItemData = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
          NSDictionary* linkBackPlist = [NSDictionary linkBackDataWithServerName:[[NSWorkspace sharedWorkspace] applicationName] appData:historyItemData]; 
          //[pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];
          if (linkBackPlist)
            [dummyPboard setObject:linkBackPlist forKey:LinkBackPboardType];

          if ([[PreferencesController sharedController] historySaveServicesResultsEnabled])//we may add the item to the history
            [self addHistoryItemToHistory:historyItem];
          
          //additional data according to the export type (pdf, eps, tiff, jpeg, png...)
          if ([extension isEqualToString:@"pdf"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:nil];
            //[pboard setData:data forType:NSPDFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:(NSString*)kUTTypePDF] owner:nil];
            //[pboard setData:data forType:(NSString*)kUTTypePDF];
            if (pdfData)
            {
              [dummyPboard setObject:pdfData forKey:NSPDFPboardType];
              [dummyPboard setObject:pdfData forKey:(NSString*)kUTTypePDF];
            }//end if (pdfData)
          }//end if ([extension isEqualToString:@"pdf"])
          else if ([extension isEqualToString:@"eps"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSPostScriptPboardType] owner:nil];
            //[pboard setData:data forType:NSPostScriptPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:@"com.adobe.encapsulated-postscript"] owner:nil];
            //[pboard setData:data forType:@"com.adobe.encapsulated-postscript"];
            if (data)
            {
              [dummyPboard setObject:data forKey:NSPostScriptPboardType];
              [dummyPboard setObject:data forKey:@"com.adobe.encapsulated-postscript"];
            }//end if (data)
          }//end if ([extension isEqualToString:@"eps"])
          else if ([extension isEqualToString:@"png"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:(NSString*)kUTTypePNG] owner:nil];
            //[pboard setData:data forType:(NSString*)kUTTypePNG];
            if (data)
              [dummyPboard setObject:data forKey:(NSString*)kUTTypePNG];
          }//end if ([extension isEqualToString:@"png"])
          else if ([extension isEqualToString:@"tiff"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            //[pboard setData:data forType:NSTIFFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:kUTTypeTIFF] owner:nil];
            //[pboard setData:data forType:kUTTypeTIFF];
            if (data)
            {
              [dummyPboard setObject:data forKey:NSTIFFPboardType];
              [dummyPboard setObject:data forKey:(NSString*)kUTTypeTIFF];
            }//end if (data)
          }//end if ([extension isEqualToString:@"tiff"])
          else if ([extension isEqualToString:@"jpeg"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            //[pboard setData:data forType:NSTIFFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:kUTTypeJPEG] owner:nil];
            //[pboard setData:data forType:kUTTypeJPEG];
            if (data)
            {
              [dummyPboard setObject:data forKey:NSTIFFPboardType];
              [dummyPboard setObject:data forKey:(NSString*)kUTTypeJPEG];
            }//end if (data)
          }//end if ([extension isEqualToString:@"jpeg"])
        }//end if (pdfData)
        else//if (!pdfData)
        {
          NSString* message = NSLocalizedString(@"This text is not LaTeX compliant; or perhaps it is a preamble problem ? You can check it in LaTeXiT", @"");
          *error = message;
          [NSApp activateIgnoringOtherApps:YES];
          NSInteger choice = NSRunAlertPanel(NSLocalizedString(@"Error", @""), message, NSLocalizedString(@"Cancel", @""),
                                       NSLocalizedString(@"Open in LaTeXiT", @""), nil);
          if (choice == NSAlertAlternateReturn)
          {
            NSDocumentController* documentController = [NSDocumentController sharedDocumentController];
            //MyDocument* document = [documentController openUntitledDocumentOfType:@"MyDocumentType" display:YES];
            MyDocument* document = (MyDocument*)[documentController makeUntitledDocumentOfType:@"MyDocumentType" error:nil];
            if (document != nil)
            {
              [documentController addDocument:document];
              [document makeWindowControllers];
              [document showWindows];
            }//end if (document != nil)
            [document setSourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]];
            [document setLatexModeRequested:mode];
            [[document windowForSheet] makeFirstResponder:[document preferredFirstResponder]];
            [document latexize:self];
          }//if (![pdfData length])
        }//end if pdfData (LaTeXisation has worked)
      }//end if not RTF
      
      //add dummyPboard to pboard in one command
      NSPasteboard* generalPboard = !putIntoClipBoard ? nil : [NSPasteboard generalPasteboard];
      [pboard declareTypes:[dummyPboard allKeys] owner:nil];
      [generalPboard declareTypes:[dummyPboard allKeys] owner:nil];
      NSEnumerator* enumerator = [dummyPboard keyEnumerator];
      id key = nil;
      while((key = [enumerator nextObject]))
      {
        id value = [dummyPboard objectForKey:key];
        if ([value isKindOfClass:[NSData class]])
        {
          [pboard setData:value forType:key];
          [generalPboard setData:value forType:key];
        }//end if ([value isKindOfClass:[NSData class]])
        else//if (![value isKindOfClass:[NSData class]])
        {
          [pboard setPropertyList:value forType:key];
          [generalPboard setPropertyList:value forType:key];
        }//end if (![value isKindOfClass:[NSData class]])
      }//end for each value
    }//end @synchronized(self)
  }//end if latexisation can be performed
}
//end _serviceLatexisation:userData:mode:putIntoClipBoard:error:

-(void) _serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData putIntoClipBoard:(BOOL)putIntoClipBoard error:(NSString **)error
{
  if (!self->isPdfLaTeXAvailable || !self->isGsAvailable)
  {
    NSString* message = NSLocalizedString(@"LaTeXiT cannot be run properly, please check its configuration", @"");
    *error = message;
    NSRunAlertPanel(NSLocalizedString(@"Error", @""), message, @"OK", nil, nil);
  }
  else
  {
    [pboard types];//it is better to call it once
    @synchronized(self) //one latexisation at a time
    {
      NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
      BOOL useColor     = [userDefaults boolForKey:ServiceRespectsColorKey];
      BOOL useBaseline  = [userDefaults boolForKey:ServiceRespectsBaselineKey];
      BOOL usePointSize = [userDefaults boolForKey:ServiceRespectsPointSizeKey];
      CGFloat pointSizeFactor = [userDefaults floatForKey:ServicePointSizeFactorKey];
      double defaultPointSize = [userDefaults floatForKey:DefaultPointSizeKey];

      //the input must be RTF, so that we can insert images in it      
      //in the case of RTF input, we may deduce size, color, and change baseline
      NSDictionary* documentAttributes = nil;
      NSAttributedString* attrString = [[[NSAttributedString alloc] initWithRTFD:[pboard dataForType:NSRTFDPboardType]
                                                             documentAttributes:&documentAttributes] autorelease];
      attrString = attrString ? attrString : [[[NSAttributedString alloc] initWithRTF:[pboard dataForType:(NSString*)kUTTypeRTFD]
                                                                   documentAttributes:&documentAttributes] autorelease];
      attrString = attrString ? attrString : [[[NSAttributedString alloc] initWithRTF:[pboard dataForType:NSRTFPboardType]
                                                                   documentAttributes:&documentAttributes] autorelease];
      attrString = attrString ? attrString : [[[NSAttributedString alloc] initWithRTF:[pboard dataForType:(NSString*)kUTTypeRTF]
                                                                   documentAttributes:&documentAttributes] autorelease];
      NSMutableAttributedString* mutableAttrString = [[attrString mutableCopy] autorelease];
            
      ServiceRegularExpressionFiltersController* serviceRegularExpressionFiltersController =
        [[PreferencesController sharedController] serviceRegularExpressionFiltersController];
      if (serviceRegularExpressionFiltersController)
        [mutableAttrString setAttributedString:
          [serviceRegularExpressionFiltersController applyFilterToAttributedString:mutableAttrString]];
      
      NSRange remainingRange = mutableAttrString.range;
      NSInteger numberOfFailures = 0;

      //we must find some places where latexisations should be done. We look for "$$..$$", "\[..\]", and "$...$"
      NSArray* delimiters =
        @[
          @[@"$$", @"$$"  , @(LATEX_MODE_DISPLAY)],
          @[@"\\[", @"\\]", @(LATEX_MODE_DISPLAY)],
          @[@"$", @"$"    , @(LATEX_MODE_INLINE)],
          @[@"\\begin{eqnarray}", @"\\end{eqnarray}", @(LATEX_MODE_EQNARRAY)],
          @[@"\\begin{eqnarray*}", @"\\end{eqnarray*}", @(LATEX_MODE_EQNARRAY)],
          @[@"\\begin{align}", @"\\end{align}", @(LATEX_MODE_ALIGN)],
          @[@"\\begin{align*}", @"\\end{align*}", @(LATEX_MODE_ALIGN)]
         ];

      NSMutableArray* errorDocuments = [NSMutableArray array];
      NSUInteger delimiterIndex = 0;
      for(delimiterIndex = 0 ; delimiterIndex < [delimiters count] ; ++delimiterIndex)
      {
        NSArray* delimiter = [delimiters objectAtIndex:delimiterIndex];
        NSString* delimiterLeft  = [delimiter objectAtIndex:0];
        NSString* delimiterRight = [delimiter objectAtIndex:1];
        NSUInteger delimiterLeftLength  = [delimiterLeft  length];
        NSUInteger delimiterRightLength = [delimiterRight length];
        latex_mode_t mode = (latex_mode_t) [[delimiter objectAtIndex:2] integerValue];
      
        BOOL finished = NO;
        while(!finished)
        {
          NSString* string = [mutableAttrString string];
          NSUInteger length = [string length];
          
          NSRange begin = NSMakeRange(NSNotFound, 0);
          BOOL mustFindBegin = YES;
          while(mustFindBegin)
          {
            mustFindBegin = NO;
            begin = [string rangeOfString:delimiterLeft options:0 range:remainingRange];
            //check if it is not a previous delimiter (problem for $$ and $)
            NSUInteger index2 = 0;
            for(index2 = 0 ; !mustFindBegin && (begin.location != NSNotFound) && (index2 < delimiterIndex) ; ++index2)
            {
              NSString* otherDelimiterLeft  = [[delimiters objectAtIndex:index2] objectAtIndex:0];
              NSString* otherDelimiterRight = [[delimiters objectAtIndex:index2] objectAtIndex:1];
              if ([string rangeOfString:otherDelimiterLeft options:0 range:remainingRange].location == begin.location)
              {
                mustFindBegin |= YES;
                remainingRange.location += [otherDelimiterLeft length];
                remainingRange.length   -= [otherDelimiterLeft length];
              }
              else if ([string rangeOfString:otherDelimiterRight options:0 range:remainingRange].location == begin.location)
              {
                mustFindBegin |= YES;
                remainingRange.location += [otherDelimiterRight length];
                remainingRange.length   -= [otherDelimiterRight length];
              }
            }
          }//end while mustFindbegin

          NSRange end = (begin.location == NSNotFound)
                          ? begin
                          : [string rangeOfString:delimiterRight options:0
                                            range:NSMakeRange(begin.location+delimiterLeftLength,
                                                              length-(begin.location+delimiterLeftLength))];
          finished = (end.location == NSNotFound);
          if (end.location != NSNotFound) //if we found a pair of delimiters, let's LaTeXize
          {
            NSRange rangeOfEquation = NSMakeRange(begin.location, end.location-begin.location+delimiterRightLength);
            NSRange rangeOfTextOfEquation = NSMakeRange(rangeOfEquation.location+delimiterLeftLength,
                                                        rangeOfEquation.length-delimiterLeftLength-delimiterRightLength);
            NSDictionary* contextAttributes = [mutableAttrString attributesAtIndex:rangeOfEquation.location effectiveRange:NULL];
            NSFont*  font  = usePointSize ? [contextAttributes objectForKey:NSFontAttributeName] : nil;
            CGFloat pointSize = font ? [font pointSize]*pointSizeFactor : defaultPointSize;
            CGFloat magnification = pointSize;
            NSColor* color = useColor ? [contextAttributes objectForKey:NSForegroundColorAttributeName] : nil;
            if (!color) color = [NSColor colorWithData:[userDefaults objectForKey:DefaultColorKey]];
            CGFloat originalBaseline = (CGFloat)[[[contextAttributes objectForKey:NSBaselineOffsetAttributeName] dynamicCastToClass:[NSNumber class]] doubleValue];
            NSString* body     = [string substringWithRange:rangeOfTextOfEquation];
            NSString* preamble = [[LaTeXProcessor sharedLaTeXProcessor] insertColorInPreamble:[[self preambleServiceAttributedString] string] color:color isColorStyAvailable:[self isColorStyAvailable]];
            
            //perform effective latexisation
            NSData* pdfData = nil;
            NSString* workingDirectory = [[NSWorkspace sharedWorkspace] temporaryDirectory];
            NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-service"];
            NSDictionary* fullEnvironment  = [[LaTeXProcessor sharedLaTeXProcessor] fullEnvironment];

            PreferencesController* preferencesController = [PreferencesController sharedController];
            CGFloat leftMargin   = [self marginsCurrentLeftMargin];
            CGFloat rightMargin  = [self marginsCurrentRightMargin];
            CGFloat bottomMargin = [self marginsCurrentBottomMargin];
            CGFloat topMargin    = [self marginsCurrentTopMargin];
            [[LaTeXProcessor sharedLaTeXProcessor] latexiseWithPreamble:preamble body:body color:color mode:mode magnification:magnification
                               compositionConfiguration:[preferencesController compositionConfigurationDocument]
                               backgroundColor:nil
                                         title:nil
                               leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin
                               additionalFilesPaths:[self additionalFilesPaths] 
                               workingDirectory:workingDirectory fullEnvironment:fullEnvironment uniqueIdentifier:uniqueIdentifier
                               outFullLog:nil outErrors:nil outPdfData:&pdfData];
            //if it has worked, put back data in the attributedString. First, we get rid of the error case
            if (!pdfData)
            {
              ++numberOfFailures;
              remainingRange.location = end.location+delimiterRightLength;
              remainingRange.length = [mutableAttrString length]-remainingRange.location;
              
              //builds a document containing the error
              NSDocumentController* documentController = [NSDocumentController sharedDocumentController];
              //MyDocument* document = [documentController openUntitledDocumentOfType:@"MyDocumentType" display:YES];
              MyDocument* document = (MyDocument*)[documentController makeUntitledDocumentOfType:@"MyDocumentType" error:nil];
              if (document != nil)
              {
                [documentController addDocument:document];
                [document makeWindowControllers];
                [document showWindows];
              }//end if (document != nil)
              [[document windowControllers] makeObjectsPerformSelector:@selector(window)];//calls windowDidLoad
              [document setSourceText:[[[NSAttributedString alloc] initWithString:body] autorelease]];
              [document setLatexModeRequested:mode];
              [document setColor:color];
              [document setMagnification:magnification];
              [errorDocuments addObject:document];
            }//end if !pdfData
            else
            {
              //we will create the image file that will be attached to the rtfd
              NSString* directory          = [[NSWorkspace sharedWorkspace] temporaryDirectory];
              NSString* filePrefix         = [NSString stringWithFormat:@"latexit-%d", 0];
              export_format_t exportFormat = [[PreferencesController sharedController] exportFormatPersistent];
              NSString* extension = nil;
              NSString* uti = nil;
              switch(exportFormat)
              {
                case EXPORT_FORMAT_PDF:
                case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS:
                  extension = @"pdf";
                  uti = (NSString*)kUTTypePDF;
                  break;
                case EXPORT_FORMAT_EPS:
                  extension = @"eps";
                  uti = @"com.adobe.encapsulated-​postscript";
                  break;
                case EXPORT_FORMAT_TIFF:
                  extension = @"tiff";
                  uti = (NSString*)kUTTypeTIFF;
                  break;
                case EXPORT_FORMAT_PNG:
                  extension = @"png";
                  uti = (NSString*)kUTTypePNG;
                  break;
                case EXPORT_FORMAT_JPEG:
                  extension = @"jpeg";
                  uti = (NSString*)kUTTypeJPEG;
                  break;
                case EXPORT_FORMAT_MATHML:
                  extension = @"html";
                  uti = @"public.mathml";
                  break;
                case EXPORT_FORMAT_SVG:
                  extension = @"svg";
                  uti = GetMySVGPboardType();
                  break;
                case EXPORT_FORMAT_TEXT:
                  extension = @"tex";
                  uti = (NSString*)kUTTypeText;
                  break;
                case EXPORT_FORMAT_RTFD:
                  extension = @"rtfd";
                  uti = (NSString*)kUTTypeRTFD;
                  break;
              }//end switch(exportFormat)

              if ([[PreferencesController sharedController] historySaveServicesResultsEnabled])//we may add the item to the history
              {
                LatexitEquation* latexitEquation =
                  [LatexitEquation latexitEquationWithPDFData:pdfData
                     preamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]
                   sourceText:[[[NSAttributedString alloc] initWithString:body] autorelease]
                        color:color pointSize:pointSize date:[NSDate date] mode:mode backgroundColor:nil title:nil];
                [self addEquationToHistory:latexitEquation];
              }

              NSString* attachedFilePath = nil;//[NSString stringWithFormat:@"%@-%d.%@", filePrefix, attachedFileId++, extension];              
              NSFileHandle* fileHandle =
                [[NSFileManager defaultManager] temporaryFileWithTemplate:[NSString stringWithFormat:@"%@-XXXXXXXX", filePrefix]
                                                                extension:extension
                                                              outFilePath:&attachedFilePath workingDirectory:directory];
              NSURL* attachedFileURL = !attachedFilePath ? nil : [NSURL fileURLWithPath:attachedFilePath];
              
              NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                             @([preferencesController exportJpegQualityPercent]), @"jpegQuality",
                                             @([preferencesController exportScalePercent]), @"scaleAsPercent",
                                             @([preferencesController exportIncludeBackgroundColor]), @"exportIncludeBackgroundColor",
                                             @([preferencesController exportTextExportPreamble]), @"textExportPreamble",
                                             @([preferencesController exportTextExportEnvironment]), @"textExportEnvironment",
                                             @([preferencesController exportTextExportBody]), @"textExportBody",
                                             [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                             nil];
              NSData* attachedData = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData
                                       exportOptions:exportOptions
                                       compositionConfiguration:[preferencesController compositionConfigurationDocument]
                                       uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];

              //extracts the baseline of the equation, if possible
              CGFloat newBaseline = originalBaseline;
              if (useBaseline)
                newBaseline -= [[[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES outPdfData:&pdfData] objectForKey:@"baseline"] doubleValue];//[LatexitEquation baselineFromData:pdfData];

              NSMutableAttributedString* mutableAttributedStringWithImage = nil;
              if (NO && isMacOS10_11OrAbove())
              {
                NSImage* image = !pdfData ? nil : [[[NSImage alloc] initWithData:pdfData] autorelease];
                NSTextAttachment* textAttachment = !attachedData ? nil : [[[NSTextAttachment alloc] initWithData:attachedData ofType:uti] autorelease];
                //textAttachment.image = image;
                NSSize imageSize = image.size;
                CGFloat renderingfontSize = pointSize;
                CGFloat renderingEx = [[NSFont systemFontOfSize:renderingfontSize] xHeight];
                CGSize renderingSize = {imageSize.width*renderingEx, imageSize.height*renderingEx};
                if (!imageSize.width*imageSize.height)
                {
                  double aspectRatio = !imageSize.height ? 0. : imageSize.width/imageSize.height;
                  renderingSize = CGSizeMake(aspectRatio*renderingEx, renderingEx);
                }//end if (!imageSize.width*imageSize.height)
                textAttachment.bounds = NSMakeRect(0, newBaseline*renderingEx, renderingSize.width, renderingSize.height);
                mutableAttributedStringWithImage = !textAttachment ? nil : [[[NSAttributedString attributedStringWithAttachment:textAttachment] mutableCopy] autorelease];
              }//end if (isMacOS10_11OrAbove())
              else//if (!isMacOS10_11OrAbove())
              {
                //creates a mutable attributed string containing the image file
                [fileHandle writeData:attachedData];
                [fileHandle closeFile];
                NSFileWrapper*      fileWrapperOfImage        = [[[NSFileWrapper alloc] initWithURL:attachedFileURL options:0 error:nil] autorelease];
                NSTextAttachment*   textAttachmentOfImage     = [[[NSTextAttachment alloc] initWithFileWrapper:fileWrapperOfImage] autorelease];
                NSAttributedString* attributedStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachmentOfImage];
                mutableAttributedStringWithImage =
                  [[[NSMutableAttributedString alloc] initWithAttributedString:attributedStringWithImage] autorelease];
                //changes the baseline of the attachment to align it with the surrounding text
                [mutableAttributedStringWithImage addAttribute:NSBaselineOffsetAttributeName
                                                         value:@(newBaseline)
                                                         range:mutableAttributedStringWithImage.range];
               }//end if (!isMacOS10_11OrAbove())
                                  
              //add a space after the image, to restore the baseline of the surrounding text
              //Gee! It works with TextEdit but not with Pages. That is to say, in Pages, if I put this space, the baseline of
              //the equation is reset. And if do not put this space, the cursor stays in "tuned baseline" mode.
              //However, it works with Nisus Writer Express, so that I think it is a bug in Pages
              const unichar invisibleSpace = 0xFEFF;
              NSString* invisibleSpaceString = [[[NSString alloc] initWithCharacters:&invisibleSpace length:1] autorelease];
              NSMutableAttributedString* spaceWithoutCustomBaseline =
                [[[NSMutableAttributedString alloc] initWithString:invisibleSpaceString] autorelease];
              [spaceWithoutCustomBaseline setAttributes:contextAttributes range:spaceWithoutCustomBaseline.range];
              NSMutableAttributedString* spaceWithCustomBaseline = [[spaceWithoutCustomBaseline mutableCopy] autorelease];
              [spaceWithCustomBaseline addAttribute:NSBaselineOffsetAttributeName value:@(newBaseline) range:spaceWithCustomBaseline.range];
              [mutableAttributedStringWithImage insertAttributedString:spaceWithCustomBaseline atIndex:0];
              [mutableAttributedStringWithImage appendAttributedString:spaceWithCustomBaseline];
              [mutableAttributedStringWithImage appendAttributedString:spaceWithoutCustomBaseline];
              //inserts the image in the global string
              if (mutableAttributedStringWithImage)
                [mutableAttrString replaceCharactersInRange:rangeOfEquation withAttributedString:mutableAttributedStringWithImage];
              
              remainingRange = NSMakeRange(remainingRange.location, [mutableAttrString length]-remainingRange.location);
            }//end if latexisation has worked
          }//end if a pair of $$...$$ was found
        }//end if finished
      }//end for each delimiter
      
      if (numberOfFailures)
      {
        NSString* message =
          (numberOfFailures == 1)
            ? NSLocalizedString(@"%d equation could not be converted because of syntax errors in it. You should "
                                @"also check if it is compatible with the default preamble in use.", @"")
            : NSLocalizedString(@"%d equations could not be converted because of syntax errors in them. You should "
                                @"also check if they are compatible with the default preamble in use.", @"");
        message = [NSString stringWithFormat:message, numberOfFailures];
        *error = message;
        
        [NSApp activateIgnoringOtherApps:YES];
        NSInteger choice = NSRunAlertPanel(NSLocalizedString(@"Error", @""), message, NSLocalizedString(@"Cancel", @""),
                                     NSLocalizedString(@"Open in LaTeXiT", @""), nil);
        if (choice == NSAlertAlternateReturn)
        {
          NSEnumerator* enumerator = [errorDocuments objectEnumerator];
          MyDocument* document = nil;
          while((document = [enumerator nextObject]))
          {
            [document showWindows];
            [[document windowForSheet] makeFirstResponder:[document preferredFirstResponder]];
            [document latexize:self];
          }
        }//end if (choice == NSAlertAlternateReturn)
      }//if there were failures
      
      //Now we must feed the pasteboard
      NSMutableDictionary* dummyPboard = [NSMutableDictionary dictionary];
      NSData* rtfdData = [mutableAttrString RTFDFromRange:mutableAttrString.range
                                       documentAttributes:documentAttributes];
      [dummyPboard setObject:rtfdData forKey:NSRTFDPboardType];
      [dummyPboard setObject:rtfdData forKey:(NSString*)kUTTypeRTFD];

      NSPasteboard* generalPboard = !putIntoClipBoard ? nil : [NSPasteboard generalPasteboard];
      [pboard declareTypes:[dummyPboard allKeys] owner:nil];
      [generalPboard declareTypes:[dummyPboard allKeys] owner:nil];
      NSEnumerator* enumerator = [dummyPboard keyEnumerator];
      id key = nil;
      while((key = [enumerator nextObject]))
      {
        id value = [dummyPboard objectForKey:key];
        if ([value isKindOfClass:[NSData class]])
        {
          [pboard setData:value forType:key];
          [generalPboard setData:value forType:key];
        }//end if ([value isKindOfClass:[NSData class]])
        else//if (![value isKindOfClass:[NSData class]])
        {
          [pboard setPropertyList:value forType:key];
          [generalPboard setPropertyList:value forType:key];
        }//end if (![value isKindOfClass:[NSData class]])
      }//end for each value
    }//end @synchronized(self)
  }//end if latexisation can be performed
}
//end _serviceMultiLatexisation:userData:mode:error:

-(void) _serviceDeLatexisation:(NSPasteboard*)pboard userData:(NSString*)userData error:(NSString**)error
{
  NSString* type = nil;
  if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSPDFPboardType, kUTTypePDF, nil]]))
  {
    NSData* pdfData = [pboard dataForType:type];
    LatexitEquation* latexitEquation = [[LatexitEquation alloc] initWithPDFData:pdfData useDefaults:YES];
    NSMutableAttributedString* source = !latexitEquation ? nil :
      [[[NSMutableAttributedString alloc] initWithAttributedString:[latexitEquation sourceText]] autorelease];
    if (source)
    {
      NSFont* font = [[source fontAttributesInRange:source.range] objectForKey:NSFontAttributeName];
      font = font ? font : [NSFont userFontOfSize:[latexitEquation pointSize]];
      font = [NSFont fontWithName:[font fontName] size:[latexitEquation pointSize]];
      NSDictionary* attributes = 
        [NSDictionary dictionaryWithObjectsAndKeys:
          font, NSFontAttributeName,
          [NSString stringWithFormat:@"%f",  [latexitEquation pointSize]], NSFontSizeAttribute,
          [latexitEquation color], NSForegroundColorAttributeName, nil];
      [source addAttributes:attributes range:source.range];
      [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, @"public.utf8-plain-text",
                                                     NSRTFPboardType, kUTTypeRTF, nil]  owner:nil];
      [pboard setString:[source string] forType:NSStringPboardType];
      [pboard setString:[source string] forType:@"public.utf8-plain-text"];
      NSData* rtfData = [source RTFFromRange:source.range documentAttributes:@{NSDocumentTypeDocumentAttribute:NSRTFTextDocumentType}];
      [pboard setData:rtfData forType:NSRTFPboardType];
      [pboard setData:rtfData forType:(NSString*)kUTTypeRTF];
    }//end if (source)
    [latexitEquation release];
  }//end if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSPDFPboardType, kUTTypePDF, nil]]))
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFDPboardType, kUTTypeRTFD, nil]]))
  {
    NSData* rtfdData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSMutableAttributedString* attributedString =
      [[NSMutableAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    NSUInteger location = 0;
    while(location < [attributedString length])
    {
      NSRange effectiveRange = NSMakeRange(0, 0);
      NSDictionary* attributesForCharacter = [attributedString attributesAtIndex:location effectiveRange:&effectiveRange];
      NSTextAttachment* textAttachment = [attributesForCharacter objectForKey:NSAttachmentAttributeName];
      if (!textAttachment)
        location += effectiveRange.length;
      else
      {
        NSFileWrapper* fileWrapper = [textAttachment fileWrapper];
        NSString* filename = [fileWrapper filename];
        NSString* textAttachmentUTI = ![fileWrapper isRegularFile] ? nil :
          [[NSFileManager defaultManager] UTIFromPath:filename];
        BOOL canBeEquation = (textAttachmentUTI && UTTypeConformsTo((CFStringRef)textAttachmentUTI, CFSTR("com.adobe.pdf"))) ||
                             (!textAttachmentUTI && [[[filename pathExtension] lowercaseString] isEqualToString:@"pdf"]);
        if (!canBeEquation)
          location += effectiveRange.length;
        else//if (canBeEquation)
        {
          NSData* pdfData = [[textAttachment fileWrapper] regularFileContents];
          LatexitEquation* latexitEquation = [[LatexitEquation alloc] initWithPDFData:pdfData useDefaults:YES];
          NSMutableAttributedString* source = !latexitEquation ? nil :
            [[[NSMutableAttributedString alloc] initWithAttributedString:[latexitEquation encapsulatedSource]] autorelease];
          if (!source)
            location += effectiveRange.length;
          else//if (source)
          {
            NSFont* font = [[attributedString fontAttributesInRange:effectiveRange] objectForKey:NSFontAttributeName];
            font = font ? font : [NSFont userFontOfSize:[latexitEquation pointSize]];
            font = [NSFont fontWithName:[font fontName] size:[latexitEquation pointSize]];
            NSDictionary* attributes = 
              [NSDictionary dictionaryWithObjectsAndKeys:
                font, NSFontAttributeName,
                [NSString stringWithFormat:@"%f",  [latexitEquation pointSize]], NSFontSizeAttribute,
                [latexitEquation color], NSForegroundColorAttributeName, nil];
            NSString* currentString = [attributedString string];
            const unichar invisibleSpace = 0xFEFF;
            BOOL hasInvisibleSpaceBefore =
              effectiveRange.location &&
              ([currentString characterAtIndex:effectiveRange.location-1] == invisibleSpace);
            BOOL hasInvisibleSpaceAfter =
              (effectiveRange.location+effectiveRange.length < [currentString length]) &&
              ([currentString characterAtIndex:effectiveRange.location+effectiveRange.length] == invisibleSpace);
            if (hasInvisibleSpaceBefore)
            {
              --location;
              --effectiveRange.location;
              ++effectiveRange.length;
            }//end if (hasInvisibleSpaceBefore)
            if (hasInvisibleSpaceAfter)
              ++effectiveRange.length;
            if (source)
              [attributedString replaceCharactersInRange:effectiveRange withAttributedString:source];
            [attributedString addAttributes:attributes range:NSMakeRange(effectiveRange.location, [source length])];
            location += [source length];
          }//end if (source)
          [latexitEquation release];
        }//end if (canBeEquation)
      }//end if textAttachment
    }//end while ! at the end of the string
    [pboard declareTypes:[NSArray arrayWithObjects:NSRTFDPboardType, kUTTypeRTFD,
                                                   NSRTFPboardType, kUTTypeRTF, nil] owner:nil];
    NSData* outRtfdData = [attributedString RTFDFromRange:attributedString.range
                          documentAttributes:docAttributes];
    [pboard setData:outRtfdData forType:NSRTFDPboardType];
    [pboard setData:outRtfdData forType:(NSString*)kUTTypeRTFD];
    NSData* outRtfData = [attributedString RTFFromRange:attributedString.range
                          documentAttributes:docAttributes];
    [pboard setData:outRtfData forType:NSRTFPboardType];
    [pboard setData:outRtfData forType:(NSString*)kUTTypeRTF];
    [attributedString release];
  }//end if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFDPboardType, kUTTypeRTFD, nil]]))
}
//end _serviceDeLatexisation:userData:error:

#pragma mark extra window controllers

-(AdditionalFilesWindowController*) additionalFilesWindowController
{
  if (!self->additionalFilesWindowController)
    self->additionalFilesWindowController = [[AdditionalFilesWindowController alloc] init];
  return self->additionalFilesWindowController;
}
//end additionalFilesController

-(CompositionConfigurationsWindowController*) compositionConfigurationWindowController
{
  if (!self->compositionConfigurationWindowController)
    self->compositionConfigurationWindowController = [[CompositionConfigurationsWindowController alloc] init];
  return self->compositionConfigurationWindowController;
}
//end compositionConfigurationController

-(DragFilterWindowController*) dragFilterWindowController
{
  if (!self->dragFilterWindowController)
    self->dragFilterWindowController = [[DragFilterWindowController alloc] init];
  return self->dragFilterWindowController;
}
//end dragFilterWindowController

-(EncapsulationsWindowController*) encapsulationsWindowController
{
  if (!self->encapsulationsWindowController)
    self->encapsulationsWindowController = [[EncapsulationsWindowController alloc] init];
  return self->encapsulationsWindowController;
}
//end encapsulationsController

-(HistoryWindowController*) historyWindowController
{
  if (!self->historyWindowController)
    self->historyWindowController = [[HistoryWindowController alloc] init];
  return self->historyWindowController;
}
//end historyController

-(LaTeXPalettesWindowController*) latexPalettesWindowController
{
  if (!self->latexPalettesWindowController)
    self->latexPalettesWindowController = [[LaTeXPalettesWindowController alloc] init];
  return self->latexPalettesWindowController;
}
//end latexPalettesController

-(LibraryWindowController*) libraryWindowController
{
  if (!self->libraryWindowController)
    self->libraryWindowController = [[LibraryWindowController alloc] init];
  return self->libraryWindowController;
}
//end libraryController

-(MarginsWindowController*) marginsWindowController
{
  if (!self->marginsWindowController)
    self->marginsWindowController = [[MarginsWindowController alloc] init];
  return self->marginsWindowController;
}
//end marginController

-(PreferencesWindowController*) preferencesWindowController
{
  if (!self->preferencesWindowController)
    self->preferencesWindowController = [[PreferencesWindowController alloc] init];
  return self->preferencesWindowController;
}
//end preferencesWindowController

//if the marginController is not loaded, just use the user defaults values
-(CGFloat) marginsCurrentTopMargin
{
  CGFloat result = self->marginsWindowController ? [self->marginsWindowController topMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalTopMarginKey];
  return result;
}
//end marginsCurrentTopMargin

-(CGFloat) marginsCurrentBottomMargin
{
  CGFloat result = self->marginsWindowController ? [self->marginsWindowController bottomMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalBottomMarginKey];
  return result;
}
//end marginsCurrentBottomMargin

-(CGFloat) marginsCurrentLeftMargin
{
  CGFloat result = self->marginsWindowController ? [self->marginsWindowController leftMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalLeftMarginKey];
  return result;
}
//end marginsCurrentLeftMargin

-(CGFloat) marginsCurrentRightMargin
{
  CGFloat result = self->marginsWindowController ? [self->marginsWindowController rightMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalRightMarginKey];
  return result;
}
//end marginsCurrentRightMargin

-(NSArray*) additionalFilesPaths
{
  NSArray* result = self->additionalFilesWindowController ? [self->additionalFilesWindowController additionalFilesPaths]
                          : [[NSUserDefaults standardUserDefaults] arrayForKey:AdditionalFilesPathsKey];
  if (!result) result = [NSArray array];
  return result;
}
//end additionalFilesPaths

//when the user has clicked a latexPalettes element, we must put some text in the current document.
//sometimes, we must add symbols, and sometimes, we must encapsulate the selection into a symbol function
//The difference is made using the cell tag
-(IBAction) latexPalettesDoubleClick:(id)sender
{
  PaletteItem* item = [[sender selectedCell] representedObject];
  NSString* string = [item latexCode];
  MyDocument* myDocument = (MyDocument*) [self currentDocument];
  if (string && myDocument)
  {
    NSRange inputSelectedRange = NSMakeRange(0, 0);
    NSRange newSelectedRange = NSMakeRange(NSNotFound, 0);
    if ([item type] == LATEX_ITEM_TYPE_ENVIRONMENT)
      string = [item stringWithTextInserted:[myDocument selectedTextFromRange:&inputSelectedRange] outInterestingRange:&newSelectedRange];
    else if ([item numberOfArguments] || [item argumentToken])
      string = [item stringWithTextInserted:[myDocument selectedTextFromRange:&inputSelectedRange] outInterestingRange:&newSelectedRange];
    if (newSelectedRange.location != NSNotFound)
      newSelectedRange.location += inputSelectedRange.location;
    [myDocument insertText:string newSelectedRange:newSelectedRange];
    [[myDocument windowForSheet] makeKeyAndOrderFront:sender];
  }//end if (string && myDocument)
}
//end latexPalettesDoubleClick:

-(BOOL) installLatexPalette:(NSURL*)paletteURL
{
  BOOL ok = NO;
  NSFileManager* fileManager = [NSFileManager defaultManager];
  //first, checks if it may be a palette
  BOOL fileIsOk = NO;
  BOOL isDirectory  = NO;
  BOOL isDirectory2 = NO;
  BOOL isDirectory3 = NO;
  NSString* palettePath= [paletteURL path];
  if ([fileManager fileExistsAtPath:palettePath isDirectory:&isDirectory] && isDirectory &&
      [fileManager fileExistsAtPath:[palettePath stringByAppendingPathComponent:@"Info.plist"] isDirectory:&isDirectory2] && !isDirectory2 &&
      [fileManager fileExistsAtPath:[palettePath stringByAppendingPathComponent:@"Resources"] isDirectory:&isDirectory3] && isDirectory3)
    fileIsOk = YES;
  if (!fileIsOk)
    NSRunAlertPanel(NSLocalizedString(@"Palette installation", @""),
                    NSLocalizedString(@"It does not appear to be a valid Latex palette package", @""),
                    NSLocalizedString(@"OK", @""), nil, nil);
  else
  {
    NSArray* libraryPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask , YES);
    libraryPaths = [libraryPaths count] ? [libraryPaths subarrayWithRange:NSMakeRange(0, 1)] : nil;
    NSArray* palettesFolderPathComponents =
      libraryPaths ? [libraryPaths arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"Application Support", [[NSWorkspace sharedWorkspace] applicationName], @"Palettes", nil]] : nil;
    NSString* palettesFolderPath = [NSString pathWithComponents:palettesFolderPathComponents];
    if (palettesFolderPath)
    {
      NSString* localizedPalettesFolderPath = [[NSFileManager defaultManager] localizedPath:palettesFolderPath];
      NSInteger choice = NSRunAlertPanel(
        [NSString stringWithFormat:NSLocalizedString(@"Do you want to install the palette %@ ?", @""),
                                   [palettePath lastPathComponent]],
        [NSString stringWithFormat:NSLocalizedString(@"This palette will be installed into \n%@", @""),
                                   localizedPalettesFolderPath],
        NSLocalizedString(@"Install palette", @""),
        NSLocalizedString(@"Cancel", @""), nil);
      if (choice == NSAlertDefaultReturn)
      {
        BOOL shouldInstall = [[NSFileManager defaultManager] createDirectoryAtPath:palettesFolderPath withIntermediateDirectories:YES attributes:nil error:0];
        if (!shouldInstall)
          NSRunAlertPanel(NSLocalizedString(@"Could not create path", @""),
                          [NSString stringWithFormat:NSLocalizedString(@"The path %@ could not be created to install a palette in it", @""),
                                                     palettesFolderPath],
                          NSLocalizedString(@"OK", @""), nil, nil);
                          
        NSString* destinationPath = [palettesFolderPath stringByAppendingPathComponent:[palettePath lastPathComponent]];
        BOOL alreadyExists = [fileManager fileExistsAtPath:destinationPath];
        BOOL overwrite = !alreadyExists;
        if (alreadyExists)
        {
          choice = NSRunAlertPanel(
            [NSString stringWithFormat:NSLocalizedString(@"The palette %@ already exists, do you want to replace it ?", @""), [palettePath lastPathComponent]],
            [NSString stringWithFormat:NSLocalizedString(@"A file or folder with the same name already exists in %@. Replacing it will overwrite its current contents.", @""),
                                       palettesFolderPath],
             NSLocalizedString(@"Replace", @""),
             NSLocalizedString(@"Cancel", @""), nil);
          overwrite |= (choice == NSAlertDefaultReturn);
        }//end if overwrite palette
        
        if (overwrite)
        {
          [fileManager removeItemAtPath:destinationPath error:0];
          BOOL success = [fileManager copyItemAtPath:palettePath toPath:destinationPath error:0];
          if (!success)
            NSRunAlertPanel(NSLocalizedString(@"Installation failed", @""),
                            [NSString stringWithFormat:NSLocalizedString(@"%@ could not be installed as %@", @""),
                                                                         [palettePath lastPathComponent], destinationPath],
                            NSLocalizedString(@"OK", @""), nil, nil);
          ok = success;
        }//end if overwrite
      }//end if install palette
    }//end if palettesFolderPath
  }//end if ok to be a palette
  return ok;
}
//end installLatexPalette:

@end
