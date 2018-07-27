//  AppController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//The AppController is a singleton, a unique instance that acts as a bridge between the menu and the documents.
//It is also responsible for shared operations (like utilities : finding a program)
//It is also a bridge for the application service : it creates a dummy, invisible document that will perform
//the latexisation
//It is also the LinkBack server

#import "AppController.h"

#import "CompositionConfigurationController.h"
#import "EncapsulationController.h"
#import "HistoryController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LatexPalettesController.h"
#import "LibraryController.h"
#import "LibraryFile.h"
#import "LibraryManager.h"
#import "LineCountTextView.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSApplicationExtended.h"
#import "NSColorExtended.h"
#import "NSStringExtended.h"
#import "MarginController.h"
#import "PaletteItem.h"
#import "PreferencesController.h"

@interface AppController (PrivateAPI)

//specialized quick version of findUnixProgram... that does not take environment in account.
//It only looks for the existence of the file in the given paths, but does not look more.
-(NSString*) findUnixProgram:(NSString*)programName inPrefixes:(NSArray*)prefixes;

-(void) _addInEnvironmentPath:(NSString*)path; //increase the environmentPath
-(void) _setEnvironment; //utility that calls setenv() with the current content of environmentPath

//check the configuration, updates isGsAvailable, isPdfLatexAvailable and isColorStyAvailable
-(void) _checkConfiguration;

-(BOOL) _checkGs;      //called by _checkConfiguration to check for gs's presence
-(BOOL) _checkPs2pdf;  //called by _checkConfiguration to check for gs's presence
-(BOOL) _checkDvipdf;  //called by _checkConfiguration to check for dvipdf's presence
-(BOOL) _checkPdfLatex;//called by _checkConfiguration to check for pdflatex's presence
-(BOOL) _checkXeLatex; //called by _checkConfiguration to check for pdflatex's presence
-(BOOL) _checkLatex;   //called by _checkConfiguration to check for pdflatex's presence
-(BOOL) _checkColorSty;//called by _checkConfiguration to check for color.sty's presence

//helper for the configuration
-(void) _findGsPath;
-(void) _findDvipdfPath;
-(void) _findPdfLatexPath;
-(void) _findPs2PdfPath;
-(void) _findXeLatexPath;
-(void) _findLatexPath;

//some notifications that trigger some work
-(void) applicationDidFinishLaunching:(NSNotification *)aNotification;
-(void) _triggerHistoryBackgroundLoading:(id)object;
-(void) _somePathDidChangeNotification:(NSNotification *)aNotification;

//private method factorizing the work of the different application service calls
-(MyDocument*) _myDocumentServiceProvider;
-(void) _serviceLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData mode:(latex_mode_t)mode
                       error:(NSString **)error;
-(void) _serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;

//delegate method to filter file opening                       
-(BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename;
@end

@implementation AppController

//the unique instance of the appController
static AppController* appControllerInstance = nil;
static MyDocument*    myDocumentServiceProviderInstance = nil;

//usual environment and PATH to find a program on the command line
static NSMutableString*     environmentPath = nil;
static NSMutableDictionary* environmentDict = nil;
static NSMutableArray*      unixBins = nil;

static NSMutableDictionary* cachePaths = nil;

+(void) initialize
{
  //Yes, it seems ugly, but I need it to force the user defaults to be initialized
  [PreferencesController initialize];
  
  NSString* temporaryPathFileName = @"latexit-paths";
  NSString* temporaryPathFilePath = [[AppController latexitTemporaryPath] stringByAppendingPathComponent:temporaryPathFileName];
  NSString* systemCall =
    [NSString stringWithFormat:@". /etc/profile && /bin/echo \"$PATH\" > %@",
      temporaryPathFilePath, temporaryPathFilePath];
  int error = system([systemCall UTF8String]);
  NSArray* profileBins = error ? [NSArray array] 
                               : [[NSString stringWithContentsOfFile:temporaryPathFilePath] componentsSeparatedByString:@":"];
    
  if (!unixBins)
    unixBins = [[NSMutableArray alloc] initWithArray:profileBins];
  
  //usual unix PATH (to find latex)
  NSArray* usualBins = 
    [NSArray arrayWithObjects:@"/bin", @"/sbin",
      @"/usr/bin", @"/usr/sbin",
      @"/usr/local/bin", @"/usr/local/sbin",
      @"/sw/bin", @"/sw/sbin",
      @"/sw/usr/bin", @"/sw/usr/sbin",
      @"/sw/local/bin", @"/sw/local/sbin",
      @"/sw/usr/local/bin", @"/sw/usr/local/sbin",
      nil];
  [unixBins addObjectsFromArray:usualBins];
  if (!cachePaths)
    cachePaths = [[NSMutableDictionary alloc] init];

  //try to build the best environment for the current user
  if (!environmentPath)
  {
    environmentPath = [[NSMutableString alloc] initWithString:[unixBins componentsJoinedByString:@":"]];

    //add ~/.MacOSX/environment.plist
    NSString* filePath = [NSString pathWithComponents:[NSArray arrayWithObjects:NSHomeDirectory(), @".MacOSX", @"environment.plist", nil]];
    NSDictionary* propertyList = [NSDictionary dictionaryWithContentsOfFile:filePath];
    if (propertyList)
    {
      NSMutableArray* components = [NSMutableArray arrayWithArray:[environmentPath componentsSeparatedByString:@":"]];
      [components addObjectsFromArray:[[propertyList objectForKey:@"PATH"] componentsSeparatedByString:@":"]];
      [environmentPath setString:[components componentsJoinedByString:@":"]];
    }
  }

  if (!environmentDict)
  {
    environmentDict = [[[NSProcessInfo processInfo] environment] mutableCopy];

    NSString* pathEnv = [environmentDict objectForKey:@"PATH"];
    if (pathEnv)
    {
      NSMutableSet* pathsSet = [NSMutableSet setWithCapacity:30];
      [pathsSet addObjectsFromArray:[environmentPath componentsSeparatedByString:@":"]];
      [pathsSet addObjectsFromArray:[pathEnv componentsSeparatedByString:@":"]];
      [environmentPath setString:[[pathsSet allObjects] componentsJoinedByString:@":"]];
      [environmentDict setObject:environmentPath forKey:@"PATH"];
    }
  }
}

+(NSDictionary*) environmentDict
{
  return environmentDict;
}

+(NSArray*) unixBins
{
  return unixBins;
}

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

+(id) allocWithZone:(NSZone *)zone
{
  @synchronized(self)
  {
    if (!appControllerInstance)
       return [super allocWithZone:zone];
  }
  return appControllerInstance;
}

-(id) copyWithZone:(NSZone *)zone
{
  return self;
}

-(id) retain
{
  return self;
}

-(unsigned) retainCount
{
  return UINT_MAX;  //denotes an object that cannot be released
}

-(void) release
{
}

-(id) autorelease
{
  return self;
}

-(id) init
{
  if (self && (self != appControllerInstance))
  {
    if (![super init])
      return nil;
    appControllerInstance = self;
    [self _setEnvironment];     //performs a setenv()
    [self _findGsPath];
    [self _findPdfLatexPath];
    [self _findPs2PdfPath];
    [self _findXeLatexPath];
    [self _findLatexPath];
    [self _findDvipdfPath];
    [self _checkConfiguration]; //mainly, looks for pdflatex program
    
    //export to EPS needs ghostscript to be available
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    export_format_t exportFormat = [userDefaults integerForKey:DragExportTypeKey];
    if (exportFormat == EXPORT_FORMAT_EPS && !isGsAvailable)
      [userDefaults setInteger:EXPORT_FORMAT_PDF forKey:DragExportTypeKey];
    if (exportFormat == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS && (!isGsAvailable || !isPs2PdfAvailable))
      [userDefaults setInteger:EXPORT_FORMAT_PDF forKey:DragExportTypeKey];
    
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(_somePathDidChangeNotification:)
                                             name:SomePathDidChangeNotification object:nil];

     //declares the service. The service will be called on a dummy document (myDocumentServiceProvider), which is lazily created
     //when first used
     [NSApp setServicesProvider:self];
     NSUpdateDynamicServices();
  }
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [compositionConfigurationController release];
  [encapsulationController release];
  [historyController release];
  [marginController release];
  [latexPalettesController release];
  [libraryController release];
  [preferencesController release];
  [super dealloc];
}

-(NSDocument*) currentDocument
{
  return [[self class] currentDocument];
}

+(NSString*) latexitTemporaryPath
{
  NSString* thisVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
  if (!thisVersion)
    thisVersion = @"";
  NSArray* components = [thisVersion componentsSeparatedByString:@" "];
  if (components && [components count])
    thisVersion = [components objectAtIndex:0];

  NSString* temporaryPath =
    [NSTemporaryDirectory() stringByAppendingPathComponent:
      [NSString stringWithFormat:@"latexit-%@", thisVersion]];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  BOOL isDirectory = NO;
  BOOL exists = [fileManager fileExistsAtPath:temporaryPath isDirectory:&isDirectory];
  if (exists && !isDirectory)
  {
    [fileManager removeFileAtPath:temporaryPath handler:NULL];
    exists = NO;
  }
  if (!exists)
    [fileManager createDirectoryAtPath:temporaryPath attributes:nil];
  return temporaryPath;
}

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
  if (document == [[self appController] dummyDocument])
    document = nil;
  return document;
}

-(CompositionConfigurationController*) compositionConfigurationController
{
  if (!compositionConfigurationController)
    compositionConfigurationController = [[CompositionConfigurationController alloc] init];
  return compositionConfigurationController;
}

-(EncapsulationController*) encapsulationController
{
  if (!encapsulationController)
    encapsulationController = [[EncapsulationController alloc] init];
  return encapsulationController;
}

-(HistoryController*) historyController
{
  if (!historyController)
    historyController = [[HistoryController alloc] init];
  return historyController;
}

-(LatexPalettesController*) latexPalettesController
{
  if (!latexPalettesController)
    latexPalettesController = [[LatexPalettesController alloc] init];
  return latexPalettesController;
}

-(LibraryController*) libraryController
{
  if (!libraryController)
    libraryController = [[LibraryController alloc] init];
  return libraryController;
}

-(MarginController*) marginController
{
  if (!marginController)
    marginController = [[MarginController alloc] init];
  return marginController;
}

-(PreferencesController*) preferencesController
{
  if (!preferencesController)
    preferencesController = [[PreferencesController alloc] init];
  return preferencesController;
}

