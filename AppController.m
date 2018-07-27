//  AppController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.

//The AppController is a singleton, a unique instance that acts as a bridge between the menu and the documents.
//It is also responsible for shared operations (like utilities : finding a program)
//It is also a bridge for the application service : it creates a dummy, invisible document that will perform
//the latexisation
//It is also the LinkBack server

#import "AppController.h"

#import "AdditionalFilesWindowController.h"
#import "CompositionConfigurationsController.h"
#import "CompositionConfigurationsWindowController.h"
#import "DragFilterWindowController.h"
#import "EncapsulationsWindowController.h"
#import "HistoryController.h"
#import "HistoryWindowController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "HistoryView.h"
#import "LatexitEquation.h"
#import "LaTeXPalettesWindowController.h"
#import "LaTeXProcessor.h"
#import "LibraryWindowController.h"
#import "LibraryManager.h"
#import "LineCountTextView.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSAttributedStringExtended.h"
#import "NSColorExtended.h"
#import "NSDictionaryCompositionConfiguration.h"
#import "NSDictionaryExtended.h"
#import "NSFileManagerExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSMenuExtended.h"
#import "NSStringExtended.h"
#import "NSUserDefaultsControllerExtended.h"
#import "NSWorkspaceExtended.h"
#import "MarginsWindowController.h"
#import "PaletteItem.h"
#import "PreferencesController.h"
#import "PreferencesControllerMigration.h"
#import "PreferencesWindowController.h"
#import "Semaphore.h"
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
-(void) _serviceLatexisation:(NSPasteboard*)pboard userData:(NSString*)userData mode:(latex_mode_t)mode error:(NSString**)error;
-(void) _serviceMultiLatexisation:(NSPasteboard*)pboard userData:(NSString*)userData error:(NSString**)error;
-(void) _serviceDeLatexisation:(NSPasteboard*)pboard userData:(NSString*)userData error:(NSString**)error;

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

-(unsigned) retainCount
{
  return UINT_MAX;  //denotes an object that cannot be released
}
//end retainCount

-(void) release
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
    self->linkbackLinks = [[NSMutableSet alloc] init];
    [self _setEnvironment:[[LaTeXProcessor sharedLaTeXProcessor] extraEnvironment]];//performs a setenv()

    [self beginCheckUpdates];
    Semaphore* configurationSemaphore = [[Semaphore alloc] initWithValue:7];
    NSDictionary* configuration = nil;
    configuration = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:NO], @"checkOnlyIfNecessary",
      [NSNumber numberWithBool:YES], @"allowFindOnFailure",
      configurationSemaphore, @"semaphore",
      nil];
    [PreferencesController sharedController];//create out of thread
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                                                 @"pdflatex", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isPdfLaTeXAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationXeLatexPathKey, @"path",
                                                                 @"xelatex", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isXeLaTeXAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                                                 @"latex", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isLaTeXAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                                                 @"dvipdf", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isDviPdfAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                                                 @"gs", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isGsAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                                                 @"ps2pdf", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isPsToPdfAvailable], @"monitor", nil]];
    [NSApplication detachDrawingThread:@selector(_checkColorStyWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingObjectsAndKeys:@"color.sty", @"path",
                                                                 [NSValue valueWithPointer:&self->isColorStyAvailable], @"monitor", nil]];
    [configurationSemaphore Z];
    [configurationSemaphore release];
    configurationSemaphore = nil;

    configuration = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSNumber numberWithBool:YES], @"checkOnlyIfNecessary",
      [NSNumber numberWithBool:YES], @"allowUIAlertOnFailure",
      [NSNumber numberWithBool:YES], @"allowUIFindOnFailure",
      nil];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPdfLatexPathKey, @"path",
                                                                 @"pdflatex", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isPdfLaTeXAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationXeLatexPathKey, @"path",
                                                                 @"xelatex", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isXeLaTeXAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationLatexPathKey, @"path",
                                                                  @"latex", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isLaTeXAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationDviPdfPathKey, @"path",
                                                                  @"dvipdf", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isDviPdfAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationGsPathKey, @"path",
                                                                  @"gs", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isGsAvailable], @"monitor", nil]];
    [self _checkPathWithConfiguration:[configuration dictionaryByAddingObjectsAndKeys:CompositionConfigurationPsToPdfPathKey, @"path",
                                                                  @"ps2pdf", @"executableName",
                                                                 [NSValue valueWithPointer:&self->isPsToPdfAvailable], @"monitor", nil]];
    [self _checkColorStyWithConfiguration:configuration];

    //export to EPS needs ghostscript to be available
    PreferencesController* preferencesController = [PreferencesController sharedController];
    export_format_t exportFormat = [preferencesController exportFormatPersistent];
    if (exportFormat == EXPORT_FORMAT_EPS && !self->isGsAvailable)
      [preferencesController setExportFormatPersistent:EXPORT_FORMAT_PDF];
    if (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS && (!self->isGsAvailable || !self->isPsToPdfAvailable))
      [preferencesController setExportFormatPersistent:EXPORT_FORMAT_PDF];
    [self endCheckUpdates];

    CompositionConfigurationsController* compositionConfigurationsController = [[PreferencesController sharedController] compositionConfigurationsController];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationPdfLatexPathKey] options:0 context:nil];
    [compositionConfigurationsController addObserver:self
      forKeyPath:[@"selection." stringByAppendingString:CompositionConfigurationXeLatexPathKey] options:0 context:nil];
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
  [self->linkbackLinks release];
  [self->additionalFilesWindowController release];
  [self->compositionConfigurationWindowController release];
  [self->encapsulationsWindowController release];
  [self->marginsWindowController release];
  [self->latexPalettesWindowController release];
  [self->libraryWindowController release];
  [self->historyWindowController release];
  [self->preferencesWindowController release];
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
  [editCopyImageAsMenu addItemWithTitle:NSLocalizedString(@"Default Format", @"Default Format") target:self action:@selector(copyAs:)
                         keyEquivalent:@"c" keyEquivalentModifierMask:NSCommandKeyMask|NSAlternateKeyMask tag:-1];
  [editCopyImageAsMenu addItem:[NSMenuItem separatorItem]];
  [editCopyImageAsMenu addItemWithTitle:@"PDF" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(int)EXPORT_FORMAT_PDF];
  [editCopyImageAsMenu addItemWithTitle:NSLocalizedString(@"PDF with outlined fonts", @"PDF with outlined fonts")
                                 target:self action:@selector(copyAs:)
                          keyEquivalent:@"c" keyEquivalentModifierMask:NSCommandKeyMask|NSShiftKeyMask|NSAlternateKeyMask
                                    tag:(int)EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS];
  [editCopyImageAsMenu addItemWithTitle:@"EPS" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(int)EXPORT_FORMAT_EPS];
  [editCopyImageAsMenu addItemWithTitle:@"TIFF" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(int)EXPORT_FORMAT_TIFF];
  [editCopyImageAsMenu addItemWithTitle:@"PNG" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(int)EXPORT_FORMAT_PNG];
  [editCopyImageAsMenu addItemWithTitle:@"JPEG" target:self action:@selector(copyAs:)
                          keyEquivalent:@"" keyEquivalentModifierMask:0 tag:(int)EXPORT_FORMAT_JPEG];
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
    [NSDictionary dictionaryWithObjectsAndKeys:nil],
    [@"selection." stringByAppendingString:CompositionConfigurationCompositionModeKey],
    nil];
  NSDictionary* configuration = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithBool:YES], @"checkOnlyIfNecessary",
    [NSNumber numberWithBool:YES], @"updateGUIfromSystemAvailabilities",
    nil];
  if ([[dict allKeys] containsObject:keyPath])
  {
    [NSApplication detachDrawingThread:@selector(_checkPathWithConfiguration:) toTarget:self
      withObject:[configuration dictionaryByAddingDictionary:[dict objectForKey:keyPath]]];
  }
}
//end observeValueForKeyPath:ofObject:change:context:

#pragma mark delegate

-(BOOL) applicationShouldOpenUntitledFile:(NSApplication*)sender
{
  return YES;
}
//end applicationShouldOpenUntitledFile:

-(BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename
{
  BOOL ok = NO;
  NSString* type = [[filename pathExtension] lowercaseString];
  if ([type isEqualTo:@"latexpalette"])
  {
    ok = [self installLatexPalette:filename];
    if (ok)
      [self->latexPalettesWindowController reloadPalettes];
    ok = YES;
  }
  else if ([type isEqualTo:@"latexlib"] || [type isEqualTo:@"library"] || [type isEqualTo:@"latexhist"] || [type isEqualTo:@"plist"])
  {
    NSString* title =
      [NSString stringWithFormat:NSLocalizedString(@"Do you want to load the library <%@> ?", @"Do you want to load the library <%@> ?"),
                                 [[filename pathComponents] lastObject]];
    NSAlert* alert = [NSAlert alertWithMessageText:title
                                     defaultButton:NSLocalizedString(@"Add to the library", @"Add to the library")
                                   alternateButton:NSLocalizedString(@"Cancel", @"Cancel")
                                       otherButton:NSLocalizedString(@"Replace the library", @"Replace the library")
                         informativeTextWithFormat:NSLocalizedString(@"If you choose <Replace the library>, the current library will be lost", @"If you choose <Replace the library>, the current library will be lost")];
    int confirm = [alert runModal];
    if (confirm == NSAlertDefaultReturn)
      ok = [[LibraryManager sharedManager] loadFrom:filename option:LIBRARY_IMPORT_MERGE parent:nil];
    else if (confirm == NSAlertOtherReturn)
      ok = [[LibraryManager sharedManager] loadFrom:filename option:LIBRARY_IMPORT_OVERWRITE parent:nil];
    else
      ok = YES;
  }
  else //latex document
  {
    MyDocument* document = (MyDocument*)[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:filename display:YES];
    ok = (document != nil);
  }
  return ok;
}
//end application:openFile:

//when the app is launched, the first document appears, then a dialog box can indicate if pdflatex and gs
//have been found or not. Then, the user has the ability to manually find them
//as delegate, no need to register for a notification
-(void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
  NSString* latexitHelperFilePath = [[NSBundle mainBundle] pathForResource:@"LaTeXiT Helper" ofType:@"app"];
  CFURLRef  latexitHelperURL = CFURLCreateWithFileSystemPath(0, (CFStringRef)latexitHelperFilePath, kCFURLPOSIXPathStyle, FALSE);
  OSStatus status = LSRegisterURL(latexitHelperURL, true);
  if (status != noErr)
    DebugLog(0, @"LSRegisterURL : %d", status);
  [[NSWorkspace sharedWorkspace] launchApplication:latexitHelperFilePath];//because Keynote won't find it otherwise

  if (latexitHelperURL) CFRelease(latexitHelperURL);
  [LinkBack publishServerWithName:[[NSWorkspace sharedWorkspace] applicationName] delegate:self];

  if (self->isGsAvailable && (self->isPdfLaTeXAvailable || self->isLaTeXAvailable || self->isXeLaTeXAvailable) && !self->isColorStyAvailable)
    NSRunInformationalAlertPanel(NSLocalizedString(@"color.sty seems to be unavailable", @"color.sty seems to be unavailable"),
                                 NSLocalizedString(@"Without the color.sty package, you won't be able to change the font color",
                                                   @"Without the color.sty package, you won't be able to change the font color"),
                                 @"OK", nil, nil);

  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSDictionary* compositionConfiguration = [preferencesController compositionConfigurationDocument];
  if (self->isPdfLaTeXAvailable)
    [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:
      [[compositionConfiguration compositionConfigurationProgramPathPdfLaTeX] stringByDeletingLastPathComponent]];
  if (self->isXeLaTeXAvailable)
    [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:
      [[compositionConfiguration compositionConfigurationProgramPathXeLaTeX] stringByDeletingLastPathComponent]];
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
    [fileManager copyPath:oldPath toPath:newPath handler:nil];

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

  if ([self->sparkleUpdater automaticallyChecksForUpdates])
    [self->sparkleUpdater checkForUpdatesInBackground];
}
//end applicationDidFinishLaunching:

-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  [LinkBack retractServerWithName:[[NSWorkspace sharedWorkspace] applicationName]];
  
  [[NSWorkspace sharedWorkspace] closeApplicationWithBundleIdentifier:@"fr.club.ktd.LaTeXiT"];//LaTeXiT Helper
  
  //close all linkback links
  NSArray* allLinkBackLinks = [self->linkbackLinks allObjects];
  NSEnumerator* enumerator = [allLinkBackLinks objectEnumerator];
  LinkBack* link = nil;
  while((link = [enumerator nextObject]))
    [self closeLinkBackLink:link];

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
            [NSArray arrayWithObjects:NSPDFPboardType,  @"com.adobe.pdf",
                                      NSRTFDPboardType, @"com.apple.flat-rtfd",
                                      NSStringPboardType, @"public.utf8-plain-text", nil]] != nil);
    if (![pasteboard availableTypeFromArray:
           [NSArray arrayWithObjects:NSPDFPboardType, @"com.adobe.pdf", NSStringPboardType, @"public.utf8-plain-text", nil]])//RTFD
    {
      NSData* rtfdData = [pasteboard dataForType:NSRTFDPboardType];
      if (!rtfdData) rtfdData = [pasteboard dataForType:@"com.apple.flat-rtfd"];
      NSDictionary* docAttributes = nil;
      NSAttributedString* attributedString = [[NSAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
      NSDictionary* pdfAttachments = [attributedString attachmentsOfType:@"pdf" docAttributes:docAttributes];
      NSData* data = [pdfAttachments count] ? [[[pdfAttachments objectEnumerator] nextObject] regularFileContents] : nil;
      [attributedString release];
      ok = (data != nil);
    }
  }
  else if ([sender action] == @selector(copyAs:))
  {
    if ([sender tag] == -1)//default
    {
      export_format_t defaultExportFormat = [[PreferencesController sharedController] exportFormatCurrentSession];
      [sender setTitle:[NSString stringWithFormat:@"%@ (%@)",
        NSLocalizedString(@"Default Format", @"Default Format"),
        [[AppController appController] nameOfType:defaultExportFormat]]];
    }
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [myDocument hasImage];
    if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      ok &= isGsAvailable && isPsToPdfAvailable;
    if ([sender tag] == -1)//default
    {
      export_format_t exportFormat = (export_format_t)[[NSUserDefaults standardUserDefaults] integerForKey:DragExportTypeKey];
      [sender setTitle:[NSString stringWithFormat:@"%@ (%@)",
        NSLocalizedString(@"Default Format", @"Default Format"),
        [self nameOfType:exportFormat]]];
    }
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
    latex_mode_t latexMode = [myDocument latexMode];
    #ifdef MIGRATE_ALIGN
    if ([sender tag] == 1)
    {
      [sender setTitle:@"Align"];
      [sender setState:(myDocument && (latexMode == LATEX_MODE_ALIGN)) ? NSOnState : NSOffState];
    }
    #else
    if ([sender tag] == 1)
    {
      [sender setTitle:@"Eqnarray"];
      [sender setState:(myDocument && (latexMode == LATEX_MODE_EQNARRAY)) ? NSOnState : NSOffState];
    }
    #endif
    else if ([sender tag] == 2)
      [sender setState:(myDocument && (latexMode == LATEX_MODE_DISPLAY)) ? NSOnState : NSOffState];
    else if ([sender tag] == 3)
      [sender setState:(myDocument && (latexMode == LATEX_MODE_INLINE)) ? NSOnState : NSOffState];
    else if ([sender tag] == 4)
      [sender setState:(myDocument && (latexMode == LATEX_MODE_TEXT)) ? NSOnState : NSOffState];
  }
  else if ([sender action] == @selector(makeLatex:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    [sender setTitle:((myDocument != nil) && [myDocument isBusy]) ? NSLocalizedString(@"Stop", @"Stop") :
                     NSLocalizedString(@"LaTeX it!", @"LaTeX it!")];
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
  else if ([sender action] == @selector(showOrHidePreamble:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    BOOL isPreambleVisible = (myDocument && [myDocument isPreambleVisible]);
    ok = (myDocument != nil) && ![myDocument isBusy] && !([myDocument documentStyle] == DOCUMENT_STYLE_MINI);
    if (isPreambleVisible)
      [sender setTitle:NSLocalizedString(@"Hide preamble", @"Hide preamble")];
    else
      [sender setTitle:NSLocalizedString(@"Show preamble", @"Show preamble")];
  }
  else if ([sender action] == @selector(showOrHideHistory:))
  {
    BOOL isHistoryVisible = [[self->historyWindowController window] isVisible];
    if (isHistoryVisible)
      [sender setTitle:NSLocalizedString(@"Hide History", @"Hide History")];
    else
      [sender setTitle:NSLocalizedString(@"Show History", @"Show History")];
  }
  else if ([sender action] == @selector(historyRemoveHistoryEntries:))
  {
    ok = [[self->historyWindowController window] isVisible] && [self->historyWindowController canRemoveEntries];
  }
  else if ([sender action] == @selector(historyClearHistory:))
  {
    ok = ([[[[self->historyWindowController historyView] historyItemsController] arrangedObjects] count] > 0);
  }
  else if ([sender action] == @selector(historyChangeLock:))
  {
    [sender setTitle:[[HistoryManager sharedManager] isLocked] ?
                    NSLocalizedString(@"Unlock", @"Unlock") : NSLocalizedString(@"Lock", @"Lock")];
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
  else if ([sender action] == @selector(showOrHideLibrary:))
  {
    BOOL isLibraryVisible = [[self->libraryWindowController window] isVisible];
    if (isLibraryVisible)
      [sender setTitle:NSLocalizedString(@"Hide Library", @"Hide Library")];
    else
      [sender setTitle:NSLocalizedString(@"Show Library", @"Show Library")];
  }
  else if ([sender action] == @selector(libraryNewFolder:))
  {
    ok = [[self->libraryWindowController window] isVisible];
  }
  else if ([sender action] == @selector(libraryImportCurrent:))
  {
    MyDocument* document = (MyDocument*) [self currentDocument];
    ok = [[self->libraryWindowController window] isVisible] && document && [document hasImage];
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
      [sender setTitle:NSLocalizedString(@"Enlarge the text area", @"Enlarge the text area")];
    else
      [sender setTitle:NSLocalizedString(@"Reduce the text area", @"Reduce the text area")];
  }
  else if ([sender action] == @selector(switchMiniWindow:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    BOOL isMini = myDocument && ([myDocument documentStyle] == DOCUMENT_STYLE_MINI);
    ok = (myDocument != nil);
    if (isMini)
      [sender setTitle:NSLocalizedString(@"Switch to normal window", @"Switch to normal window")];
    else
      [sender setTitle:NSLocalizedString(@"Switch to mini-window", @"Switch to mini-window")];
  }
  return ok;
}
//end validateMenuItem:

-(IBAction) displaySponsors:(id)sender
{
  [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://pierre.chachatelier.fr/programmation/latexit-sponsors.php"]];
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

-(void) showPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier//showPreferencesPane + select one pane
{
  [self showPreferencesPane:self];
  [[self preferencesWindowController] selectPreferencesPaneWithItemIdentifier:itemIdentifier];
}
//end showPreferencesPaneWithItemIdentifier:

-(IBAction) newFromClipboard:(id)sender
{
  NSColor* color = nil;
  NSData* data = nil;
  NSString* filename = NSLocalizedString(@"clipboard", @"clipboard");
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSPDFPboardType]])
  {
    filename = [filename stringByAppendingPathExtension:@"pdf"];
    data = [pasteboard dataForType:NSPDFPboardType];
  }
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:@"com.adobe.pdf"]])
  {
    filename = [filename stringByAppendingPathExtension:@"pdf"];
    data = [pasteboard dataForType:@"com.adobe.pdf"];
  }
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
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:@"com.apple.flat-rtfd"]])
  {
    filename = [filename stringByAppendingPathExtension:@"pdf"];
    NSData* rtfdData = [pasteboard dataForType:@"com.apple.flat-rtfd"];
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
      newFileName = [NSString stringWithFormat:@"%@-%u.%@", filePrefix, i++, extension];
      newFilePath = [folderPath stringByAppendingPathComponent:newFileName];
    } 
    filepath = newFilePath;
    [fileManager registerTemporaryPath:filepath];
  }//end if (filename)

  BOOL ok = (data && filepath) ? [data writeToFile:filepath atomically:YES] : NO;
  if (ok)
  {
    NSError* error = nil;
    MyDocument* document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:filepath] display:NO error:&error];
    ok = (error == nil) && (document != nil);
    if (!ok)
      [document close];
    else
    {
      [document makeWindowControllers];
      [[document windowControllers] makeObjectsPerformSelector:@selector(window)];//force loading nib file
      if (color) [document setColor:color];
      [document showWindows];
    }
  }
}
//end newFromClipboard:

-(IBAction) openFile:(id)sender
{
  if (![self->openFileTypePopUp numberOfItems])
  {
    [self->openFileTypePopUp addItemsWithTitles:[NSArray arrayWithObjects:
      NSLocalizedString(@"PDF Equation", @"PDF Equation"),
      NSLocalizedString(@"Text file", @"Text file"),
      NSLocalizedString(@"LaTeXiT library", @"LaTeXiT library"),
      NSLocalizedString(@"LaTeX Equation Editor library", @"LaTeX Equation Editor library"),
      NSLocalizedString(@"LaTeXiT history", @"LaTeXiT history"),
      NSLocalizedString(@"LaTeXiT LaTeX Palette", @"LaTeXiT  LaTeX Palette"), nil]];
    [self->openFileTypePopUp selectItemAtIndex:0];
  }
  self->openFileTypeOpenPanel = [NSOpenPanel openPanel];
  [self changeOpenFileType:self->openFileTypePopUp];
  [self->openFileTypeOpenPanel setAllowsMultipleSelection:NO];
  [self->openFileTypeOpenPanel setCanChooseDirectories:NO];
  [self->openFileTypeOpenPanel setCanChooseFiles:YES];
  [self->openFileTypeOpenPanel setCanCreateDirectories:NO];
  [self->openFileTypeOpenPanel setResolvesAliases:YES];
  [self->openFileTypeOpenPanel setAccessoryView:self->openFileTypeView];
  [self->openFileTypeOpenPanel setDelegate:self];//panel:shouldShowFilename:
  int result = [self->openFileTypeOpenPanel runModalForDirectory:nil file:nil types:nil];
  if (result == NSOKButton)
  {
    NSString* filePath = [[self->openFileTypeOpenPanel filenames] lastObject];
    [self application:NSApp openFile:filePath];
  }
  self->openFileTypeOpenPanel = nil;
}
//end openFile:

-(IBAction) changeOpenFileType:(id)sender
{
  if (self->openFileTypeOpenPanel && (sender == self->openFileTypePopUp))
  {
    int selectedIndex = [self->openFileTypePopUp indexOfSelectedItem];
    if (selectedIndex == 0)
      [self->openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"com.adobe.pdf", nil]];
    else if (selectedIndex == 1)
      [self->openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"public.text", nil]];
    else if (selectedIndex == 2)
      [self->openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"latexlib", nil]];
    else if (selectedIndex == 3)
      [self->openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"library", nil]];
    else if (selectedIndex == 4)
      [self->openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"latexhist", nil]];
    else if (selectedIndex == 5)
      [self->openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"latexpalette", nil]];
    else
      [self->openFileTypeOpenPanel setAllowedFileTypes:nil];
    [self->openFileTypeOpenPanel validateVisibleColumns];
  }
}
//end changeOpenFileType:

-(BOOL) panel:(id)sender shouldShowFilename:(NSString *)filename
{
  BOOL result = YES;
  if (sender == self->openFileTypeOpenPanel)
  {
    NSArray* allowedFileTypes = [self->openFileTypeOpenPanel allowedFileTypes];
    BOOL isDirectory = NO;
    result = ([[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory &&
              ![[NSWorkspace sharedWorkspace] isFilePackageAtPath:filename]) ||
              [allowedFileTypes containsObject:[filename pathExtension]];
    NSEnumerator* enumerator = [allowedFileTypes objectEnumerator];
    NSString*     uti = nil;
    if (!result)
    {
      FSRef fsRefToItem;
      FSPathMakeRef((const UInt8 *)[filename fileSystemRepresentation], &fsRefToItem, NULL );
      CFTypeRef itemUTI = NULL;
      LSCopyItemAttribute( &fsRefToItem, kLSRolesAll, kLSItemContentType, &itemUTI );
      while(!result && ((uti = [enumerator nextObject])))
        result |= UTTypeConformsTo((CFStringRef)itemUTI, (CFStringRef)uti);
    }
  }
  return result;
}
//end panel:shouldShowFilename:

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
      #ifdef MIGRATE_ALIGN
      case 1 : mode = LATEX_MODE_ALIGN; break;
      #else
      case 1 : mode = LATEX_MODE_EQNARRAY; break;
      #endif
      case 2 : mode = LATEX_MODE_DISPLAY; break;
      case 3 : mode = LATEX_MODE_INLINE; break;
      case 4 : mode = LATEX_MODE_TEXT; break;
      default: mode = LATEX_MODE_TEXT; break;
    }
    [document setLatexMode:mode];
  }
}
//end makeLatexAndExport:

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
    [[document lowerBoxLatexizeButton] performClick:self];
}
//end makeLatex:

-(IBAction) displayLog:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document displayLastLog:sender];
}
//end displayLog:

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
//end librarySaveAs:

-(IBAction) showOrHideHistory:(id)sender
{
  NSWindowController* controller = [self historyWindowController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideHistory:

-(IBAction) libraryImportCurrent:(id)sender //creates a library item with the current document state
{
  [[self libraryWindowController] importCurrent:sender];
}
//end libraryImportCurrent:

-(IBAction) libraryNewFolder:(id)sender     //creates a folder
{
  [[self libraryWindowController] newFolder:sender];
}
//end libraryNewFolder:

-(IBAction) libraryRemoveSelectedItems:(id)sender    //removes some items
{
  [[self libraryWindowController] removeSelectedItems:sender];
}
//end libraryRemoveSelectedItems:

-(IBAction) libraryRenameItem:(id)sender    //rename some items
{
  [[self libraryWindowController] renameItem:sender];
}
//end libraryRenameItem:

-(IBAction) libraryRefreshItems:(id)sender   //refresh an item
{
  [[self libraryWindowController] refreshItems:sender];
}
//end libraryRefreshItems:

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
    [NSMutableString stringWithString:NSLocalizedString(@"http://pierre.chachatelier.fr/programmation/latexit_en.php",
                                                        @"http://pierre.chachatelier.fr/programmation/latexit_en.php")];
  if ([sender respondsToSelector:@selector(tag)] && ([sender tag] == 1))
    [urlString appendString:@"#donation"];
  NSURL* webSiteURL = [NSURL URLWithString:urlString];

  BOOL ok = [[NSWorkspace sharedWorkspace] openURL:webSiteURL];
  if (!ok)
  {
    NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                   [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to reach %@.\n You should check your network.",
                                                                @"An error occured while trying to reach %@.\n You should check your network."),
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
  NSString* string = [readmeTextView string];
  if (!string || ![string length])
  {
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* file = [mainBundle pathForResource:NSLocalizedString(@"Read Me", @"Read Me") ofType:@"rtfd"];
    ok = (file != nil);
    if (ok)
      [readmeTextView readRTFDFromFile:file];
  }
  if (ok)
  {
    if (![readmeWindow isVisible])
      [readmeWindow center];
    [readmeWindow makeKeyAndOrderFront:self];
  }
}
//end showHelp:

-(void) showHelp:(id)sender section:(NSString*)section
{
  [self showHelp:sender];
  [readmeTextView scrollRangeToVisible:[[readmeTextView string] rangeOfString:section]];
}
//end showHelp:section:

#pragma mark private engine helpers

-(NSString*) nameOfType:(export_format_t)format
{
  NSString* result = nil;
  switch(format)
  {
    case EXPORT_FORMAT_PDF : result = @"PDF";   break;
    case EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS : result = NSLocalizedString(@"PDF with outlined fonts", @"PDF with outlined fonts"); break;
    case EXPORT_FORMAT_EPS : result = @"EPS";   break;
    case EXPORT_FORMAT_TIFF : result = @"TIFF"; break;
    case EXPORT_FORMAT_PNG : result = @"PNG";   break;
    case EXPORT_FORMAT_JPEG : result = @"JPEG"; break;
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
  NSString* path = [cachePaths objectForKey:programName];
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
      [cachePaths setObject:path forKey:programName];
  }//end if (!path && prefixes)
  return path;  
}
//end _findUnixProgram:inPrefixes:

//looks for a programName in the environment.
-(NSString*) findUnixProgram:(NSString*)programName tryPrefixes:(NSArray*)prefixes environment:(NSDictionary*)environment useLoginShell:(BOOL)useLoginShell
{
  //first, it may be simply found in the common, usual, path
  NSString* path = [cachePaths objectForKey:programName];
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
      [cachePaths setObject:path forKey:programName];
  }//end if (!path)
  return path;
}
//end _findUnixProgram:tryPrefixes:environment

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
  return isGsAvailable;
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

//try to find gs program, searching by its name
-(void) _findPathWithConfiguration:(id)configuration
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSString*      pathKey        = [configuration objectForKey:@"path"];
  NSString*      executableName = [configuration objectForKey:@"executableName"];
  NSFileManager* fileManager    = [NSFileManager defaultManager];
  NSString*      proposedPath   = nil;
  BOOL           useLoginShell  = NO;
  @synchronized(preferencesController){
    proposedPath  = [[preferencesController compositionConfigurationDocument] objectForKey:pathKey];
    useLoginShell = [[[preferencesController compositionConfigurationDocument] objectForKey:CompositionConfigurationUseLoginShellKey] boolValue];
  }
  NSMutableArray* prefixes = [NSMutableArray arrayWithArray:[[LaTeXProcessor sharedLaTeXProcessor] unixBins]];
  [prefixes addObjectsFromArray:[NSArray arrayWithObjects:[proposedPath stringByDeletingLastPathComponent], nil]];
  if (![fileManager fileExistsAtPath:proposedPath])
    proposedPath = [self findUnixProgram:executableName tryPrefixes:prefixes environment:[[LaTeXProcessor sharedLaTeXProcessor] extraEnvironment] useLoginShell:useLoginShell];
  if ([fileManager fileExistsAtPath:proposedPath])
  {
    @synchronized(preferencesController){
      [preferencesController setCompositionConfigurationDocumentProgramPath:proposedPath forKey:pathKey];
    }
  }//end @synchronized(preferencesController)
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
    ([pathKey isEqualToString:CompositionConfigurationPdfLatexPathKey] && (!checkOnlyIfNecessary || (compositionMode == COMPOSITION_MODE_PDFLATEX))) ||
    ([pathKey isEqualToString:CompositionConfigurationXeLatexPathKey] && (!checkOnlyIfNecessary || (compositionMode == COMPOSITION_MODE_XELATEX))) ||
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
        pathProposed = [[preferencesController compositionConfigurationDocument] objectForKey:pathKey];
      }
      BOOL pathProposedIsEmpty = !pathProposed || [pathProposed isEqualToString:@""];
      BOOL ok = !pathProposedIsEmpty && [[NSFileManager defaultManager] isExecutableFileAtPath:pathProposed];
      //currently, the only check is the option -v, at least to see if the program can be executed
      int error = !ok ? 127 : system([[NSString stringWithFormat:@"%@ -v 1>|/dev/null 2>&1", pathProposed] UTF8String]);
      error = !ok ? 127 : (WIFEXITED(error) ? WEXITSTATUS(error) : 127);
      ok = ok && (error != 127);
      *monitor = ok;

      NSDictionary* recursiveConfiguration = [configuration subDictionaryWithKeys:[NSArray arrayWithObjects:@"path", @"executableName", @"monitor", nil]];
      BOOL allowFindOnFailure = [[configuration objectForKey:@"allowFindOnFailure"] boolValue];
      BOOL shouldFind = !ok && allowFindOnFailure;// && !pathProposedIsEmpty;
      if (shouldFind)
      {
        [self _findPathWithConfiguration:recursiveConfiguration];
        [self _checkPathWithConfiguration:recursiveConfiguration];
        ok = (*monitor);
      }

      BOOL allowUIAlertOnFailure = [[configuration objectForKey:@"allowUIAlertOnFailure"] boolValue];
      BOOL allowUIFindOnFailure  = [[configuration objectForKey:@"allowUIFindOnFailure"] boolValue];
      BOOL retry = !(*monitor) && allowUIAlertOnFailure;
      NSString* executableName = !retry ? nil : [configuration objectForKey:@"executableName"];
      while (retry)
      {
        retry = NO;
        int returnCode =
          NSRunAlertPanel(
            [NSString stringWithFormat:
              NSLocalizedString(@"%@ not found or does not work as expected", @"%@ not found or does not work as expected"), executableName],
            [NSString stringWithFormat:
              NSLocalizedString(@"The current configuration of LaTeXiT requires %@ to work.",
                                @"The current configuration of LaTeXiT requires %@ to work."), executableName],
            !allowUIFindOnFailure ? @"OK" : [NSString stringWithFormat:NSLocalizedString(@"Find %@...", @"Find %@..."), executableName],
            !allowUIFindOnFailure ? nil : @"Cancel", nil);
        if (allowUIFindOnFailure && (returnCode == NSAlertDefaultReturn))
        {
          NSFileManager* fileManager = [NSFileManager defaultManager];
          NSOpenPanel* openPanel = [NSOpenPanel openPanel];
          [openPanel setResolvesAliases:NO];
          int ret2 = [openPanel runModalForDirectory:@"/usr" file:nil types:nil];
          ok = (ret2 == NSOKButton) && ([[openPanel filenames] count]);
          if (ok)
          {
            NSString* filepath = [[openPanel filenames] objectAtIndex:0];
            if (![fileManager fileExistsAtPath:filepath])
              retry = YES;
            else
            {
              [[LaTeXProcessor sharedLaTeXProcessor] addInEnvironmentPath:[filepath stringByDeletingLastPathComponent]];
              @synchronized(preferencesController){
                [preferencesController setCompositionConfigurationDocumentProgramPath:filepath forKey:pathKey];
              }
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
          //[kpseWhichTask setStandardOutput:nullDevice];
          //[kpseWhichTask setStandardError:nullDevice];
          [kpseWhichTask setTimeOut:2.0];
          [kpseWhichTask launch];
          [kpseWhichTask waitUntilExit];
          ok = ([kpseWhichTask terminationStatus] == 0);
        }
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

-(void) closeLinkBackLink:(LinkBack*)link
{
  [link retain];
  @try{
    NSValue* key = [NSValue valueWithPointer:link];
    if ([self->linkbackLinks containsObject:key])
    {
      @try{
        [self->linkbackLinks removeObject:key];
        //[link remoteCloseLink];
        [link closeLink];
      }
      @catch (NSException* e){
        DebugLog(0, @"exception : %@", e);
      }
      NSArray* documents = [NSApp orderedDocuments];
      [documents makeObjectsPerformSelector:@selector(closeLinkBackLink:) withObject:link];
    }//end if ([self->linkbackLinks containsObject:key])
  }
  @catch (NSException* e){
    DebugLog(0, @"exception : %@", e);
  }
  [link release];
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
  [self->linkbackLinks addObject:[NSValue valueWithPointer:link]];
  NSData* linkbackItemsData = [[[link pasteboard] propertyListForType:LinkBackPboardType] linkBackAppData];
  NSArray* linkbackItems = [NSKeyedUnarchiver unarchiveObjectWithData:linkbackItemsData];
  id firstLinkBackItem = (linkbackItems && [linkbackItems count]) ? [linkbackItems objectAtIndex:0] : nil;
  HistoryItem* historyItem = [firstLinkBackItem isKindOfClass:[HistoryItem class]] ? firstLinkBackItem : nil;
  LatexitEquation* latexitEquation =
    historyItem ? [historyItem equation] :
    [firstLinkBackItem isKindOfClass:[LatexitEquation class]] ? firstLinkBackItem :
    nil;

  MyDocument* documentForLink = nil;
  documentForLink = (MyDocument*) [self currentDocument];
  /*
  NSEnumerator* enumerator = !link ? nil : [[NSApp orderedDocuments] objectEnumerator];
  MyDocument* document = nil;
  while((document = [enumerator nextObject]))
  {
    LinkBack* documentLink = [document linkBackLink];
    if ((documentLink == link) || [[documentLink itemKey] isEqual:[link itemKey]])
    {
      documentForLink = document;
      break;
    }
  }//for each document
  */

  if (!documentForLink)
    documentForLink = (MyDocument*) [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MyDocumentType" display:YES];
  if (documentForLink && latexitEquation)
  {
    if ([documentForLink linkBackLink] != link)
      [documentForLink setLinkBackLink:link];//automatically closes previous links
    [documentForLink applyLatexitEquation:latexitEquation isRecentLatexisation:NO]; //defines the state of the document
    [NSApp activateIgnoringOtherApps:YES];
    NSArray* windows = [documentForLink windowControllers];
    NSWindow* window = [[windows lastObject] window];
    [documentForLink setDocumentTitle:NSLocalizedString(@"Equation linked with another application",
                                                        @"Equation linked with another application")];
    [window makeKeyAndOrderFront:self];
    [window makeFirstResponder:[documentForLink preferredFirstResponder]];
  }
}
//end linkBackClientDidRequestEdit:

#pragma mark service

-(void) serviceLatexisationAlign:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_ALIGN error:error];
}
//end serviceLatexisationAlign:userData:error:

-(void) serviceLatexisationEqnarray:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_EQNARRAY error:error];
}
//end serviceLatexisationEqnarray:userData:error:

-(void) serviceLatexisationDisplay:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_DISPLAY error:error];
}
//end serviceLatexisationDisplay:userData:error:

-(void) serviceLatexisationInline:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_INLINE error:error];
}
//end serviceLatexisationInline:userData:error:

-(void) serviceLatexisationText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_TEXT error:error];
}
//end serviceLatexisationText:userData:error:

-(void) serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceMultiLatexisation:pboard userData:userData error:error];
}
//end serviceMultiLatexisation:userData:error:

-(void) serviceDeLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceDeLatexisation:pboard userData:userData error:error];
}
//end serviceDeLatexisation:userData:error:

//performs the application service
-(void) _serviceLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData mode:(latex_mode_t)mode
                       error:(NSString **)error
{
  if (!self->isPdfLaTeXAvailable || !self->isGsAvailable)
  {
    NSString* message = NSLocalizedString(@"LaTeXiT cannot be run properly, please check its configuration",
                                          @"LaTeXiT cannot be run properly, please check its configuration");
    *error = message;
    NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), message, @"OK", nil, nil);
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
      if ([types containsObject:NSRTFPboardType] || [types containsObject:@"public.rtf"])
      {
        NSDictionary* documentAttributes = nil;
        NSData* pboardData = [pboard dataForType:NSRTFPboardType];
        if (!pboardData) pboardData = [pboard dataForType:@"public.rtf"];
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
          int itemNumber  = [attrString itemNumberInTextList:textList atIndex:0];
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
        NSNumber* originalBaseline = [contextAttributes objectForKey:NSBaselineOffsetAttributeName];
        if (!originalBaseline) originalBaseline = [NSNumber numberWithFloat:0.0];
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
        [[LaTeXProcessor sharedLaTeXProcessor] latexiseWithPreamble:preamble body:body color:color mode:mode magnification:magnification
                           compositionConfiguration:[preferencesController compositionConfigurationDocument]
                           backgroundColor:nil
                           leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin
                           additionalFilesPaths:[self additionalFilesPaths]
                           workingDirectory:workingDirectory fullEnvironment:fullEnvironment
                           uniqueIdentifier:uniqueIdentifier
                           outFullLog:nil outErrors:nil outPdfData:&pdfData];

        //if it has worked, put back data in the service pasteboard
        if (pdfData)
        {
          //we will create the image file that will be attached to the rtfd
          NSString* directory          = [[NSWorkspace sharedWorkspace] temporaryDirectory];
          NSString* filePrefix         = [NSString stringWithFormat:@"latexit-%d", 0];
          NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
          export_format_t exportFormat = [userDefaults integerForKey:DragExportTypeKey];
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
          }

          NSString* attachedFile       = [NSString stringWithFormat:@"%@.%@", filePrefix, extension];
          NSString* attachedFilePath   = [directory stringByAppendingPathComponent:attachedFile];
          NSData*   attachedData       = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData
                                           jpegColor:[preferencesController exportJpegBackgroundColor]
                                           jpegQuality:[preferencesController exportJpegQualityPercent]
                                            scaleAsPercent:[preferencesController exportScalePercent]
                                            compositionConfiguration:[preferencesController compositionConfigurationDocument]];

          //Now we must feed the pasteboard
          //[pboard declareTypes:[NSArray array] owner:nil];

           //we try to make RTFD data only if the user wants to use the baseline, because there is
           //a side-effect : it "disables" LinkBack (can't click on an image embedded in RTFD)
          if (useBaseline)
          {
            //extracts the baseline of the equation, if possible
            CGFloat newBaseline = [originalBaseline floatValue];
            if (useBaseline)
              newBaseline -= [[[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES] objectForKey:@"baseline"] doubleValue];//[LatexitEquation baselineFromData:pdfData];

            //creates a mutable attributed string containing the image file
            [attachedData writeToFile:attachedFilePath atomically:NO];
            NSFileWrapper*      fileWrapperOfImage        = [[[NSFileWrapper alloc] initWithPath:attachedFilePath] autorelease];
            NSTextAttachment*   textAttachmentOfImage     = [[[NSTextAttachment alloc] initWithFileWrapper:fileWrapperOfImage] autorelease];
            NSAttributedString* attributedStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachmentOfImage];
            NSMutableAttributedString* mutableAttributedStringWithImage =
              [[[NSMutableAttributedString alloc] initWithAttributedString:attributedStringWithImage] autorelease];
              
            //changes the baseline of the attachment to align it with the surrounding text
            [mutableAttributedStringWithImage addAttribute:NSBaselineOffsetAttributeName
                                                     value:[NSNumber numberWithFloat:newBaseline]
                                                     range:NSMakeRange(0, [mutableAttributedStringWithImage length])];
            
            //add a space after the image, to restore the baseline of the surrounding text
            //Gee! It works with TextEdit but not with Pages. That is to say, in Pages, if I put this space, the baseline of
            //the equation is reset. And if do not put this space, the cursor stays in "tuned baseline" mode.
            //However, it works with Nisus Writer Express, so that I think it is a bug in Pages
            unichar invisibleSpace = 0xFEFF;
            NSString* invisibleSpaceString = [[[NSString alloc] initWithCharacters:&invisibleSpace length:1] autorelease];
            NSMutableAttributedString* space = [[[NSMutableAttributedString alloc] initWithString:invisibleSpaceString] autorelease];
            [space setAttributes:contextAttributes range:NSMakeRange(0, [space length])];
            [space addAttribute:NSBaselineOffsetAttributeName value:[NSNumber numberWithFloat:newBaseline]
                          range:NSMakeRange(0, [space length])];
            [mutableAttributedStringWithImage insertAttributedString:space atIndex:0];
            [mutableAttributedStringWithImage appendAttributedString:space];

            //finally creates the rtdfData
            NSData* rtfdData = [mutableAttributedStringWithImage RTFDFromRange:NSMakeRange(0, [mutableAttributedStringWithImage length])
                                                            documentAttributes:documentAttributes];
            //RTFd data
            //[pboard addTypes:[NSArray arrayWithObject:NSRTFDPboardType] owner:nil];
            //[pboard setData:rtfdData forType:NSRTFDPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:@"com.apple.flat-rtfd"] owner:nil];
            //[pboard setData:rtfdData forType:@"com.apple.flat-rtfd"];
            if (rtfdData)
            {
              [dummyPboard setObject:rtfdData forKey:NSRTFDPboardType];
              [dummyPboard setObject:rtfdData forKey:@"com.apple.flat-rtfd"];
            }
          }//end if useBaseline

          //LinkBack data
          NSAttributedString* attributedPreamble = [[NSAttributedString alloc] initWithString:preamble];
          LatexitEquation* latexitEquation =
            [[LatexitEquation alloc] initWithPDFData:pdfData preamble:attributedPreamble
                                         sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                              color:[NSColor blackColor] pointSize:defaultPointSize date:[NSDate date] mode:mode
                                    backgroundColor:nil];
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
            //[pboard addTypes:[NSArray arrayWithObject:@"com.adobe.pdf"] owner:nil];
            //[pboard setData:pdfData forType:@"com.adobe.pdf"];
            if (pdfData)
            {
              [dummyPboard setObject:pdfData forKey:NSPDFPboardType];
              [dummyPboard setObject:pdfData forKey:@"com.adobe.pdf"];
            }
          }
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
            }
          }
          else if ([extension isEqualToString:@"png"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:@"public.png"] owner:nil];
            //[pboard setData:attachedData forType:@"public.png"];
            if (attachedData)
              [dummyPboard setObject:attachedData forKey:@"public.png"];
          }
          else if ([extension isEqualToString:@"tiff"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            //[pboard setData:attachedData forType:NSTIFFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:@"public.tiff"] owner:nil];
            //[pboard setData:attachedData forType:@"public.tiff"];
            if (attachedData)
            {
              [dummyPboard setObject:attachedData forKey:NSTIFFPboardType];
              [dummyPboard setObject:attachedData forKey:@"public.tiff"];
            }
          }
          else if ([extension isEqualToString:@"jpeg"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            //[pboard setData:attachedData forType:NSTIFFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:@"public.jpeg"] owner:nil];
            //[pboard setData:attachedData forType:@"public.jpeg"];
            if (attachedData)
            {
              [dummyPboard setObject:attachedData forKey:NSTIFFPboardType];
              [dummyPboard setObject:attachedData forKey:@"public.jpeg"];
            }
          }
        }//end if pdfData
        else
        {
          NSString* message = NSLocalizedString(@"This text is not LaTeX compliant; or perhaps it is a preamble problem ? "\
                                                @"You can check it in LaTeXiT",
                                                @"This text is not LaTeX compliant; or perhaps it is a preamble problem ? "\
                                                @"You can check it in LaTeXiT");
          *error = message;
          [NSApp activateIgnoringOtherApps:YES];
          int choice = NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), message, NSLocalizedString(@"Cancel", @"Cancel"),
                                       NSLocalizedString(@"Open in LaTeXiT", @"Open in LaTeXiT"), nil);
          if (choice == NSAlertAlternateReturn)
          {
           MyDocument* document = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MyDocumentType" display:YES];
           [document setSourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]];
           [document setLatexMode:mode];
           [document setColor:color];
           [document setMagnification:magnification];
           [[document windowForSheet] makeFirstResponder:[document preferredFirstResponder]];
           [document latexize:self];
          }
        }//end if pdfData (LaTeXisation has worked)
      }
      //if the input is not RTF but just string, we will use default color and size
      else if ([types containsObject:NSStringPboardType] || [types containsObject:NSPDFPboardType])
      {
        NSAttributedString* preamble = [self preambleServiceAttributedString];
        NSString* pboardString = nil;
        if ([types containsObject:NSPDFPboardType])
        {
          PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:[pboard dataForType:NSPDFPboardType]];
          pboardString = [pdfDocument string];
          [pdfDocument release];
        }
        else if ([types containsObject:@"com.adobe.pdf"])
        {
          PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:[pboard dataForType:@"com.adobe.pdf"]];
          pboardString = [pdfDocument string];
          [pdfDocument release];
        }
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
          leftMargin:leftMargin rightMargin:rightMargin topMargin:topMargin bottomMargin:bottomMargin
          additionalFilesPaths:[self additionalFilesPaths]
          workingDirectory:workingDirectory fullEnvironment:fullEnvironment
          uniqueIdentifier:uniqueIdentifier
          outFullLog:nil outErrors:nil outPdfData:&pdfData];

        //if it has worked, put back data in the service pasteboard
        if (pdfData)
        {
          //translates the data to the right format
          NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
          export_format_t exportFormat = [userDefaults integerForKey:DragExportTypeKey];
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
          }

          NSData* data = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData
                                     jpegColor:[preferencesController exportJpegBackgroundColor]
                                     jpegQuality:[preferencesController exportJpegQualityPercent]
                                      scaleAsPercent:[preferencesController exportScalePercent]
                                      compositionConfiguration:[preferencesController compositionConfigurationDocument]];

          //now feed the pasteboard
          //[pboard declareTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:nil];
          //LinkBack data
          LatexitEquation* latexitEquation =
            [[LatexitEquation alloc] initWithPDFData:pdfData preamble:preamble
                                         sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                              color:[NSColor blackColor] pointSize:defaultPointSize date:[NSDate date] mode:mode
                                    backgroundColor:nil];
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
            //[pboard addTypes:[NSArray arrayWithObject:@"com.adobe.pdf"] owner:nil];
            //[pboard setData:data forType:@"com.adobe.pdf"];
            if (pdfData)
            {
              [dummyPboard setObject:pdfData forKey:NSPDFPboardType];
              [dummyPboard setObject:pdfData forKey:@"com.adobe.pdf"];
            }
          }
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
            }
          }
          else if ([extension isEqualToString:@"png"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:@"public.png"] owner:nil];
            //[pboard setData:data forType:@"public.png"];
            if (data)
              [dummyPboard setObject:data forKey:@"public.png"];
          }
          else if ([extension isEqualToString:@"tiff"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            //[pboard setData:data forType:NSTIFFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:@"public.tiff"] owner:nil];
            //[pboard setData:data forType:@"public.tiff"];
            if (data)
            {
              [dummyPboard setObject:data forKey:NSTIFFPboardType];
              [dummyPboard setObject:data forKey:@"public.tiff"];
            }
          }
          else if ([extension isEqualToString:@"jpeg"])
          {
            //[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            //[pboard setData:data forType:NSTIFFPboardType];
            //[pboard addTypes:[NSArray arrayWithObject:@"public.jpeg"] owner:nil];
            //[pboard setData:data forType:@"public.jpeg"];
            if (data)
            {
              [dummyPboard setObject:data forKey:NSTIFFPboardType];
              [dummyPboard setObject:data forKey:@"public.jpeg"];
            }
          }
        }
        else
        {
          NSString* message = NSLocalizedString(@"This text is not LaTeX compliant; or perhaps it is a preamble problem ? "\
                                                @"You can check it in LaTeXiT",
                                                @"This text is not LaTeX compliant; or perhaps it is a preamble problem ? "\
                                                @"You can check it in LaTeXiT");
          *error = message;
          [NSApp activateIgnoringOtherApps:YES];
          int choice = NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), message, NSLocalizedString(@"Cancel", @"Cancel"),
                                       NSLocalizedString(@"Open in LaTeXiT", @"Open in LaTeXiT"), nil);
          if (choice == NSAlertAlternateReturn)
          {
           MyDocument* document = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MyDocumentType" display:YES];
           [document setSourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]];
           [document setLatexMode:mode];
           [[document windowForSheet] makeFirstResponder:[document preferredFirstResponder]];
           [document latexize:self];
          }
        }//end if pdfData (LaTeXisation has worked)
      }//end if not RTF
      
      //add dummyPbord to pboar in one command
      [pboard declareTypes:[dummyPboard allKeys] owner:nil];
      NSEnumerator* enumerator = [dummyPboard keyEnumerator];
      id key = nil;
      while((key = [enumerator nextObject]))
      {
        id value = [dummyPboard objectForKey:key];
        if ([value isKindOfClass:[NSData class]])
          [pboard setData:value forType:key];
        else
          [pboard setPropertyList:value forType:key];
      }//end for each value
    }//end @synchronized(self)
  }//end if latexisation can be performed
}
//end _serviceLatexisation:userData:mode:error:

-(void) _serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  if (!self->isPdfLaTeXAvailable || !self->isGsAvailable)
  {
    NSString* message = NSLocalizedString(@"LaTeXiT cannot be run properly, please check its configuration",
                                          @"LaTeXiT cannot be run properly, please check its configuration");
    *error = message;
    NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), message, @"OK", nil, nil);
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
      attrString = attrString ? attrString : [[[NSAttributedString alloc] initWithRTF:[pboard dataForType:@"com.apple.flat-rtfd"]
                                                                   documentAttributes:&documentAttributes] autorelease];
      attrString = attrString ? attrString : [[[NSAttributedString alloc] initWithRTF:[pboard dataForType:NSRTFPboardType]
                                                                   documentAttributes:&documentAttributes] autorelease];
      attrString = attrString ? attrString : [[[NSAttributedString alloc] initWithRTF:[pboard dataForType:@"public.rtf"]
                                                                   documentAttributes:&documentAttributes] autorelease];
      NSMutableAttributedString* mutableAttrString = [[attrString mutableCopy] autorelease];
      
      NSRange remainingRange = NSMakeRange(0, [mutableAttrString length]);
      int numberOfFailures = 0;

      //we must find some places where latexisations should be done. We look for "$$..$$", "\[..\]", and "$...$"
      NSArray* delimiters =
        [NSArray arrayWithObjects:
          [NSArray arrayWithObjects:@"$$", @"$$"  , [NSNumber numberWithInt:LATEX_MODE_DISPLAY], nil],
          [NSArray arrayWithObjects:@"\\[", @"\\]", [NSNumber numberWithInt:LATEX_MODE_DISPLAY], nil],
          [NSArray arrayWithObjects:@"$", @"$"    , [NSNumber numberWithInt:LATEX_MODE_INLINE], nil],
          [NSArray arrayWithObjects:@"\\begin{eqnarray*}", @"\\end{eqnarray*}", [NSNumber numberWithInt:LATEX_MODE_EQNARRAY], nil],
          [NSArray arrayWithObjects:@"\\begin{align*}", @"\\end{align*}", [NSNumber numberWithInt:LATEX_MODE_ALIGN], nil],
          nil];

      NSMutableArray* errorDocuments = [NSMutableArray array];
      unsigned int delimiterIndex = 0;
      for(delimiterIndex = 0 ; delimiterIndex < [delimiters count] ; ++delimiterIndex)
      {
        NSArray* delimiter = [delimiters objectAtIndex:delimiterIndex];
        NSString* delimiterLeft  = [delimiter objectAtIndex:0];
        NSString* delimiterRight = [delimiter objectAtIndex:1];
        unsigned int delimiterLeftLength  = [delimiterLeft  length];
        unsigned int delimiterRightLength = [delimiterRight length];
        latex_mode_t mode = (latex_mode_t) [[delimiter objectAtIndex:2] intValue];
      
        BOOL finished = NO;
        while(!finished)
        {
          NSString* string = [mutableAttrString string];
          unsigned int length = [string length];
          
          NSRange begin = NSMakeRange(NSNotFound, 0);
          BOOL mustFindBegin = YES;
          while(mustFindBegin)
          {
            mustFindBegin = NO;
            begin = [string rangeOfString:delimiterLeft options:0 range:remainingRange];
            //check if it is not a previous delimiter (problem for $$ and $)
            unsigned int index2 = 0;
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
            NSNumber* originalBaseline = [contextAttributes objectForKey:NSBaselineOffsetAttributeName];
            if (!originalBaseline) originalBaseline = [NSNumber numberWithFloat:0.0];
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
              MyDocument* document = [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MyDocumentType" display:NO];
              [[document windowControllers] makeObjectsPerformSelector:@selector(window)];//calls windowDidLoad
              [document setSourceText:[[[NSAttributedString alloc] initWithString:body] autorelease]];
              [document setLatexMode:mode];
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
              }

              if ([[PreferencesController sharedController] historySaveServicesResultsEnabled])//we may add the item to the history
              {
                LatexitEquation* latexitEquation =
                  [LatexitEquation latexitEquationWithPDFData:pdfData
                     preamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]
                   sourceText:[[[NSAttributedString alloc] initWithString:body] autorelease]
                        color:color pointSize:pointSize date:[NSDate date] mode:mode backgroundColor:nil];
                [self addEquationToHistory:latexitEquation];
              }

              NSString* attachedFilePath = nil;//[NSString stringWithFormat:@"%@-%d.%@", filePrefix, attachedFileId++, extension];              
              NSFileHandle* fileHandle =
                [[NSFileManager defaultManager] temporaryFileWithTemplate:[NSString stringWithFormat:@"%@-XXXXXXXXX", filePrefix]
                                                                extension:extension
                                                              outFilePath:&attachedFilePath workingDirectory:directory];
              NSData* attachedData = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData
                                       jpegColor:[preferencesController exportJpegBackgroundColor]
                                       jpegQuality:[preferencesController exportJpegQualityPercent]
                                        scaleAsPercent:[preferencesController exportScalePercent]
                                        compositionConfiguration:[preferencesController compositionConfigurationDocument]];

              //extracts the baseline of the equation, if possible
              CGFloat newBaseline = [originalBaseline floatValue];
              if (useBaseline)
                newBaseline -= [[[LatexitEquation metaDataFromPDFData:pdfData useDefaults:YES] objectForKey:@"baseline"] doubleValue];//[LatexitEquation baselineFromData:pdfData];

              //creates a mutable attributed string containing the image file
              [fileHandle writeData:attachedData];
              [fileHandle closeFile];
              NSFileWrapper*      fileWrapperOfImage        = [[[NSFileWrapper alloc] initWithPath:attachedFilePath] autorelease];
              NSTextAttachment*   textAttachmentOfImage     = [[[NSTextAttachment alloc] initWithFileWrapper:fileWrapperOfImage] autorelease];
              NSAttributedString* attributedStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachmentOfImage];
              NSMutableAttributedString* mutableAttributedStringWithImage =
                [[[NSMutableAttributedString alloc] initWithAttributedString:attributedStringWithImage] autorelease];
                  
              //changes the baseline of the attachment to align it with the surrounding text
              [mutableAttributedStringWithImage addAttribute:NSBaselineOffsetAttributeName
                                                       value:[NSNumber numberWithFloat:newBaseline]
                                                       range:NSMakeRange(0, [mutableAttributedStringWithImage length])];
                
              //add a space after the image, to restore the baseline of the surrounding text
              //Gee! It works with TextEdit but not with Pages. That is to say, in Pages, if I put this space, the baseline of
              //the equation is reset. And if do not put this space, the cursor stays in "tuned baseline" mode.
              //However, it works with Nisus Writer Express, so that I think it is a bug in Pages
              unichar invisibleSpace = 0xFEFF;
              NSString* invisibleSpaceString = [[[NSString alloc] initWithCharacters:&invisibleSpace length:1] autorelease];
              NSMutableAttributedString* space = [[[NSMutableAttributedString alloc] initWithString:invisibleSpaceString] autorelease];
              [space setAttributes:contextAttributes range:NSMakeRange(0, [space length])];
              [space addAttribute:NSBaselineOffsetAttributeName value:[NSNumber numberWithFloat:newBaseline]
                            range:NSMakeRange(0, [space length])];
              [mutableAttributedStringWithImage insertAttributedString:space atIndex:0];
              [mutableAttributedStringWithImage appendAttributedString:space];
              //inserts the image in the global string
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
                                @"also check if it is compatible with the default preamble in use.",
                                @"%d equation could not be converted because of syntax errors in it. You should "
                                @"also check if it is compatible with the default preamble in use.")
            : NSLocalizedString(@"%d equations could not be converted because of syntax errors in them. You should "
                                @"also check if they are compatible with the default preamble in use.",
                                @"%d equations could not be converted because of syntax errors in them. You should "
                                @"also check if they are compatible with the default preamble in use.");
        message = [NSString stringWithFormat:message, numberOfFailures];
        *error = message;
        
        [NSApp activateIgnoringOtherApps:YES];
        int choice = NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), message, NSLocalizedString(@"Cancel", @"Cancel"),
                                     NSLocalizedString(@"Open in LaTeXiT", @"Open in LaTeXiT"), nil);
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
        }
      }//if there were failures
      
      //Now we must feed the pasteboard
      NSMutableDictionary* dummyPboard = [NSMutableDictionary dictionary];
      NSData* rtfdData = [mutableAttrString RTFDFromRange:NSMakeRange(0, [mutableAttrString length])
                                       documentAttributes:documentAttributes];
      [dummyPboard setObject:rtfdData forKey:NSRTFDPboardType];
      [dummyPboard setObject:rtfdData forKey:@"com.apple.flat-rtfd"];

      [pboard declareTypes:[dummyPboard allKeys] owner:nil];
      NSEnumerator* enumerator = [dummyPboard keyEnumerator];
      id key = nil;
      while((key = [enumerator nextObject]))
      {
        id value = [dummyPboard objectForKey:key];
        if ([value isKindOfClass:[NSData class]])
          [pboard setData:value forType:key];
        else
          [pboard setPropertyList:value forType:key];
      }//end for each value
    }//end @synchronized(self)
  }//end if latexisation can be performed
}
//end _serviceMultiLatexisation:userData:mode:error:

-(void) _serviceDeLatexisation:(NSPasteboard*)pboard userData:(NSString*)userData error:(NSString**)error
{
  NSString* type = nil;
  if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSPDFPboardType, @"com.adobe.pdf", nil]]))
  {
    NSData* pdfData = [pboard dataForType:type];
    LatexitEquation* latexitEquation = [[LatexitEquation alloc] initWithPDFData:pdfData useDefaults:YES];
    NSMutableAttributedString* source = !latexitEquation ? nil :
      [[[NSMutableAttributedString alloc] initWithAttributedString:[latexitEquation sourceText]] autorelease];
    if (source)
    {
      NSFont* font = [[source fontAttributesInRange:NSMakeRange(0, [source length])] objectForKey:NSFontAttributeName];
      font = font ? font : [NSFont userFontOfSize:[latexitEquation pointSize]];
      font = [NSFont fontWithName:[font fontName] size:[latexitEquation pointSize]];
      NSDictionary* attributes = 
        [NSDictionary dictionaryWithObjectsAndKeys:
          font, NSFontAttributeName,
          [NSString stringWithFormat:@"%f",  [latexitEquation pointSize]], NSFontSizeAttribute,
          [latexitEquation color], NSForegroundColorAttributeName, nil];
      [source addAttributes:attributes range:NSMakeRange(0, [source length])];
      [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, @"public.utf8-plain-text",
                                                     NSRTFPboardType, @"public.rtf", nil]  owner:nil];
      [pboard setString:[source string] forType:NSStringPboardType];
      [pboard setString:[source string] forType:@"public.utf8-plain-text"];
      NSData* rtfData = [source RTFFromRange:NSMakeRange(0, [source length]) documentAttributes:nil];
      [pboard setData:rtfData forType:NSRTFPboardType];
      [pboard setData:rtfData forType:@"public.rtf"];
    }
    [latexitEquation release];
  }
  else if ((type = [pboard availableTypeFromArray:[NSArray arrayWithObjects:NSRTFDPboardType, @"com.apple.flat-rtfd", nil]]))
  {
    NSData* rtfdData = [pboard dataForType:type];
    NSDictionary* docAttributes = nil;
    NSMutableAttributedString* attributedString =
      [[NSMutableAttributedString alloc] initWithRTFD:rtfdData documentAttributes:&docAttributes];
    unsigned int location = 0;
    while(location < [attributedString length])
    {
      NSRange effectiveRange = NSMakeRange(0, 0);
      NSDictionary* attributesForCharacter = [attributedString attributesAtIndex:location effectiveRange:&effectiveRange];
      NSTextAttachment* textAttachment = [attributesForCharacter objectForKey:NSAttachmentAttributeName];
      if (!textAttachment)
        location += effectiveRange.length;
      else
      {
        NSString* filename = [[textAttachment fileWrapper] filename];
        if (![[[filename pathExtension] lowercaseString] isEqualToString:@"pdf"])
          location += effectiveRange.length;
        else
        {
          NSData* pdfData = [[textAttachment fileWrapper] regularFileContents];
          LatexitEquation* latexitEquation = [[LatexitEquation alloc] initWithPDFData:pdfData useDefaults:YES];
          NSMutableAttributedString* source = !latexitEquation ? nil :
            [[[NSMutableAttributedString alloc] initWithAttributedString:[latexitEquation encapsulatedSource]] autorelease];
          if (!source)
            location += effectiveRange.length;
          else
          {
            NSFont* font = [[attributedString fontAttributesInRange:effectiveRange] objectForKey:NSFontAttributeName];
            font = font ? font : [NSFont userFontOfSize:[latexitEquation pointSize]];
            font = [NSFont fontWithName:[font fontName] size:[latexitEquation pointSize]];
            NSDictionary* attributes = 
              [NSDictionary dictionaryWithObjectsAndKeys:
                font, NSFontAttributeName,
                [NSString stringWithFormat:@"%f",  [latexitEquation pointSize]], NSFontSizeAttribute,
                [latexitEquation color], NSForegroundColorAttributeName, nil];
            [attributedString replaceCharactersInRange:effectiveRange withAttributedString:source];
            [attributedString addAttributes:attributes range:NSMakeRange(effectiveRange.location, [source length])];
            location += [source length];
          }
          [latexitEquation release];
        }//end if is pdf
      }//end if textAttachment
    }//end while ! at the end of the string
    [pboard declareTypes:[NSArray arrayWithObjects:NSRTFDPboardType, @"com.apple.flat-rtfd",
                                                   NSRTFPboardType, @"public.rtf", nil] owner:nil];
    NSData* outRtfdData = [attributedString RTFDFromRange:NSMakeRange(0, [attributedString length])
                          documentAttributes:docAttributes];
    [pboard setData:outRtfdData forType:NSRTFDPboardType];
    [pboard setData:outRtfdData forType:@"com.apple.flat-rtfd"];
    NSData* outRtfData = [attributedString RTFFromRange:NSMakeRange(0, [attributedString length])
                          documentAttributes:docAttributes];
    [pboard setData:outRtfData forType:NSRTFPboardType];
    [pboard setData:outRtfData forType:@"public.rtf"];
    [attributedString release];
  }
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
-(IBAction) latexPalettesClick:(id)sender
{
  PaletteItem* item = [[sender selectedCell] representedObject];
  NSString* string = [item latexCode];
  MyDocument* myDocument = (MyDocument*) [self currentDocument];
  if (string && myDocument)
  {
    if (([item numberOfArguments] >= 0) || ([item type] == LATEX_ITEM_TYPE_ENVIRONMENT))
      string = [item stringWithTextInserted:[myDocument selectedText]];
    [myDocument insertText:string];
  }//end if (string && myDocument)
}
//end latexPalettesClick:

-(BOOL) installLatexPalette:(NSString*)palettePath
{
  BOOL ok = NO;
  NSFileManager* fileManager = [NSFileManager defaultManager];
  //first, checks if it may be a palette
  BOOL fileIsOk = NO;
  BOOL isDirectory  = NO;
  BOOL isDirectory2 = NO;
  BOOL isDirectory3 = NO;
  if ([fileManager fileExistsAtPath:palettePath isDirectory:&isDirectory] && isDirectory &&
      [fileManager fileExistsAtPath:[palettePath stringByAppendingPathComponent:@"Info.plist"] isDirectory:&isDirectory2] && !isDirectory2 &&
      [fileManager fileExistsAtPath:[palettePath stringByAppendingPathComponent:@"Resources"] isDirectory:&isDirectory3] && isDirectory3)
    fileIsOk = YES;
  if (!fileIsOk)
    NSRunAlertPanel(NSLocalizedString(@"Palette installation", @"Palette installation"),
                    NSLocalizedString(@"It does not appear to be a valid Latex palette package", @"It does not appear to be a valid Latex palette package"),
                    NSLocalizedString(@"OK", @"OK"), nil, nil);
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
      int choice = NSRunAlertPanel(
        [NSString stringWithFormat:NSLocalizedString(@"Do you want to install the palette %@ ?", @"Do you want to install the palette %@ ?"),
                                   [palettePath lastPathComponent]],
        [NSString stringWithFormat:NSLocalizedString(@"This palette will be installed into \n%@", @"This palette will be installed into \n%@"),
                                   localizedPalettesFolderPath],
        NSLocalizedString(@"Install palette", @"Install palette"),
        NSLocalizedString(@"Cancel", @"Cancel"), nil);
      if (choice == NSAlertDefaultReturn)
      {
        BOOL shouldInstall = [[NSFileManager defaultManager] createDirectoryPath:palettesFolderPath attributes:nil];
        if (!shouldInstall)
          NSRunAlertPanel(NSLocalizedString(@"Could not create path", @"Could not create path"),
                          [NSString stringWithFormat:NSLocalizedString(@"The path %@ could not be created to install a palette in it",
                                                                       @"The path %@ could not be created to install a palette in it"),
                                                     palettesFolderPath],
                          NSLocalizedString(@"OK", @"OK"), nil, nil);
                          
        NSString* destinationPath = [palettesFolderPath stringByAppendingPathComponent:[palettePath lastPathComponent]];
        BOOL alreadyExists = [fileManager fileExistsAtPath:destinationPath];
        BOOL overwrite = !alreadyExists;
        if (alreadyExists)
        {
          choice = NSRunAlertPanel(
            [NSString stringWithFormat:NSLocalizedString(@"The palette %@ already exists, do you want to replace it ?",
                                                         @"The palette %@ already exists, do you want to replace it ?"), [palettePath lastPathComponent]],
            [NSString stringWithFormat:NSLocalizedString(@"A file or folder with the same name already exists in %@. Replacing it will overwrite its current contents.",
                                                         @"A file or folder with the same name already exists in %@. Replacing it will overwrite its current contents."),
                                       palettesFolderPath],
             NSLocalizedString(@"Replace", @"Replace"),
             NSLocalizedString(@"Cancel", @"Cancel"), nil);
          overwrite |= (choice == NSAlertDefaultReturn);
        }//end if overwrite palette
        
        if (overwrite)
        {
          [fileManager removeFileAtPath:destinationPath handler:NULL];
          BOOL success = [fileManager copyPath:palettePath toPath:destinationPath handler:NULL];
          if (!success)
            NSRunAlertPanel(NSLocalizedString(@"Installation failed", @"Installation failed"),
                            [NSString stringWithFormat:NSLocalizedString(@"%@ could not be installed as %@", @"%@ could not be installed as %@"),
                                                                         [palettePath lastPathComponent], destinationPath],
                            NSLocalizedString(@"OK", @"OK"), nil, nil);
          ok = success;
        }//end if overwrite
      }//end if install palette
    }//end if palettesFolderPath
  }//end if ok to be a palette
  return ok;
}
//end installLatexPalette:

@end