//the dummy document used for application service is lazily created at first use
-(MyDocument*) _myDocumentServiceProvider
{
  @synchronized(self)
  {
    if (!myDocumentServiceProviderInstance)
    {
       //this dummy document is only used for the application service
       myDocumentServiceProviderInstance =
         (MyDocument*) [[[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MyDocumentType" display:NO] retain];
       //uncomment the line below if you need the dummy document (myDocumentServiceProviderInstance) to have its IBOutlets connected
       //(it is disabled to improve start up time)
       //[NSBundle loadNibNamed:@"MyDocument" owner:myDocumentServiceProviderInstance];
       [myDocumentServiceProviderInstance setNullId];//the id should not interfere with the one of real documents
    }
  }
  return myDocumentServiceProviderInstance;
}

//increase environmentPath
-(void) _addInEnvironmentPath:(NSString*)path
{
  NSMutableSet* componentsSet = [NSMutableSet setWithArray:[environmentPath componentsSeparatedByString:@":"]];
  [componentsSet addObject:path];
  [componentsSet removeObject:@"."];
  [environmentPath setString:[[componentsSet allObjects] componentsJoinedByString:@":"]];
}

//performs a setenv()
-(void) _setEnvironment
{
  const char* oldPath = getenv("PATH");
  NSString* oldPathString = oldPath ? [NSString stringWithCString:oldPath] : [NSString string];
  NSMutableArray* components = [NSMutableArray arrayWithArray:[environmentPath componentsSeparatedByString:@":"]];
  [components addObject:oldPathString];
  setenv("PATH", [[components componentsJoinedByString:@":"] cString], 1);
}

-(BOOL) applicationShouldOpenUntitledFile:(NSApplication*)sender
{
  return YES;
}

-(MyDocument*) dummyDocument
{
  return [self _myDocumentServiceProvider];
}

-(IBAction) makeDonation:(id)sender//display info panel
{
  if (![donationPanel isVisible])
    [donationPanel center];
  [donationPanel orderFront:sender];
}

-(IBAction) newFromClipboard:(id)sender
{
  NSData* data = nil;
  NSString* filename = @"clipboard";
  NSPasteboard* pasteboard = [NSPasteboard generalPasteboard];
  if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSPDFPboardType]])
  {
    filename = [filename stringByAppendingPathExtension:@"pdf"];
    data = [pasteboard dataForType:NSPDFPboardType];
  }
  else if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]])
  {
    filename = [filename stringByAppendingPathExtension:@"tex"];
    data = [pasteboard dataForType:NSStringPboardType];
  }
  NSString* filepath = [[AppController latexitTemporaryPath] stringByAppendingPathComponent:filename];
  BOOL ok = data ? [data writeToFile:filepath atomically:YES] : NO;
  if (ok)
  {
    MyDocument* document =
      #ifdef PANTHER
      [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:filepath display:NO];
      #else
      [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:NO error:nil];
      #endif
    ok = [document readFromFile:filepath ofType:[filepath pathExtension]];
    if (!ok)
      [document close];
    else
    {
      [document makeWindowControllers];
      [document windowControllerDidLoadNib:[[document windowForSheet] windowController]];
      [document showWindows];
    }
  }
}

-(IBAction) copyAs:(id)sender
{
  [[(MyDocument*)[self currentDocument] imageView] copy:sender]; 
}

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  if ([sender action] == @selector(newFromClipboard:))
  {
    ok = ([[NSPasteboard generalPasteboard] availableTypeFromArray:
            [NSArray arrayWithObjects:NSPDFPboardType, NSStringPboardType, nil]] != nil);
  }
  else if ([sender action] == @selector(copyAs:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [myDocument hasImage];
    if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      ok &= isGsAvailable && isPs2PdfAvailable;
  }
  else if ([sender action] == @selector(exportImage:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [myDocument hasImage];
  }
  else if ([sender action] == @selector(makeLatex:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [self isPdfLatexAvailable];
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
    ok = (myDocument != nil) && ![myDocument isBusy];
    if (isPreambleVisible)
      [sender setTitle:NSLocalizedString(@"Hide preamble", @"Hide preamble")];
    else
      [sender setTitle:NSLocalizedString(@"Show preamble", @"Show preamble")];
  }
  else if ([sender action] == @selector(showOrHideHistory:))
  {
    BOOL isHistoryVisible = (historyController && [[historyController window] isVisible]);
    if (isHistoryVisible)
      [sender setTitle:NSLocalizedString(@"Hide History", @"Hide History")];
    else
      [sender setTitle:NSLocalizedString(@"Show History", @"Show History")];
  }
  else if ([sender action] == @selector(historyRemoveHistoryEntries:))
  {
    ok = historyController && [[historyController window] isVisible] && [historyController canRemoveEntries];
  }
  else if ([sender action] == @selector(historyClearHistory:))
  {
    ok = [[[HistoryManager sharedManager] historyItems] count];
  }
  else if ([sender action] == @selector(showOrHideLibrary:))
  {
    BOOL isLibraryVisible = (libraryController && [[libraryController window] isVisible]);
    if (isLibraryVisible)
      [sender setTitle:NSLocalizedString(@"Hide Library", @"Hide Library")];
    else
      [sender setTitle:NSLocalizedString(@"Show Library", @"Show Library")];
  }
  else if ([sender action] == @selector(libraryNewFolder:))
  {
    ok = libraryController && [[libraryController window] isVisible];
  }
  else if ([sender action] == @selector(libraryImportCurrent:))
  {
    MyDocument* document = (MyDocument*) [self currentDocument];
    ok = libraryController && [[libraryController window] isVisible] && document && [document hasImage];
  }
  else if ([sender action] == @selector(libraryRemoveSelectedItems:))
  {
    ok = libraryController && [[libraryController window] isVisible] && [libraryController canRemoveSelectedItems];
  }
  else if ([sender action] == @selector(libraryRefreshItems:))
  {
    ok = libraryController && [[libraryController window] isVisible] && [libraryController canRefreshItems];
  }
  else if ([sender action] == @selector(libraryOpen:))
  {
    ok = libraryController && [[libraryController window] isVisible];
  }
  else if ([sender action] == @selector(librarySaveAs:))
  {
    ok = libraryController && [[libraryController window] isVisible];
  }
  else if ([sender action] == @selector(showOrHideColorInspector:))
    [sender setState:[[NSColorPanel sharedColorPanel] isVisible] ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideCompositionConfiguration:))
    [sender setState:(compositionConfigurationController && [[compositionConfigurationController window] isVisible]) ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideEncapsulation:))
    [sender setState:(encapsulationController && [[encapsulationController window] isVisible]) ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideMargin:))
    [sender setState:(marginController && [[marginController window] isVisible]) ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideLatexPalettes:))
    [sender setState:(latexPalettesController && [[latexPalettesController window] isVisible]) ? NSOnState : NSOffState];
  return ok;
}

-(IBAction) historyRemoveHistoryEntries:(id)sender
{
  [[self historyController] removeHistoryEntries:sender];
}

-(IBAction) historyClearHistory:(id)sender
{
  [[self historyController] clearHistory:sender];
}

-(IBAction) showOrHideHistory:(id)sender
{
  NSWindowController* controller = [self historyController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}

-(IBAction) libraryImportCurrent:(id)sender //creates a library item with the current document state
{
  [[self libraryController] importCurrent:sender];
}

-(IBAction) libraryNewFolder:(id)sender     //creates a folder
{
  [[self libraryController] newFolder:sender];
}

-(IBAction) libraryRemoveSelectedItems:(id)sender    //removes some items
{
  [[self libraryController] removeSelectedItems:sender];
}

-(IBAction) libraryRefreshItems:(id)sender   //refresh an item
{
  [[self libraryController] refreshItems:sender];
}

-(IBAction) libraryOpen:(id)sender
{
  [[self libraryController] open:sender];
}

-(IBAction) librarySaveAs:(id)sender
{
  [[self libraryController] saveAs:sender];
}

-(IBAction) showOrHideLibrary:(id)sender
{
  NSWindowController* controller = [self libraryController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}

-(IBAction) showOrHideColorInspector:(id)sender
{
  NSColorPanel* colorPanel = [NSColorPanel sharedColorPanel];
  if ([colorPanel isVisible])
    [colorPanel close];
  else
    [colorPanel orderFront:self];
}

-(IBAction) showOrHidePreamble:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
  {
    BOOL makePreambleVisible = ![document isPreambleVisible];
    [document setPreambleVisible:makePreambleVisible];
  }
}

-(IBAction) showOrHideLatexPalettes:(id)sender
{
  NSWindowController* controller = [self latexPalettesController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}

-(IBAction) showOrHideCompositionConfiguration:(id)sender
{
  NSWindowController* controller = [self compositionConfigurationController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}

-(IBAction) showOrHideEncapsulation:(id)sender
{
  NSWindowController* controller = [self encapsulationController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}

-(IBAction) showOrHideMargin:(id)sender
{
  NSWindowController* controller = [self marginController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}

//looks for a programName in the given PATHs. Just tests that the file exists
-(NSString*) findUnixProgram:(NSString*)programName inPrefixes:(NSArray*)prefixes
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
  }
  return path;  
}

//looks for a programName in the environment.
-(NSString*) findUnixProgram:(NSString*)programName tryPrefixes:(NSArray*)prefixes
                 environment:(NSDictionary*)environment
{
  //first, it may be simply found in the common, usual, path
  NSString* path = [cachePaths objectForKey:programName];
  if (!path)
    path = [self findUnixProgram:programName inPrefixes:prefixes];
  
  if (!path) //if it is not...
  {
    //try to find it thanks to a "which" command
    NSString* whichPath = [self findUnixProgram:@"which" inPrefixes:unixBins];
    NSTask* whichTask = [[NSTask alloc] init];
    @try
    {
      NSPipe* pipe = [NSPipe pipe];
      NSFileHandle* readHandle = [pipe fileHandleForReading];
      [whichTask setEnvironment:environment];
      [whichTask setStandardOutput:pipe];
      [whichTask setLaunchPath:whichPath];
      [whichTask setArguments:[NSArray arrayWithObject:programName]];
      [whichTask launch];
      [whichTask waitUntilExit];
      NSData* data = [readHandle availableData];
      path = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
      if ([path length])
      {
        path = [path stringByDeletingLastPathComponent];
        path = [path stringByAppendingPathComponent:programName];
      }
    }
    @catch(NSException* e)
    {
    }
    @finally
    {
      [whichTask release];
    }
    if (path)
      [cachePaths setObject:path forKey:programName];
  }
  return path;
}

//ask for LaTeXiT's web site
-(IBAction) openWebSite:(id)sender
{
  NSMutableString* urlString =
    [NSMutableString stringWithString:NSLocalizedString(@"http://ktd.club.fr/programmation/latexit_en.php",
                                                        @"http://ktd.club.fr/programmation/latexit_en.php")];
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
                    @"Ok", nil, nil);
  }
}

//check for updates on LaTeXiT's web site
//if <sender> is nil, it's considered as a background task and will only present a panel if a new version is available.
-(IBAction) checkUpdates:(id)sender
{
  NSURL* versionFileURL = [NSURL URLWithString:@"http://ktd.club.fr/programmation/fichiers/latexit-version-current"];
  NSString* currentVersion = [NSString stringWithContentsOfURL:versionFileURL];
  if (sender && !currentVersion)
    NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                   [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to reach %@.\n You should check your network.",
                                                                @"An error occured while trying to reach %@.\n You should check your network."),
                                              [versionFileURL absoluteString]],
                    @"Ok", nil, nil);
  else
  {
    NSArray* components = [currentVersion componentsSeparatedByString:@" "];
    if (components && [components count])
      currentVersion = [components objectAtIndex:0];

    NSString* thisVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    if (!thisVersion)
      thisVersion = @"";
    components = [thisVersion componentsSeparatedByString:@" "];
    if (components && [components count])
      thisVersion = [components objectAtIndex:0];

    int beta = (([components count] >= 3) && ([[components objectAtIndex:1] isEqualToString:@"beta"])) ?
                [[components objectAtIndex:2] intValue] : 0;

    NSComparisonResult comparison = [thisVersion compare:currentVersion options:NSCaseInsensitiveSearch|NSNumericSearch];
    if (sender && (comparison == NSOrderedSame) && (beta > 0))
      comparison = NSOrderedAscending;

    if (sender && (comparison == NSOrderedSame))
      NSRunAlertPanel(NSLocalizedString(@"Check for new versions", @"Check for new versions"),
                      NSLocalizedString(@"Your version of LaTeXiT is up-to-date", @"Your version of LaTeXiT is up-to-date"),

                      @"Ok", nil, nil);
    else if (sender && (comparison == NSOrderedDescending))
      NSRunAlertPanel(NSLocalizedString(@"Check for new versions", @"Check for new versions"),
                      NSLocalizedString(@"Your version of LaTeXiT is more recent than the official available one",
                                        @"Your version of LaTeXiT is more recent than the official available one"),
                      @"Ok", nil, nil);
    else if (comparison == NSOrderedAscending)
    {
      int choice = NSRunAlertPanel(NSLocalizedString(@"Check for new versions", @"Check for new versions"),
                                   NSLocalizedString(@"A new version of LaTeXiT is available",
                                                     @"A new version of LaTeXiT is available"),
                                   NSLocalizedString(@"Open download page", @"Open download page"),
                                   NSLocalizedString(@"Cancel", @"Cancel"), nil);
      if (choice == NSAlertDefaultReturn)
        [self openWebSite:self];
    }
  }//end if network ok
}

-(IBAction) exportImage:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document exportImage:sender];
}

-(IBAction) makeLatex:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [[document makeLatexButton] performClick:self];
}

-(IBAction) displayLog:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document displayLastLog:sender];
}

//returns the preamble that should be used, according to the fact that color.sty is available or not
-(NSAttributedString*) preamble
{
  NSData* preambleData = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultPreambleAttributedKey];
  NSMutableAttributedString* preamble = [[NSMutableAttributedString alloc] initWithRTF:preambleData documentAttributes:NULL];
  NSString* preambleString = [preamble string];
  if (!isColorStyAvailable)
  {
    NSRange pdftexColorRange = [preambleString rangeOfString:@"{color}"];
    if (pdftexColorRange.location != NSNotFound)
      [preamble insertAttributedString:[[[NSAttributedString alloc] initWithString:@"%"] autorelease]
                               atIndex:pdftexColorRange.location];
  }
  return [preamble autorelease];
}

-(BOOL) isGsAvailable
{
  return isGsAvailable;
}

-(BOOL) isDvipdfAvailable
{
  return isDvipdfAvailable;
}

-(BOOL) isPdfLatexAvailable
{
  return isPdfLatexAvailable;
}

-(BOOL) isPs2PdfAvailable
{
  return isPs2PdfAvailable;
}

-(BOOL) isXeLatexAvailable
{
  return isXeLatexAvailable;
}

-(BOOL) isLatexAvailable
{
  return isLatexAvailable;
}

-(BOOL) isColorStyAvailable
{
  return isColorStyAvailable;
}

//try to find gs program, searching by its name
-(void) _findGsPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* gsPath             = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[gsPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:gsPath])
    gsPath = [self findUnixProgram:@"gs" tryPrefixes:prefixes environment:environmentDict];
  if ([fileManager fileExistsAtPath:gsPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:gsPath forKey:CompositionConfigurationGsPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}

//try to find pdflatex program, searching by its name
-(void) _findPdfLatexPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* pdfLatexPath       = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPdfLatexPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[pdfLatexPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:pdfLatexPath])
    pdfLatexPath = [self findUnixProgram:@"pdflatex" tryPrefixes:prefixes environment:environmentDict];
  if ([fileManager fileExistsAtPath:pdfLatexPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:pdfLatexPath forKey:CompositionConfigurationPdfLatexPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}

//try to find pdflatex program, searching by its name
-(void) _findPs2PdfPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* ps2PdfPath         = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPs2PdfPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[ps2PdfPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:ps2PdfPath])
    ps2PdfPath = [self findUnixProgram:@"ps2pdf" tryPrefixes:prefixes environment:environmentDict];
  if ([fileManager fileExistsAtPath:ps2PdfPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:ps2PdfPath forKey:CompositionConfigurationPs2PdfPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}

//try to find xelatex program, searching by its name
-(void) _findXeLatexPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* xeLatexPath        = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationXeLatexPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[xeLatexPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:xeLatexPath])
    xeLatexPath = [self findUnixProgram:@"xelatex" tryPrefixes:prefixes environment:environmentDict];
  if ([fileManager fileExistsAtPath:xeLatexPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:xeLatexPath forKey:CompositionConfigurationXeLatexPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}

//try to find latex program, searching by its name
-(void) _findLatexPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* latexPath          = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationLatexPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[latexPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:latexPath])
    latexPath = [self findUnixProgram:@"latex" tryPrefixes:prefixes environment:environmentDict];
  if ([fileManager fileExistsAtPath:latexPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:latexPath forKey:CompositionConfigurationLatexPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}

//try to find dvipdf program, searching by its name
-(void) _findDvipdfPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* dvipdfPath         = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationDvipdfPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[dvipdfPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:dvipdfPath])
    dvipdfPath = [self findUnixProgram:@"dvipdf" tryPrefixes:prefixes environment:environmentDict];
  if ([fileManager fileExistsAtPath:dvipdfPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:dvipdfPath forKey:CompositionConfigurationDvipdfPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}

//check if gs work as expected. The user may have given a name different from "gs"
-(BOOL) _checkGs
{
  BOOL ok = YES;
  NSTask* gsTask = [[NSTask alloc] init];
  @try
  {
    //currently, the only check is the option -v, at least to see if the program can be executed
    ok = (system([[NSString stringWithFormat:@"%@ -v 1>/dev/null 2>/dev/null",
                   [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey]] UTF8String]) == 0);
    /*
    NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
    [gsTask setLaunchPath:[userDefaults stringForKey:GsPathKey]];
    [gsTask setArguments:[NSArray arrayWithObject:@"-v"]];
    [gsTask setStandardOutput:nullDevice];
    [gsTask setStandardError:nullDevice];
    [gsTask launch];
    [gsTask waitUntilExit];
    ok = ([gsTask terminationStatus] == 0);*/
  }
  @catch(NSException* e)
  {
    ok = NO;
  }
  @finally
  {
    [gsTask release];
  }
  return ok;
}

//check if pdflatex works as expected. The user may have given a name different from "pdflatex"
-(BOOL) _checkPdfLatex
{
  BOOL ok = YES;
  NSTask* pdfLatexTask = [[NSTask alloc] init];
  @try
  {
    //currently, the only check is the option -v, at least to see if the program can be executed
    ok = (system([[NSString stringWithFormat:@"%@ -v 1>/dev/null 2>/dev/null",
                   [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPdfLatexPathKey]] UTF8String]) == 0);
    /*
    NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
    [pdfLatexTask setLaunchPath:[userDefaults stringForKey:PdfLatexPathKey]];
    [pdfLatexTask setArguments:[NSArray arrayWithObject:@"-v"]];
    [pdfLatexTask setStandardOutput:nullDevice];
    [pdfLatexTask setStandardError:nullDevice];
    [pdfLatexTask launch];
    [pdfLatexTask waitUntilExit];
    ok = ([pdfLatexTask terminationStatus] == 0);*/
  }
  @catch(NSException* e)
  {
    ok = NO;
  }
  @finally
  {
    [pdfLatexTask release];
  }
  return ok;
}

//check if ps2pdf works as expected. The user may have given a name different from "ps2pdf"
-(BOOL) _checkPs2Pdf
{
  BOOL ok = YES;
  NSTask* ps2PdfTask = [[NSTask alloc] init];
  @try
  {
    //currently, the only check is the option -v, at least to see if the program can be executed
    ok = [[NSFileManager defaultManager]
            isExecutableFileAtPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPs2PdfPathKey]];
    /*NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
    [ps2PdfTask setLaunchPath:[userDefaults stringForKey:Ps2PdfPathKey]];
    [ps2PdfTask setArguments:[NSArray arrayWithObject:@"-v"]];
    [ps2PdfTask setStandardOutput:nullDevice];
    [ps2PdfTask setStandardError:nullDevice];
    [ps2PdfTask launch];
    [ps2PdfTask waitUntilExit];*/
  }
  @catch(NSException* e)
  {
    ok = NO;
  }
  @finally
  {
    [ps2PdfTask release];
  }
  return ok;
}

//check if xelatex works as expected. The user may have given a name different from "pdflatex"
-(BOOL) _checkXeLatex
{
  BOOL ok = YES;
  NSTask* xeLatexTask = [[NSTask alloc] init];
  @try
  {
    //currently, the only check is the option -v, at least to see if the program can be executed
    ok = (system([[NSString stringWithFormat:@"%@ -v 1>/dev/null 2>/dev/null",
                    [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationXeLatexPathKey]] UTF8String]) == 0);
    /*
    NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
    [xeLatexTask setLaunchPath:[userDefaults stringForKey:XeLatexPathKey]];
    [xeLatexTask setArguments:[NSArray arrayWithObject:@"-v"]];
    [xeLatexTask setStandardOutput:nullDevice];
    [xeLatexTask setStandardError:nullDevice];
    [xeLatexTask launch];
    [xeLatexTask waitUntilExit];
    ok = ([xeLatexTask terminationStatus] == 0);*/
  }
  @catch(NSException* e)
  {
    ok = NO;
  }
  @finally
  {
    [xeLatexTask release];
  }
  return ok;
}

//check if latex works as expected. The user may have given a name different from "pdflatex"
-(BOOL) _checkLatex
{
  BOOL ok = YES;
  NSTask* latexTask = [[NSTask alloc] init];
  @try
  {
    //currently, the only check is the option -v, at least to see if the program can be executed
    ok = (system([[NSString stringWithFormat:@"%@ -v 1>/dev/null 2>/dev/null",
                   [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationLatexPathKey]] UTF8String]) == 0);
    /*
    NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
    [latexTask setLaunchPath:[userDefaults stringForKey:LatexPathKey]];
    [latexTask setArguments:[NSArray arrayWithObject:@"-v"]];
    [latexTask setStandardOutput:nullDevice];
    [latexTask setStandardError:nullDevice];
    [latexTask launch];
    [latexTask waitUntilExit];
    ok = ([latexTask terminationStatus] == 0);*/
  }
  @catch(NSException* e)
  {
    ok = NO;
  }
  @finally
  {
    [latexTask release];
  }
  return ok;
}

//check if dvipdf works as expected. The user may have given a name different from "pdflatex"
-(BOOL) _checkDvipdf
{
  BOOL ok = YES;
  NSTask* dvipdfTask = [[NSTask alloc] init];
  @try
  {
    ok = [[NSFileManager defaultManager] isExecutableFileAtPath:
            [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationDvipdfPathKey]];
    /*    
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
    [dvipdfTask setLaunchPath:[userDefaults stringForKey:DvipdfPathKey]];
    [dvipdfTask setStandardOutput:nullDevice];
    [dvipdfTask setStandardError:nullDevice];
    [dvipdfTask launch];
    [dvipdfTask waitUntilExit];*/
  }
  @catch(NSException* e)
  {
    ok = NO;
  }
  @finally
  {
    [dvipdfTask release];
  }
  return ok;
}

//checks if color.sty is available, by compiling a simple latex string that uses it
-(BOOL) _checkColorSty
{
  BOOL ok = YES;
  NSTask* checkTask = [[NSTask alloc] init];
  
  //first try with kpsewhich
  @try
  {
    NSString* kpseWhichPath = [self findUnixProgram:@"kpsewhich" tryPrefixes:unixBins environment:environmentDict];
    ok = kpseWhichPath  && [kpseWhichPath length] &&
         (system([[NSString stringWithFormat:@"%@ %@ 1>/dev/null 2>/dev/null",kpseWhichPath,@"color.sty"] UTF8String]) == 0);
    /*
    if (ok)
    {
      NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
      NSString* directory       = [AppController latexitTemporaryPath];
      [checkTask setCurrentDirectoryPath:directory];
      [checkTask setLaunchPath:kpseWhichPath];
      [checkTask setArguments:[NSArray arrayWithObject:@"color.sty"]];
      [checkTask setStandardOutput:nullDevice];
      [checkTask setStandardError:nullDevice];
      [checkTask launch];
      [checkTask waitUntilExit];
      ok = ([checkTask terminationStatus] == 0);
    }*/
  }
  @catch(NSException* e)
  {
    ok = NO;
  }
  
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
      @try
      {
        NSString* testString = @"\\documentclass[10pt]{article}\\usepackage{color}\\begin{document}\\end{document}";
        NSString* directory      = [AppController latexitTemporaryPath];
        NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
        [checkTask setCurrentDirectoryPath:directory];
        NSString* launchPath = [PreferencesController currentCompositionConfigurationObjectForKey:pathKey];
        BOOL isDirectory = YES;
        if ([[NSFileManager defaultManager] fileExistsAtPath:launchPath isDirectory:&isDirectory] && !isDirectory)
        {
          [checkTask setLaunchPath:launchPath];
          [checkTask setArguments:[NSArray arrayWithObjects:@"--interaction", @"nonstopmode", testString, nil]];
          [checkTask setStandardOutput:nullDevice];
          [checkTask setStandardError:nullDevice];
          [checkTask launch];
          [checkTask waitUntilExit];
          ok = ([checkTask terminationStatus] == 0);
        }
      }
      @catch(NSException* e)
      {
        ok = NO;
      }
    }//end for each latex executable
  }//end if kpsewhich failed

  [checkTask release];
  return ok;
}

-(void) _checkConfiguration
{
  isGsAvailable       = [self _checkGs];
  isPdfLatexAvailable = [self _checkPdfLatex];
  isPs2PdfAvailable   = [self _checkPs2Pdf];
  isXeLatexAvailable  = [self _checkXeLatex];
  isLatexAvailable    = [self _checkLatex];
  isDvipdfAvailable   = [self _checkDvipdf];
  isColorStyAvailable = [self _checkColorSty];
}

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
    if ([item type] == LATEX_ITEM_TYPE_FUNCTION)
      string = [NSString stringWithFormat:@"%@{%@}", string, [myDocument selectedText]];
    [myDocument insertText:string];
  }
}

-(void) linkBackDidClose:(LinkBack*)link
{
  NSArray* documents = [NSApp orderedDocuments];
  [documents makeObjectsPerformSelector:@selector(closeLinkBackLink:) withObject:link];
}

//a link back request will create a new document thanks to the available data, as historyItems
-(void) linkBackClientDidRequestEdit:(LinkBack*)link
{
  NSData* historyItemData = [[[link pasteboard] propertyListForType:LinkBackPboardType] linkBackAppData];
  NSArray* historyItems = [NSKeyedUnarchiver unarchiveObjectWithData:historyItemData];
  HistoryItem* historyItem = (historyItems && [historyItems count]) ? [historyItems objectAtIndex:0] : nil;
  MyDocument* currentDocument = (MyDocument*) [self currentDocument];
  if (!currentDocument)
    currentDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MyDocumentType" display:YES];
  if (currentDocument && historyItem)
  {
    [currentDocument setLinkBackLink:link];//automatically closes previous links
    [currentDocument applyHistoryItem:historyItem]; //defines the state of the document
    [NSApp activateIgnoringOtherApps:YES];
    NSArray* windows = [currentDocument windowControllers];
    NSWindow* window = [[windows lastObject] window];
    [currentDocument setDocumentTitle:NSLocalizedString(@"Equation linked with another application",
                                                        @"Equation linked with another application")];
    [window makeKeyAndOrderFront:self];
    [window makeFirstResponder:[currentDocument sourceTextView]];
  }
}

//when the app is launched, the first document appears, then a dialog box can indicate if pdflatex and gs
//have been found or not. Then, the user has the ability to manually find them
//as delegate, no need to register for a notification
-(void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
  [LinkBack publishServerWithName:[NSApp applicationName] delegate:self];

  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  if (!isGsAvailable)
    [self _findGsPath];
  BOOL retry = YES;
  while (!isGsAvailable && retry)
  {
    int returnCode =
      NSRunAlertPanel(
        [NSString stringWithFormat:
          NSLocalizedString(@"%@ not found or not working as expected", @"%@ not found or not working as expected"),
          @"gs"],
        [NSString stringWithFormat:
          NSLocalizedString(@"The current configuration of LaTeXiT requires %@ to work.",
                            @"The current configuration of LaTeXiT requires %@ to work."),
          @"Ghostscript (gs)"],
        [NSString stringWithFormat:NSLocalizedString(@"Find %@...", @"Find %@..."), @"gs"],
        @"Cancel", nil);
    retry &= (returnCode == NSAlertDefaultReturn);
    if (returnCode == NSAlertDefaultReturn)
    {
      NSFileManager* fileManager = [NSFileManager defaultManager];
      NSOpenPanel* openPanel = [NSOpenPanel openPanel];
      [openPanel setResolvesAliases:NO];
      int ret2 = [openPanel runModalForDirectory:@"/usr" file:nil types:nil];
      BOOL ok = (ret2 == NSOKButton) && ([[openPanel filenames] count]);
      if (ok)
      {
        NSString* filepath = [[openPanel filenames] objectAtIndex:0];
        if ([fileManager fileExistsAtPath:filepath])
        {
          [self _addInEnvironmentPath:[filepath stringByDeletingLastPathComponent]];
          [PreferencesController currentCompositionConfigurationSetObject:filepath forKey:CompositionConfigurationGsPathKey];
          [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
          retry &= !isGsAvailable;
        }
      }
    }
  }

  if (!isPdfLatexAvailable)
    [self _findPdfLatexPath];
  retry = YES;
  while (!isPdfLatexAvailable && retry)
  {
    int returnCode =
      NSRunAlertPanel(
        [NSString stringWithFormat:
          NSLocalizedString(@"%@ not found or not working as expected", @"%@ not found or not working as expected"),
          @"pdflatex"],
        [NSString stringWithFormat:
          NSLocalizedString(@"The current configuration of LaTeXiT requires %@ to work.",
                            @"The current configuration of LaTeXiT requires %@ to work."),
          @"pdflatex"],
        [NSString stringWithFormat:NSLocalizedString(@"Find %@...", @"Find %@..."), @"pdflatex"],
        @"Cancel", nil);
    retry &= (returnCode == NSAlertDefaultReturn);
    if (returnCode == NSAlertDefaultReturn)
    {
      NSFileManager* fileManager = [NSFileManager defaultManager];
      NSOpenPanel* openPanel = [NSOpenPanel openPanel];
      [openPanel setResolvesAliases:NO];
      int ret2 = [openPanel runModalForDirectory:@"/usr" file:nil types:nil];
      BOOL ok = (ret2 == NSOKButton) && ([[openPanel filenames] count]);
      if (ok)
      {
        NSString* filepath = [[openPanel filenames] objectAtIndex:0];
        if ([fileManager fileExistsAtPath:filepath])
        {
          [self _addInEnvironmentPath:[filepath stringByDeletingLastPathComponent]];
          [PreferencesController currentCompositionConfigurationSetObject:filepath forKey:CompositionConfigurationPdfLatexPathKey];
          [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
          retry &= !isPdfLatexAvailable;
        }
      }
    }
  }

  if (!isPs2PdfAvailable)
    [self _findPs2PdfPath];
  retry = YES;
  while (!isPs2PdfAvailable && retry)
  {
    int returnCode =
      NSRunAlertPanel(
        [NSString stringWithFormat:
          NSLocalizedString(@"%@ not found or not working as expected", @"%@ not found or not working as expected"),
          @"ps2pdf"],
        [NSString stringWithFormat:
          NSLocalizedString(@"You need ps2pdf to export as \"PDF with outlined fonts\"",
                            @"You need ps2pdf to export as \"PDF with outlined fonts\""),
          @"pdflatex"],
        [NSString stringWithFormat:NSLocalizedString(@"Find %@...", @"Find %@..."), @"ps2pdf"],
        @"Cancel", nil);
    retry &= (returnCode == NSAlertDefaultReturn);
    if (returnCode == NSAlertDefaultReturn)
    {
      NSFileManager* fileManager = [NSFileManager defaultManager];
      NSOpenPanel* openPanel = [NSOpenPanel openPanel];
      [openPanel setResolvesAliases:NO];
      int ret2 = [openPanel runModalForDirectory:@"/usr" file:nil types:nil];
      BOOL ok = (ret2 == NSOKButton) && ([[openPanel filenames] count]);
      if (ok)
      {
        NSString* filepath = [[openPanel filenames] objectAtIndex:0];
        if ([fileManager fileExistsAtPath:filepath])
        {
          [self _addInEnvironmentPath:[filepath stringByDeletingLastPathComponent]];
          [PreferencesController currentCompositionConfigurationSetObject:filepath forKey:CompositionConfigurationPs2PdfPathKey];
          [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
          retry &= !isPs2PdfAvailable;
        }
      }
    }
  }

  if (!isDvipdfAvailable)
    [self _findDvipdfPath];
  NSNumber* compositionModeAsNumber = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationCompositionModeKey];
  retry = ((composition_mode_t)[compositionModeAsNumber intValue] == COMPOSITION_MODE_LATEXDVIPDF);
  while (!isDvipdfAvailable && retry)
  {
    int returnCode =
      NSRunAlertPanel(
        [NSString stringWithFormat:
          NSLocalizedString(@"%@ not found or not working as expected", @"%@ not found or not working as expected"),
          @"dvipdf"],
        [NSString stringWithFormat:
          NSLocalizedString(@"The current configuration of LaTeXiT requires %@ to work.",
                            @"The current configuration of LaTeXiT requires %@ to work."),
          @"dvipdf"],
        [NSString stringWithFormat:NSLocalizedString(@"Find %@...", @"Find %@..."), @"dvipdf"],
        @"Cancel", nil);
    retry &= (returnCode == NSAlertDefaultReturn);
    if (returnCode == NSAlertDefaultReturn)
    {
      NSFileManager* fileManager = [NSFileManager defaultManager];
      NSOpenPanel* openPanel = [NSOpenPanel openPanel];
      [openPanel setResolvesAliases:NO];
      int ret2 = [openPanel runModalForDirectory:@"/usr" file:nil types:nil];
      BOOL ok = (ret2 == NSOKButton) && ([[openPanel filenames] count]);
      if (ok)
      {
        NSString* filepath = [[openPanel filenames] objectAtIndex:0];
        if ([fileManager fileExistsAtPath:filepath])
        {
          [self _addInEnvironmentPath:[filepath stringByDeletingLastPathComponent]];
          [PreferencesController currentCompositionConfigurationSetObject:filepath forKey:CompositionConfigurationDvipdfPathKey];
          [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
          retry &= !isDvipdfAvailable;
        }
      }
    }
  }

  if (!isXeLatexAvailable)
    [self _findXeLatexPath];
  retry = ((composition_mode_t)[compositionModeAsNumber intValue] == COMPOSITION_MODE_XELATEX);
  while (!isXeLatexAvailable && retry)
  {
    int returnCode =
      NSRunAlertPanel(
        [NSString stringWithFormat:
          NSLocalizedString(@"%@ not found or not working as expected", @"%@ not found or not working as expected"),
          @"xelatex"],
        [NSString stringWithFormat:
          NSLocalizedString(@"The current configuration of LaTeXiT requires %@ to work.",
                            @"The current configuration of LaTeXiT requires %@ to work."),
          @"xelatex"],
        [NSString stringWithFormat:NSLocalizedString(@"Find %@...", @"Find %@..."), @"xelatex"],
        @"Cancel", nil);
    retry &= (returnCode == NSAlertDefaultReturn);
    if (returnCode == NSAlertDefaultReturn)
    {
      NSFileManager* fileManager = [NSFileManager defaultManager];
      NSOpenPanel* openPanel = [NSOpenPanel openPanel];
      [openPanel setResolvesAliases:NO];
      int ret2 = [openPanel runModalForDirectory:@"/usr" file:nil types:nil];
      BOOL ok = (ret2 == NSOKButton) && ([[openPanel filenames] count]);
      if (ok)
      {
        NSString* filepath = [[openPanel filenames] objectAtIndex:0];
        if ([fileManager fileExistsAtPath:filepath])
        {
          [self _addInEnvironmentPath:[filepath stringByDeletingLastPathComponent]];
          [PreferencesController currentCompositionConfigurationSetObject:filepath forKey:CompositionConfigurationXeLatexPathKey];
          [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
          retry &= !isXeLatexAvailable;
        }
      }
    }
  }

  if (!isLatexAvailable)
    [self _findLatexPath];
  retry = ((composition_mode_t)[compositionModeAsNumber intValue] == COMPOSITION_MODE_LATEXDVIPDF);
  while (!isLatexAvailable && retry)
  {
    int returnCode =
      NSRunAlertPanel(
        [NSString stringWithFormat:
          NSLocalizedString(@"%@ not found or not working as expected", @"%@ not found or not working as expected"),
          @"latex"],
        [NSString stringWithFormat:
          NSLocalizedString(@"The current configuration of LaTeXiT requires %@ to work.",
                            @"The current configuration of LaTeXiT requires %@ to work."),
          @"latex"],
        [NSString stringWithFormat:NSLocalizedString(@"Find %@...", @"Find %@..."), @"latex"],
        @"Cancel", nil);
    retry &= (returnCode == NSAlertDefaultReturn);
    if (returnCode == NSAlertDefaultReturn)
    {
      NSFileManager* fileManager = [NSFileManager defaultManager];
      NSOpenPanel* openPanel = [NSOpenPanel openPanel];
      [openPanel setResolvesAliases:NO];
      int ret2 = [openPanel runModalForDirectory:@"/usr" file:nil types:nil];
      BOOL ok = (ret2 == NSOKButton) && ([[openPanel filenames] count]);
      if (ok)
      {
        NSString* filepath = [[openPanel filenames] objectAtIndex:0];
        if ([fileManager fileExistsAtPath:filepath])
        {
          [self _addInEnvironmentPath:[filepath stringByDeletingLastPathComponent]];
          [PreferencesController currentCompositionConfigurationSetObject:filepath forKey:CompositionConfigurationLatexPathKey];
          [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
          retry &= !isLatexAvailable;
        }
      }
    }
  }
  
  if (isGsAvailable && (isPdfLatexAvailable || isLatexAvailable || isXeLatexAvailable) && !isColorStyAvailable)
    NSRunInformationalAlertPanel(NSLocalizedString(@"color.sty seems to be unavailable", @"color.sty seems to be unavailable"),
                                 NSLocalizedString(@"Without the color.sty package, you won't be able to change the font color",
                                                   @"Without the color.sty package, you won't be able to change the font color"),
                                 @"OK", nil, nil);
  if (isGsAvailable)
    [self _addInEnvironmentPath:[[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey] stringByDeletingLastPathComponent]];
  if (isPdfLatexAvailable)
    [self _addInEnvironmentPath:[[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPdfLatexPathKey] stringByDeletingLastPathComponent]];
  if (isPs2PdfAvailable)
    [self _addInEnvironmentPath:[[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPs2PdfPathKey] stringByDeletingLastPathComponent]];
  if (isXeLatexAvailable)
    [self _addInEnvironmentPath:[[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationXeLatexPathKey] stringByDeletingLastPathComponent]];
  if (isLatexAvailable)
    [self _addInEnvironmentPath:[[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationLatexPathKey] stringByDeletingLastPathComponent]];
  if (isDvipdfAvailable)
    [self _addInEnvironmentPath:[[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationDvipdfPathKey] stringByDeletingLastPathComponent]];

  [self _setEnvironment];

  //sets visible controllers  
  if ([userDefaults boolForKey:CompositionConfigurationControllerVisibleAtStartupKey])
    [[self compositionConfigurationController] showWindow:self];
  if ([userDefaults boolForKey:EncapsulationControllerVisibleAtStartupKey])
    [[self encapsulationController] showWindow:self];
  if ([userDefaults boolForKey:HistoryControllerVisibleAtStartupKey])
    [[self historyController] showWindow:self];
  if ([userDefaults boolForKey:LatexPalettesControllerVisibleAtStartupKey])
    [[self latexPalettesController] showWindow:self];
  if ([userDefaults boolForKey:LibraryControllerVisibleAtStartupKey])
    [[self libraryController] showWindow:self];
  if ([userDefaults boolForKey:MarginControllerVisibleAtStartupKey])
    [[self marginController] showWindow:self];
  [[[self currentDocument] windowForSheet] makeKeyAndOrderFront:self];
  
  //initialize system services
  [self changeServiceShortcuts];
  
  [NSThread detachNewThreadSelector:@selector(_triggerHistoryBackgroundLoading:) toTarget:self withObject:nil];
  
  if ([userDefaults boolForKey:CheckForNewVersionsKey])
    [NSApplication detachDrawingThread:@selector(checkUpdates:) toTarget:self withObject:nil];
}

-(void) serviceLatexisationEqnarray:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_EQNARRAY error:error];
}
-(void) serviceLatexisationDisplay:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_DISPLAY error:error];
}
-(void) serviceLatexisationInline:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_INLINE error:error];
}
-(void) serviceLatexisationText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:LATEX_MODE_TEXT error:error];
}
-(void) serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceMultiLatexisation:pboard userData:userData error:error];
}

//performs the application service
-(void) _serviceLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData mode:(latex_mode_t)mode
                       error:(NSString **)error
{
  if (!isPdfLatexAvailable || !isGsAvailable)
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
      NSArray* types = [pboard types];

      NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
      BOOL useColor     = [userDefaults boolForKey:ServiceRespectsColorKey];
      BOOL useBaseline  = [userDefaults boolForKey:ServiceRespectsBaselineKey];
      BOOL usePointSize = [userDefaults boolForKey:ServiceRespectsPointSizeKey];
      double defaultPointSize = [userDefaults floatForKey:DefaultPointSizeKey];
      
      //in the case of RTF input, we may deduce size, color, and change baseline
      if ([types containsObject:NSRTFPboardType])
      {
        NSAttributedString* attrString = [[[NSAttributedString alloc] initWithRTF:[pboard dataForType:NSRTFPboardType]
                                                               documentAttributes:NULL] autorelease];
        NSDictionary* contextAttributes = [attrString attributesAtIndex:0 effectiveRange:NULL];
        NSFont*  font  = usePointSize ? [contextAttributes objectForKey:NSFontAttributeName] : nil;
        float pointSize = font ? [font pointSize] : defaultPointSize;
        float magnification = pointSize;
        NSColor* color = useColor ? [contextAttributes objectForKey:NSForegroundColorAttributeName] : nil;
        if (!color) color = [NSColor colorWithData:[userDefaults objectForKey:DefaultColorKey]];
        NSNumber* originalBaseline = [contextAttributes objectForKey:NSBaselineOffsetAttributeName];
        if (!originalBaseline) originalBaseline = [NSNumber numberWithFloat:0.0];
        NSString* pboardString = [attrString string];
        NSString* preamble = [self insertColorInPreamble:[[self preamble] string] color:color];
        
        //calls the effective latexisation
        NSData* pdfData = [[self _myDocumentServiceProvider] latexiseWithPreamble:preamble body:pboardString color:color mode:mode
                                                                    magnification:magnification];

        //if it has worked, put back data in the service pasteboard
        if (pdfData)
        {
          //we will create the image file that will be attached to the rtfd
          NSString* directory          = [AppController latexitTemporaryPath];
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

          NSColor*  color              = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
          float     quality            = [userDefaults floatForKey:DragExportJpegQualityKey];
          NSString* attachedFile       = [NSString stringWithFormat:@"%@.%@", filePrefix, extension];
          NSString* attachedFilePath   = [directory stringByAppendingPathComponent:attachedFile];
          NSData*   attachedData       = [self dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality];
          
          //Now we must feed the pasteboard
          [pboard declareTypes:[NSArray array] owner:nil];

           //we try to make RTFD data only if the user wants to use the baseline, because there is
           //a side-effect : it "disables" LinkBack (can't click on an image embedded in RTFD)
          if (useBaseline)
          {
            //extracts the baseline of the equation, if possible
            NSMutableString* equationBaselineAsString = [NSMutableString stringWithString:@"0"];
            NSString* dataAsString = [[[NSString alloc] initWithData:pdfData encoding:NSASCIIStringEncoding] autorelease];
            NSArray*  testArray    = [dataAsString componentsSeparatedByString:@"/Baseline (EEbas"];
            if (testArray && ([testArray count] >= 2))
            {
              [equationBaselineAsString setString:[testArray objectAtIndex:1]];
              NSRange range = [equationBaselineAsString rangeOfString:@"EEbasend"];
              range.length  = (range.location != NSNotFound) ? [equationBaselineAsString length]-range.location : 0;
              [equationBaselineAsString deleteCharactersInRange:range];
            }
            
            float newBaseline = [originalBaseline floatValue];
            if (useBaseline)
              newBaseline -= [equationBaselineAsString floatValue];

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
            NSMutableAttributedString* space = [[[NSMutableAttributedString alloc] initWithString:@" "] autorelease];
            [space setAttributes:contextAttributes range:NSMakeRange(0, [space length])];
            [mutableAttributedStringWithImage appendAttributedString:space];

            //finally creates the rtdfData
            NSData* rtfdData = [mutableAttributedStringWithImage RTFDFromRange:NSMakeRange(0, [mutableAttributedStringWithImage length])
                                                            documentAttributes:nil];

            //RTFd data
            [pboard addTypes:[NSArray arrayWithObject:NSRTFDPboardType] owner:nil];
            [pboard setData:rtfdData forType:NSRTFDPboardType];
          }

          //LinkBack data
          HistoryItem* historyItem =
            [HistoryItem historyItemWithPDFData:pdfData preamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]
                                     sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                          color:color pointSize:pointSize date:[NSDate date] mode:mode backgroundColor:[NSColor whiteColor]];
          NSArray* historyItemArray = [NSArray arrayWithObject:historyItem];
          NSData* historyItemData = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
          NSDictionary* linkBackPlist = [NSDictionary linkBackDataWithServerName:[NSApp applicationName] appData:historyItemData];
          if ([userDefaults boolForKey:ServiceUsesHistoryKey])//we may add the item to the history
            [[HistoryManager sharedManager] addItem:historyItem];
        
          [pboard addTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:nil];
          [pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];
          
          //and additional data according to the export type (pdf, eps, tiff, jpeg, png...)
          if ([extension isEqualToString:@"pdf"])
          {
            [pboard addTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:nil];
            [pboard setData:pdfData forType:NSPDFPboardType];
          }
          else if ([extension isEqualToString:@"eps"])
          {
            [pboard addTypes:[NSArray arrayWithObject:NSPostScriptPboardType] owner:nil];
            [pboard setData:attachedData forType:NSPostScriptPboardType];
          }
          else if ([extension isEqualToString:@"tiff"] || [extension isEqualToString:@"jpeg"] || [extension isEqualToString:@"png"])
          {
            [pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            [pboard setData:attachedData forType:NSTIFFPboardType];
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
           [document setColor:color];
           [document setMagnification:magnification];
           [[document windowForSheet] makeFirstResponder:[document sourceTextView]];
           [document makeLatex:self];
          }
        }//end if pdfData (LaTeXisation has worked)
      }
      //if the input is not RTF but just string, we will use default color and size
      else if ([types containsObject:NSStringPboardType]
               #ifndef PANTHER
               || [types containsObject:NSPDFPboardType]
               #endif
              )
      {
        NSAttributedString* preamble = [self preamble];
        NSString* pboardString = nil;
        #ifndef PANTHER
        if ([types containsObject:NSPDFPboardType])
        {
          PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:[pboard dataForType:NSPDFPboardType]];
          pboardString = [pdfDocument string];
          [pdfDocument release];
        }
        #endif
        if (!pboardString)
          [pboard stringForType:NSStringPboardType];

        //performs effective latexisation
        NSData* pdfData = [[self _myDocumentServiceProvider] latexiseWithPreamble:[preamble string] body:pboardString
                                                                            color:[NSColor blackColor] mode:mode
                                                                    magnification:defaultPointSize];

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

          NSColor* color               = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
          float  quality               = [userDefaults floatForKey:DragExportJpegQualityKey];
          NSData*   data               = [self dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality];

          //now feed the pasteboard
          [pboard declareTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:nil];
                
          //LinkBack data
          HistoryItem* historyItem =
          [HistoryItem historyItemWithPDFData:pdfData
                                     preamble:preamble
                                   sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                        color:[NSColor blackColor]
                                    pointSize:defaultPointSize date:[NSDate date] mode:mode backgroundColor:[NSColor whiteColor]];
          NSArray* historyItemArray = [NSArray arrayWithObject:historyItem];
          NSData* historyItemData = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
          NSDictionary* linkBackPlist = [NSDictionary linkBackDataWithServerName:[NSApp applicationName] appData:historyItemData]; 
          [pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];
          if ([userDefaults boolForKey:ServiceUsesHistoryKey])//we may add the item to the history
            [[HistoryManager sharedManager] addItem:historyItem];
          
          //additional data according to the export type (pdf, eps, tiff, jpeg, png...)
          if ([extension isEqualToString:@"pdf"])
          {
            [pboard addTypes:[NSArray arrayWithObject:NSPDFPboardType] owner:nil];
            [pboard setData:data forType:NSPDFPboardType];
          }
          else if ([extension isEqualToString:@"eps"])
          {
            [pboard addTypes:[NSArray arrayWithObject:NSPostScriptPboardType] owner:nil];
            [pboard setData:data forType:NSPostScriptPboardType];
          }
          else if ([extension isEqualToString:@"tiff"] || [extension isEqualToString:@"jpeg"] || [extension isEqualToString:@"png"])
          {
            [pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
            [pboard setData:data forType:NSTIFFPboardType];
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
           [[document windowForSheet] makeFirstResponder:[document sourceTextView]];
           [document makeLatex:self];
          }
        }//end if pdfData (LaTeXisation has worked)
      }//end if not RTF
    }//end @synchronized(self)
  }//end if latexisation can be performed
}

-(void) _serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  if (!isPdfLatexAvailable || !isGsAvailable)
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
      NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
      BOOL useColor     = [userDefaults boolForKey:ServiceRespectsColorKey];
      BOOL useBaseline  = [userDefaults boolForKey:ServiceRespectsBaselineKey];
      BOOL usePointSize = [userDefaults boolForKey:ServiceRespectsPointSizeKey];
      double defaultPointSize = [userDefaults floatForKey:DefaultPointSizeKey];

      //the input must be RTF, so that we can insert images in it      
      //in the case of RTF input, we may deduce size, color, and change baseline
      NSAttributedString* attrString = [[[NSAttributedString alloc] initWithRTF:[pboard dataForType:NSRTFPboardType]
                                                             documentAttributes:NULL] autorelease];
      NSMutableAttributedString* mutableAttrString = [[attrString mutableCopy] autorelease];
      
      NSRange remainingRange = NSMakeRange(0, [mutableAttrString length]);
      int numberOfFailures = 0;

      //we must find some places where latexisations should be done. We look for "$$..$$", "\[..\]", and "$...$"
      NSArray* delimiters =
        [NSArray arrayWithObjects:
          [NSArray arrayWithObjects:@"$$", @"$$"  , [NSNumber numberWithInt:LATEX_MODE_DISPLAY], nil],
          [NSArray arrayWithObjects:@"\\[", @"\\]", [NSNumber numberWithInt:LATEX_MODE_DISPLAY], nil],
          [NSArray arrayWithObjects:@"$", @"$"    , [NSNumber numberWithInt:LATEX_MODE_INLINE],nil],
          nil];
          
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
            float pointSize = font ? [font pointSize] : defaultPointSize;
            float magnification = pointSize;
            NSColor* color = useColor ? [contextAttributes objectForKey:NSForegroundColorAttributeName] : nil;
            if (!color) color = [NSColor colorWithData:[userDefaults objectForKey:DefaultColorKey]];
            NSNumber* originalBaseline = [contextAttributes objectForKey:NSBaselineOffsetAttributeName];
            if (!originalBaseline) originalBaseline = [NSNumber numberWithFloat:0.0];
            NSString* body     = [string substringWithRange:rangeOfTextOfEquation];
            NSString* preamble = [self insertColorInPreamble:[[self preamble] string] color:color];

            //calls the effective latexisation
            NSData* pdfData = [[self _myDocumentServiceProvider] latexiseWithPreamble:preamble body:body color:color mode:mode
                                                                        magnification:magnification];
            //if it has worked, put back data in the attributedString. First, we get rid of the error case
            if (!pdfData)
            {
              ++numberOfFailures;
              remainingRange.location = end.location+delimiterRightLength;
              remainingRange.length = [mutableAttrString length]-remainingRange.location;
            }
            else
            {
              //we will create the image file that will be attached to the rtfd
              NSString* directory          = [AppController latexitTemporaryPath];
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

              NSColor*  color              = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
              float     quality            = [userDefaults floatForKey:DragExportJpegQualityKey];
              NSString* attachedFile       = [NSString stringWithFormat:@"%@.%@", filePrefix, extension];
              NSString* attachedFilePath   = [directory stringByAppendingPathComponent:attachedFile];
              NSData*   attachedData       = [self dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality];

              //extracts the baseline of the equation, if possible
              NSMutableString* equationBaselineAsString = [NSMutableString stringWithString:@"0"];
              NSString* dataAsString = [[[NSString alloc] initWithData:pdfData encoding:NSASCIIStringEncoding] autorelease];
              NSArray*  testArray    = [dataAsString componentsSeparatedByString:@"/Baseline (EEbas"];
              if (testArray && ([testArray count] >= 2))
              {
                [equationBaselineAsString setString:[testArray objectAtIndex:1]];
                NSRange range = [equationBaselineAsString rangeOfString:@"EEbasend"];
                range.length  = (range.location != NSNotFound) ? [equationBaselineAsString length]-range.location : 0;
                [equationBaselineAsString deleteCharactersInRange:range];
              }
                
              float newBaseline = [originalBaseline floatValue];
              if (useBaseline)
                newBaseline -= [equationBaselineAsString floatValue];

              //creates a mutable attributed string containing the image file
              [attachedData writeToFile:attachedFilePath atomically:NO];
              NSFileWrapper*      fileWrapperOfImage        = [[[NSFileWrapper alloc] initWithPath:attachedFilePath] autorelease];
              NSTextAttachment*   textAttachmentOfImage     = [[[NSTextAttachment alloc] initWithFileWrapper:fileWrapperOfImage] autorelease];
              NSAttributedString* attributedStringWithImage = [NSAttributedString attributedStringWithAttachment:textAttachmentOfImage];
              NSMutableAttributedString* mutableAttributedStringWithImage = [[attributedStringWithImage mutableCopy] autorelease];
                  
              //changes the baseline of the attachment to align it with the surrounding text
              [mutableAttributedStringWithImage addAttribute:NSBaselineOffsetAttributeName
                                                       value:[NSNumber numberWithFloat:newBaseline]
                                                       range:NSMakeRange(0, [mutableAttributedStringWithImage length])];
                
              //add a space after the image, to restore the baseline of the surrounding text
              //Gee! It works with TextEdit but not with Pages. That is to say, in Pages, if I put this space, the baseline of
              //the equation is reset. And if do not put this space, the cursor stays in "tuned baseline" mode.
              //However, it works with Nisus Writer Express, so that I think it is a bug in Pages
              NSMutableAttributedString* space = [[[NSMutableAttributedString alloc] initWithString:@" "] autorelease];
              [space setAttributes:contextAttributes range:NSMakeRange(0, [space length])];
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
        NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), message, NSLocalizedString(@"Ok", @"Ok"), nil, nil);
      }
      
      //Now we must feed the pasteboard
      NSData* rtfdData = [mutableAttrString RTFDFromRange:NSMakeRange(0, [mutableAttrString length]) documentAttributes:nil];
      [pboard declareTypes:[NSArray arrayWithObject:NSRTFDPboardType] owner:nil];
      [pboard setData:rtfdData forType:NSRTFDPboardType];
    }//end @synchronized(self)
  }//end if latexisation can be performed
}

-(IBAction) showPreferencesPane:(id)sender
{
  if (!preferencesController)
    preferencesController = [[PreferencesController alloc] init];
  NSWindow* window = [preferencesController window];
  [window makeKeyAndOrderFront:self];
}

-(void) showPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier//showPreferencesPane + select one pane
{
  [self showPreferencesPane:self];
  [preferencesController selectPreferencesPaneWithItemIdentifier:itemIdentifier];
}

-(IBAction) showHelp:(id)sender
{
  NSString* string = [readmeTextView string];
  if (!string || ![string length])
  {
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* file = [mainBundle pathForResource:NSLocalizedString(@"Read Me", @"Read Me") ofType:@"rtfd"];
    [readmeTextView readRTFDFromFile:file];
  }
  if (![readmeWindow isVisible])
    [readmeWindow center];
  [readmeWindow makeKeyAndOrderFront:self];
}

//if a path has changed in the preferences, pdflatex may become [un]available, so we must update
//the "Latexise" button of the documents
-(void) _somePathDidChangeNotification:(NSNotification *)aNotification
{
  [self _checkConfiguration];
  NSArray* documents = [NSApp orderedDocuments];
  [documents makeObjectsPerformSelector:@selector(updateAvailabilities:) withObject:nil];
}

//modifies the \usepackage{color} line of the preamble to use the given color
-(NSString*) insertColorInPreamble:(NSString*)thePreamble color:(NSColor*)theColor
{
  NSColor* color = theColor ? theColor : [NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:0];
  color = [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
  float rgba[4] = {0};
  [color getRed:&rgba[0] green:&rgba[1] blue:&rgba[2] alpha:&rgba[3]];
  NSString* colorString =
    [NSString stringWithFormat:@"\\color[rgb]{%1.3f,%1.3f,%1.3f}", rgba[0], rgba[1], rgba[2]];
  NSMutableString* preamble = [NSMutableString stringWithString:thePreamble];
  NSRange colorRange = [preamble rangeOfString:@"{color}"];
  if (colorRange.location == NSNotFound)
    colorRange = [preamble rangeOfString:@"[pdftex]{color}"]; //because of old versions of LaTeXiT
  if ([self isColorStyAvailable])
  {
    if (colorRange.location != NSNotFound)
    {
      //int insertionPoint = pdftexColorRange.location+pdftexColorRange.length;
      //[preamble insertString:colorString atIndex:insertionPoint];
      colorString = [NSString stringWithFormat:@"{color}%@", colorString];
      [preamble replaceCharactersInRange:colorRange withString:colorString];
    }
    else //try to find a good place of insertion
    {
      colorString = [NSString stringWithFormat:@"{color}%@", colorString];
      NSRange firstUsePackage = [preamble rangeOfString:@"\\usepackage"];
      if (firstUsePackage.location != NSNotFound)
        [preamble insertString:colorString atIndex:firstUsePackage.location];
      else
        [preamble appendString:colorString];
    }
  }//end insert color

  return preamble;
}

//returns data representing data derived from pdfData, but in the format specified (pdf, eps, tiff, png...)
-(NSData*) dataForType:(export_format_t)format pdfData:(NSData*)pdfData
             jpegColor:(NSColor*)color jpegQuality:(float)quality
{
  NSData* data = nil;
  @synchronized(self) //only one person may ask that service at a time
  {
    //prepare file names
    NSString* directory      = [AppController latexitTemporaryPath];
    NSString* filePrefix     = [NSString stringWithFormat:@"latexit-controller"];
    NSString* pdfFile        = [NSString stringWithFormat:@"%@.pdf", filePrefix];
    NSString* pdfFilePath    = [directory stringByAppendingPathComponent:pdfFile];
    NSString* tmpEpsFile     = [NSString stringWithFormat:@"%@-2.eps", filePrefix];
    NSString* tmpEpsFilePath = [directory stringByAppendingPathComponent:tmpEpsFile];
    NSString* tmpPdfFile     = [NSString stringWithFormat:@"%@-2.pdf", filePrefix];
    NSString* tmpPdfFilePath = [directory stringByAppendingPathComponent:tmpPdfFile];

    if (pdfData)
    {
      if (format == EXPORT_FORMAT_PDF)
      {
        data = pdfData;
      }
      else if (format == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      {
        [pdfData writeToFile:pdfFilePath atomically:NO];
        NSString* gsPath       = [self findUnixProgram:@"gs" tryPrefixes:unixBins environment:environmentDict];
        NSString* epstopdfPath = [self findUnixProgram:@"ps2pdf" tryPrefixes:unixBins environment:environmentDict];
        if (![gsPath isEqualToString:@""] && ![epstopdfPath isEqualToString:@""])
        {
          NSString* systemCall =
            [NSString stringWithFormat:
              @"%@ -sDEVICE=pswrite -dNOCACHE -sOutputFile=- -q -dbatch -dNOPAUSE -dQUIET %@ -c quit | %@ - %@ 1>/dev/null 2>/dev/null",
              gsPath, pdfFilePath, epstopdfPath, tmpPdfFilePath];
          int error = system([systemCall UTF8String]);
          if (error)
          {
            NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                            [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file with command:\n%@",
                                                                         @"An error occured while trying to create the file with command:\n%@"),
                                                       systemCall],
                            @"Ok", nil, nil);
          }
          else
            data = [NSData dataWithContentsOfFile:tmpPdfFilePath];
        }
      }
      else if (format == EXPORT_FORMAT_EPS)
      {
        [pdfData writeToFile:pdfFilePath atomically:NO];
        NSFileHandle* nullDevice = [NSFileHandle fileHandleWithNullDevice];
        NSTask* gsTask = [[NSTask alloc] init];
        NSPipe* errorPipe = [NSPipe pipe];
        NSMutableString* errorString = [NSMutableString string];
        @try
        {
          [gsTask setCurrentDirectoryPath:directory];
          [gsTask setEnvironment:environmentDict];
          [gsTask setLaunchPath:[self findUnixProgram:@"gs" tryPrefixes:unixBins environment:[gsTask environment]]];
          [gsTask setArguments:[NSArray arrayWithObjects:@"-dNOPAUSE", @"-dNOCACHE", @"-dBATCH", @"-sDEVICE=epswrite",
                                                         [NSString stringWithFormat:@"-sOutputFile=%@", tmpEpsFilePath],
                                                         pdfFilePath, nil]];
          [gsTask setStandardOutput:nullDevice];
          [gsTask setStandardError:errorPipe];
          [gsTask launch];
          [gsTask waitUntilExit];
        }
        @catch(NSException* e)
        {
          [errorString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", [e name], [e reason]]];
        }
        @finally
        {
          NSData*   errorData   = [[errorPipe fileHandleForReading] availableData];
          [errorString appendString:[[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] autorelease]];

          if ([gsTask terminationStatus] != 0)
          {
            NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                            [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file :\n%@",
                                                                         @"An error occured while trying to create the file :\n%@"),
                                                       errorString],
                            @"Ok", nil, nil);
          }
          [gsTask release];
        }
        data = [NSData dataWithContentsOfFile:tmpEpsFilePath];
      }
      else if (format == EXPORT_FORMAT_TIFF)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentation];
        [image release];
      }
      else if (format == EXPORT_FORMAT_PNG)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:15.0];
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:data];
        data = [imageRep representationUsingType:NSPNGFileType properties:nil];
        [image release];
      }
      else if (format == EXPORT_FORMAT_JPEG)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        NSSize size = [image size];
        NSImage* opaqueImage = [[NSImage alloc] initWithSize:size];
        NSRect rect = NSMakeRect(0, 0, size.width, size.height);
        [opaqueImage lockFocus];
          [color set];
          NSRectFill(rect);
          [image drawInRect:rect fromRect:rect operation:NSCompositeSourceOver fraction:1.0];
        [opaqueImage unlockFocus];
        data = [opaqueImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:15.0];
        [opaqueImage release];
        NSBitmapImageRep *opaqueImageRep = [NSBitmapImageRep imageRepWithData:data];
        NSDictionary* properties =
          [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:quality/100], NSImageCompressionFactor, nil];
        data = [opaqueImageRep representationUsingType:NSJPEGFileType properties:properties];
        [image release];
      }
    }//end if pdfData available
  }//end @synchronized
  return data;
}

//returns a file icon to represent the given PDF data; if not specified (nil), the backcground color will be half-transparent
-(NSImage*) makeIconForData:(NSData*)pdfData backgroundColor:(NSColor*)backgroundColor
{
  NSImage* icon = nil;
  NSImage* image = [[[NSImage alloc] initWithData:pdfData] autorelease];
  NSSize imageSize = [image size];
  icon = [[[NSImage alloc] initWithSize:NSMakeSize(128, 128)] autorelease];
  NSRect imageRect = NSMakeRect(0, 0, imageSize.width, imageSize.height);
  NSRect srcRect = imageRect;
  if (imageRect.size.width >= imageRect.size.height)
    srcRect.size.width = MIN(srcRect.size.width, 2*srcRect.size.height);
  else
    srcRect.size.height = MIN(srcRect.size.height, 2*srcRect.size.width);
  srcRect.origin.y = imageSize.height-srcRect.size.height;

  float marginX = (srcRect.size.height > srcRect.size.width ) ? ((srcRect.size.height - srcRect.size.width )/2)*128/srcRect.size.height : 0;
  float marginY = (srcRect.size.width  > srcRect.size.height) ? ((srcRect.size.width  - srcRect.size.height)/2)*128/srcRect.size.width  : 0;
  NSRect dstRect = NSMakeRect(marginX, marginY, 128-2*marginX, 128-2*marginY);
  if (!backgroundColor)
    backgroundColor = [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:0.25];
  [icon lockFocus];
    [backgroundColor set];
    NSRectFill(NSMakeRect(0, 0, 128, 128));
    [image drawInRect:dstRect fromRect:srcRect operation:NSCompositeSourceOver fraction:1];
    if (imageSize.width > 2*imageSize.height) //if the equation is truncated, adds <...>
    {
      NSRectFill(NSMakeRect(100, 0, 28, 128));
      [[NSColor blackColor] set];
      [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(102, 56, 6, 6)] fill];
      [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(112, 56, 6, 6)] fill];
      [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(122, 56, 6, 6)] fill];
    }
    else if (imageSize.height > 2*imageSize.width)
    {
      NSRectFill(NSMakeRect(0, 0, 128, 16));
      [[NSColor blackColor] set];
      [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(51, 5, 6, 6)] fill];
      [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(61, 5, 6, 6)] fill];
      [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(71, 5, 6, 6)] fill];
    }
  [icon unlockFocus];
  return icon;
}

//application delegate methods
-(BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename
{
  BOOL ok = NO;
  NSString* type = [[filename pathExtension] lowercaseString];
  if (![type isEqualTo:@"latexlib"])
    ok = ([[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:filename display:YES] != nil);
  else
  {
    NSString* title =
      [NSString stringWithFormat:NSLocalizedString(@"Do you want to load the library <%@> ?", @"Do you want to load the library <%@> ?"),
                                 [[filename pathComponents] lastObject]];
    int confirm = NSRunAlertPanel(title, NSLocalizedString(@"The current library will be lost", @"The current library will be lost"),
                                  NSLocalizedString(@"Load the library", @"Load the library"), NSLocalizedString(@"Cancel", @"Cancel"), nil);
    if (confirm == NSAlertDefaultReturn)
      ok = [[LibraryManager sharedManager] loadFrom:filename];
    else
      ok = YES;
  }
  return ok;
}

-(NSData*) annotatePdfDataInLEEFormat:(NSData*)data preamble:(NSString*)preamble source:(NSString*)source color:(NSColor*)color
                                 mode:(mode_t)mode magnification:(double)magnification baseline:(double)baseline
                                 backgroundColor:(NSColor*)backgroundColor
{
  NSMutableData* newData = nil;
  
  NSString* colorAsString   = [(color ? color : [NSColor blackColor]) rgbaString];
  NSString* bkColorAsString = [(backgroundColor ? backgroundColor : [NSColor whiteColor]) rgbaString];
  if (data)
  {
    NSMutableString* replacedPreamble = [NSMutableString stringWithString:preamble];
    [replacedPreamble replaceOccurrencesOfString:@"\\" withString:@"ESslash"      options:0 range:NSMakeRange(0, [replacedPreamble length])];
    [replacedPreamble replaceOccurrencesOfString:@"{"  withString:@"ESleftbrack"  options:0 range:NSMakeRange(0, [replacedPreamble length])];
    [replacedPreamble replaceOccurrencesOfString:@"}"  withString:@"ESrightbrack" options:0 range:NSMakeRange(0, [replacedPreamble length])];
    [replacedPreamble replaceOccurrencesOfString:@"$"  withString:@"ESdollar"     options:0 range:NSMakeRange(0, [replacedPreamble length])];

    NSMutableString* replacedSource = [NSMutableString stringWithString:source];
    [replacedSource replaceOccurrencesOfString:@"\\" withString:@"ESslash"      options:0 range:NSMakeRange(0, [replacedSource length])];
    [replacedSource replaceOccurrencesOfString:@"{"  withString:@"ESleftbrack"  options:0 range:NSMakeRange(0, [replacedSource length])];
    [replacedSource replaceOccurrencesOfString:@"}"  withString:@"ESrightbrack" options:0 range:NSMakeRange(0, [replacedSource length])];
    [replacedSource replaceOccurrencesOfString:@"$"  withString:@"ESdollar"     options:0 range:NSMakeRange(0, [replacedSource length])];

    NSString* type = [[NSNumber numberWithInt:mode] stringValue];

    NSMutableString *annotation =
        [NSMutableString stringWithFormat:
          @"\nobj /Encoding /MacRomanEncoding <<\n"\
           "/Preamble (ESannop%sESannopend)\n"\
           "/Subject (ESannot%sESannotend)\n"\
           "/Type (EEtype%@EEtypeend)\n"\
           "/Color (EEcol%@EEcolend)\n"
           "/BKColor (EEbkc%@EEbkcend)\n"
           "/Magnification (EEmag%fEEmagend)\n"\
           "/Baseline (EEbas%fEEbasend)\n"\
           ">> endobj",
          [replacedPreamble cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
          [replacedSource   cStringUsingEncoding:NSMacOSRomanStringEncoding allowLossyConversion:YES],
          type, colorAsString, bkColorAsString, magnification, baseline];
          
    NSMutableString* pdfString = [[[NSMutableString alloc] initWithData:data encoding:NSASCIIStringEncoding] autorelease];
    
    NSRange r1 = [pdfString rangeOfString:@"\nxref" options:NSBackwardsSearch];
    NSRange r2 = [pdfString lineRangeForRange:[pdfString rangeOfString:@"startxref" options:NSBackwardsSearch]];

    NSString* tail_of_tail = [pdfString substringFromIndex:r2.location];
    NSArray*  tailarray    = [tail_of_tail componentsSeparatedByString:@"\n"];

    int byte_count = 0;
    NSScanner* scanner = [NSScanner scannerWithString:[tailarray objectAtIndex:1]];
    [scanner scanInt:&byte_count];
    byte_count += [annotation length];

    NSRange r3 = NSMakeRange(r1.location, r2.location - r1.location);
    NSString* stuff = [pdfString substringWithRange: r3];

    [annotation appendString:stuff];
    [annotation appendString:[NSString stringWithFormat: @"startxref\n%d\n%%%%EOF", byte_count]];
    
    NSData* dataToAppend = [annotation dataUsingEncoding:NSMacOSRomanStringEncoding/*NSASCIIStringEncoding*/ allowLossyConversion:YES];

    newData = [NSMutableData dataWithData:[data subdataWithRange:NSMakeRange(0, r1.location)]];
    [newData appendData:dataToAppend];
  }//end if data
  return newData;
}

//as the delegate, no need to register the notification
//When the application quits, the notification is caught to perform some saving
-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  BOOL visible = NO;

  visible = compositionConfigurationController && [[compositionConfigurationController window] isVisible];
  [userDefaults setBool:visible forKey:CompositionConfigurationControllerVisibleAtStartupKey];

  visible = encapsulationController && [[encapsulationController window] isVisible];
  [userDefaults setBool:visible forKey:EncapsulationControllerVisibleAtStartupKey];

  visible = latexPalettesController && [[latexPalettesController window] isVisible];
  [userDefaults setBool:visible forKey:LatexPalettesControllerVisibleAtStartupKey];

  visible = historyController && [[historyController window] isVisible];
  [userDefaults setBool:visible forKey:HistoryControllerVisibleAtStartupKey];

  visible = libraryController && [[libraryController window] isVisible];
  [userDefaults setBool:visible forKey:LibraryControllerVisibleAtStartupKey];

  visible = marginController && [[marginController window] isVisible];
  [userDefaults setBool:visible forKey:MarginControllerVisibleAtStartupKey];
}

//if the marginController is not loaded, just use the user defaults values
-(float) marginControllerTopMargin
{
  return marginController ? [marginController topMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalTopMarginKey];
}

-(float) marginControllerBottomMargin
{
  return marginController ? [marginController bottomMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalBottomMarginKey];
}

-(float) marginControllerLeftMargin
{
  return marginController ? [marginController leftMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalLeftMarginKey];
}

-(float) marginControllerRightMargin
{
  return marginController ? [marginController rightMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalRightMarginKey];
}

-(void) _triggerHistoryBackgroundLoading:(id)object //arg not used, but required for thread call
{
  NSAutoreleasePool* threadAutoreleasePool = [[NSAutoreleasePool alloc] init];
  [NSThread setThreadPriority:0];
  [HistoryManager sharedManager];
  [threadAutoreleasePool release];
}

-(void) changeServiceShortcuts
{
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSString* infoPlistPath =
    [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents"] stringByAppendingPathComponent:@"Info.plist"];
  NSURL* infoPlistURL = [NSURL fileURLWithPath:infoPlistPath];
  CFStringRef cfStringError = nil;
  CFPropertyListRef cfInfoPlist = CFPropertyListCreateFromXMLData(kCFAllocatorDefault,
                                                                  (CFDataRef)[NSData dataWithContentsOfURL:infoPlistURL],
                                                                  kCFPropertyListMutableContainersAndLeaves, &cfStringError);
  if (cfInfoPlist && !cfStringError)
  {
    NSMutableDictionary* infoPlist = (NSMutableDictionary*) cfInfoPlist;
    NSMutableArray* services = [infoPlist objectForKey:@"NSServices"];
    [services removeAllObjects];
    
    NSArray* shortcutStrings = [userDefaults arrayForKey:ServiceShortcutStringsKey];
    NSArray* shortcutEnabled = [userDefaults arrayForKey:ServiceShortcutEnabledKey];
    latex_mode_t latex_mode = LATEX_MODE_DISPLAY;
    for(latex_mode = LATEX_MODE_DISPLAY ; latex_mode <= LATEX_MODE_EQNARRAY ; ++latex_mode)
    {
      unsigned int index = indexOfLatexMode(latex_mode);
      NSString* menuItemName = (latex_mode == LATEX_MODE_EQNARRAY) ? @"LaTeXiT/Typeset LaTeX Maths eqnarray" :
                               (latex_mode == LATEX_MODE_DISPLAY)  ? @"LaTeXiT/Typeset LaTeX Maths display"  :
                               (latex_mode == LATEX_MODE_INLINE)   ? @"LaTeXiT/Typeset LaTeX Maths inline"   :
                               (latex_mode == LATEX_MODE_TEXT)     ? @"LaTeXiT/Typeset LaTeX Text"     : @"";
      NSString* serviceMessage = (latex_mode == LATEX_MODE_EQNARRAY) ? @"serviceLatexisationEqnarray" :
                                 (latex_mode == LATEX_MODE_DISPLAY)  ? @"serviceLatexisationDisplay"  :
                                 (latex_mode == LATEX_MODE_INLINE)   ? @"serviceLatexisationInline"   :
                                 (latex_mode == LATEX_MODE_TEXT)     ? @"serviceLatexisationText"     : @"";
      unsigned int count = MIN([shortcutStrings count], [shortcutEnabled count]);
      if (index<count)
      {
        NSString* shortcut =  (NSString*) [shortcutStrings objectAtIndex:index];
        BOOL      disable  = ![[shortcutEnabled objectAtIndex:index] boolValue];
        
        NSDictionary* serviceItemPlist = disable ? [NSDictionary dictionary] :
          [NSDictionary dictionaryWithObjectsAndKeys:
            [NSDictionary dictionaryWithObject:shortcut forKey:@"default"], @"NSKeyEquivalent",
            [NSDictionary dictionaryWithObject:menuItemName forKey:@"default"], @"NSMenuItem",
            serviceMessage, @"NSMessage",
            @"LaTeXiT", @"NSPortName",
            [NSArray arrayWithObjects:@"NSRTFDPboardType", @"NSPDFPboardType", @"NSPostScriptPboardType", @"NSTIFFPboardType", nil], @"NSReturnTypes",
            [NSArray arrayWithObjects:@"NSStringPboardType", @"NSRTFPboardType", @"NSPDFPboardType", nil], @"NSSendTypes",
            nil];
        [services insertObject:serviceItemPlist atIndex:latex_mode];
      }//end if index<count
    }//end for each latex mode
      
    //adds multi latexisation
    NSDictionary* serviceItemPlist = ![[shortcutEnabled objectAtIndex:4] boolValue] ? [NSDictionary dictionary] :
      [NSDictionary dictionaryWithObjectsAndKeys:
        [NSDictionary dictionaryWithObject:[shortcutStrings objectAtIndex:4] forKey:@"default"], @"NSKeyEquivalent",
        [NSDictionary dictionaryWithObject:@"LaTeXiT/Detect and typeset equations" forKey:@"default"], @"NSMenuItem",
        @"serviceMultiLatexisation", @"NSMessage",
        @"LaTeXiT", @"NSPortName",
        [NSArray arrayWithObject:@"NSRTFDPboardType"], @"NSReturnTypes",
        [NSArray arrayWithObject:@"NSRTFPboardType"], @"NSSendTypes",
        nil];
    [services addObject:serviceItemPlist];
    
    [infoPlist writeToURL:infoPlistURL atomically:YES];

  }//end if infoPlist
  CFRelease(cfInfoPlist);
}

-(void) startMessageProgress:(NSString*)message
{
  [[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(startMessageProgress:) withObject:message];
}

-(void) stopMessageProgress
{
  [[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(stopMessageProgress)];
}

@end
