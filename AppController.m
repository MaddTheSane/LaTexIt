//  AppController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005 PierreChatelier. All rights reserved.

//The AppController is a singleton, a unique instance that acts as a bridge between the menu and the documents.
//It is also responsible for shared operations (like utilities : finding a program)
//It is also a bridge for the application service : it creates a dummy, invisible document that will perform
//the latexisation
//It is also the LinkBack server

#import "AppController.h"

#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LibraryFile.h"
#import "LibraryManager.h"
#import "LineCountTextView.h"
#import "MyDocument.h"
#import "NSApplicationExtended.h"
#import "NSColorExtended.h"
#import "MarginController.h"
#import "PalettesController.h"
#import "PreferencesController.h"

@interface AppController (PrivateAPI)

//specialized quick version of findUnixProgram... that does not take environment in account.
//It only looks for the existence of the file in the given paths, but does not look more.
-(NSString*) findUnixProgram:(NSString*)programName inPrefixes:(NSArray*)prefixes;

-(void) _addInEnvironmentPath:(NSString*)path; //increase the environmentPath
-(void) _setEnvironment; //utility that calls setenv() with the current content of environmentPath

//check the configuration, updates isGsAvailable, isPdfLatexAvailable and isColorStyAvailable
-(void) _checkConfiguration;

-(BOOL) _checkGs;      //called by _checkConfiguration to check gs's presence
-(BOOL) _checkPdfLatex;//called by _checkConfiguration to check pdflatex's presence
-(BOOL) _checkColorSty;//called by _checkConfiguration to check color.sty's presence

//helper for the configuration
-(void) _findGsPath;
-(void) _findPdfLatexPath;

//some notifications that trigger some work
-(void) applicationDidFinishLaunching:(NSNotification *)aNotification;
-(void) windowDidBecomeMain:(NSNotification *)aNotification;
-(void) _somePathDidChangeNotification:(NSNotification *)aNotification;

//private method factorizing the work of the different application service calls
-(MyDocument*) _myDocumentServiceProvider;
-(void) _serviceLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData mode:(latex_mode_t)mode
                       error:(NSString **)error;

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
static NSArray* unixBins = nil;

+(void) initialize
{
  //Yes, it seems ugly, but I need it to force the user defaults to be initialized
  [PreferencesController initialize];
  
  //usual unix PATH (to find latex)
  if (!unixBins)
    unixBins = [[NSArray alloc] initWithObjects:@"/bin", @"/sbin",
      @"/usr/bin", @"/usr/sbin",
      @"/usr/local/bin", @"/usr/local/sbin",
      @"/sw/bin", @"/sw/sbin",
      @"/sw/usr/bin", @"/sw/usr/sbin",
      @"/sw/local/bin", @"/sw/local/sbin",
      @"/sw/usr/local/bin", @"/sw/usr/local/sbin",
      @"/usr/local/teTeX/bin/powerpc-apple-darwin-current",
      nil];

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

  //creates the unique instance of AppController
  if (!appControllerInstance)
    appControllerInstance = [[[self class] alloc] init];
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
  return appControllerInstance;
}

-(id) init
{
  if (appControllerInstance) //do not build more than one appController
    return [appControllerInstance retain]; //but retain to allow release
  else
  {
    self = [super init];
    if (self)
    {
      [self _setEnvironment];     //performs a setenv()
      [self _checkConfiguration]; //mainly, looks for pdflatex program
      
      //export to EPS needs ghostscript to be available
      NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
      NSString* exportType = [userDefaults stringForKey:DragExportTypeKey];
      if ([exportType isEqualTo:@"EPS"] && !isGsAvailable)
        [userDefaults setObject:@"PDF" forKey:DragExportTypeKey];
      
      NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
      [notificationCenter addObserver:self selector:@selector(applicationDidFinishLaunching:)
                                               name:NSApplicationDidFinishLaunchingNotification object:nil];
      [notificationCenter addObserver:self selector:@selector(_somePathDidChangeNotification:)
                                               name:SomePathDidChangeNotification object:nil];
      [notificationCenter addObserver:self selector:@selector(windowDidBecomeMain:)
                                               name:NSWindowDidBecomeMainNotification object:nil];

       //declares the service. The service will be called on a dummy document (myDocumentServiceProvider), which is lazily created
       //when first used
       [NSApp setServicesProvider:self];
       NSUpdateDynamicServices();
    }
    return self;
  }
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [marginController release];
  [palettesController release];
  [preferencesController release];
  [super dealloc];
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

-(BOOL) validateMenuItem:(NSMenuItem*)sender
{
  BOOL ok = YES;
  if ([sender action] == @selector(exportImage:))
  {
    MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [myDocument hasImage];
  }
  else if ([sender action] == @selector(makeLatex:))
  {
    MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [self isPdfLatexAvailable];
  }
  else if ([sender action] == @selector(showOrHidePreamble:))
  {
    MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy];
  }
  else if ([sender action] == @selector(showOrHideHistory:))
  {
    MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy];
  }
  else if ([sender action] == @selector(showOrHideLibrary:))
  {
    MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy];
  }
  else if ([sender action] == @selector(removeHistoryEntries:))
  {
    MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
    ok = (myDocument != nil) && ([[myDocument selectedHistoryItems] count]) && ![myDocument isBusy];
  }
  else if ([sender action] == @selector(removeLibraryItems:))
  {
    MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
    ok = (myDocument != nil) && ([[myDocument selectedLibraryItems] count]) && ![myDocument isBusy];
  }
  else if ([sender action] == @selector(refreshLibraryItems:))
  {
    MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
    NSArray* selectedLibraryItems = [myDocument selectedLibraryItems];
    BOOL isLibraryFileSelected = ([selectedLibraryItems count] == 1) && ([[selectedLibraryItems lastObject] isKindOfClass:[LibraryFile class]]);
    ok = (myDocument != nil) && isLibraryFileSelected && ![myDocument isBusy];
  }
  else if ([sender action] == @selector(clearHistory:))
  {
    ok = ([[[HistoryManager sharedManager] historyItems] count] > 0);
  }
  return ok;
}

-(void) menuNeedsUpdate:(NSMenu*)menu
{
  MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];

  BOOL isPreambleVisible = (myDocument && [myDocument isPreambleVisible]);
  if (isPreambleVisible)
    [showPreambleMenuItem setTitle:NSLocalizedString(@"Hide preamble", @"Hide preamble")];
  else
    [showPreambleMenuItem setTitle:NSLocalizedString(@"Show preamble", @"Show preamble")];

  BOOL isHistoryVisible = (myDocument && [myDocument isHistoryVisible]);
  if (isHistoryVisible)
    [showHistoryMenuItem setTitle:NSLocalizedString(@"Hide History", @"Hide History")];
  else
    [showHistoryMenuItem setTitle:NSLocalizedString(@"Show History", @"Show History")];

  BOOL isLibraryVisible = (myDocument && [myDocument isLibraryVisible]);
  if (isLibraryVisible)
    [showLibraryMenuItem setTitle:NSLocalizedString(@"Hide Library", @"Hide Library")];
  else
    [showLibraryMenuItem setTitle:NSLocalizedString(@"Show Library", @"Show Library")];

  BOOL isMarginVisible = marginController && [[marginController window] isVisible];
  if (isMarginVisible)
    [marginMenuItem setTitle:NSLocalizedString(@"Hide Margins", @"Hide Margins")];
  else
    [marginMenuItem setTitle:NSLocalizedString(@"Show Margins", @"Show Margins")];
  
  BOOL isPaletteVisible = palettesController && [[palettesController window] isVisible];
  if (isPaletteVisible)
    [paletteMenuItem setTitle:NSLocalizedString(@"Hide Palettes", @"Hide Palettes")];
  else
    [paletteMenuItem setTitle:NSLocalizedString(@"Show Palettes", @"Show Palettes")];
}

-(IBAction) showOrHidePreamble:(id)sender
{
  MyDocument* document = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
  if (document)
  {
    BOOL makePreambleVisible = ![document isPreambleVisible];
    [document setPreambleVisible:makePreambleVisible];
    [self menuNeedsUpdate:nil];
  }
}

-(IBAction) showOrHideHistory:(id)sender
{
  MyDocument* document = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
  if (document)
  {
    BOOL makeHistoryVisible = ![document isHistoryVisible];
    [document setHistoryVisible:makeHistoryVisible];
    [self menuNeedsUpdate:nil];
  }
}

-(IBAction) showOrHideLibrary:(id)sender
{
  MyDocument* document = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
  if (document)
  {
    BOOL makeLibraryVisible = ![document isLibraryVisible];
    [document setLibraryVisible:makeLibraryVisible];
    [self menuNeedsUpdate:nil];
  }
}

-(IBAction) showOrHidePalette:(id)sender
{
  if (!palettesController)
    palettesController = [[PalettesController alloc] init];

  if ([[palettesController window] isVisible])
    [palettesController close];
  else
    [palettesController showWindow:self];
}

-(IBAction) showOrHideMargin:(id)sender
{
  if (!marginController)
    marginController = [[MarginController alloc] init];

  if ([[marginController window] isVisible])
    [marginController close];
  else
  {
    [marginController updateWithUserDefaults];
    [marginController showWindow:self];
  }
}

//looks for a programName in the given PATHs. Just tests that the file exists
-(NSString*) findUnixProgram:(NSString*)programName inPrefixes:(NSArray*)prefixes
{
  NSString* path = nil;
  if (prefixes)
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
  }
  return path;  
}

//looks for a programName in the environment.
-(NSString*) findUnixProgram:(NSString*)programName tryPrefixes:(NSArray*)prefixes
                 environment:(NSDictionary*)environment
{
  //first, it may be simply found in the common, usual, path
  NSString* path = [self findUnixProgram:programName inPrefixes:prefixes];
  
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
  }
  return path;
}

-(IBAction) openWebSite:(id)sender
{
	NSURL* webSiteURL = [NSURL URLWithString:NSLocalizedString(@"http://ktd.club.fr/programmation/latexit_en.php",
                                                             @"http://ktd.club.fr/programmation/latexit_en.php")];
  BOOL ok = [[NSWorkspace sharedWorkspace] openURL:webSiteURL];
  if (!ok)
  {
    NSRunAlertPanel(@"Error",
                   [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to reach %@\n. You should check your network.",
                                                                @"An error occured while trying to reach %@\n. You should check your network."),
                                              [webSiteURL absoluteString]],
                    @"Ok", nil, nil);
  }
}

-(IBAction) exportImage:(id)sender
{
  MyDocument* document = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
  if (document)
    [document exportImage:sender];
}

-(IBAction) makeLatex:(id)sender
{
  MyDocument* document = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
  if (document)
    [[document makeLatexButton] performClick:self];
}

-(IBAction) displayLog:(id)sender
{
  MyDocument* document = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
  if (document)
    [document displayLastLog:sender];
}

-(IBAction) clearHistory:(id)sender
{
  int returnCode = NSRunAlertPanel(NSLocalizedString(@"Clear History",@"Clear History"),
                                   NSLocalizedString(@"Are you sure you want to clear the whole history ?\nThis operation is irreversible.",
                                                     @"Are you sure you want to clear the whole history ?\nThis operation is irreversible."),
                                   NSLocalizedString(@"Clear History",@"Clear History"),
                                   NSLocalizedString(@"Cancel", @"Cancel"),
                                   nil);
  if (returnCode == NSAlertDefaultReturn)
    [[HistoryManager sharedManager] clearAll];
}

-(IBAction) addCurrentEquationToLibrary:(id)sender
{
  [(MyDocument*)[[NSDocumentController sharedDocumentController] currentDocument] addCurrentEquationToLibrary:sender];
}

-(IBAction) addLibraryFolder:(id)sender
{
  [(MyDocument*)[[NSDocumentController sharedDocumentController] currentDocument] addLibraryFolder:sender];
}

-(IBAction) removeLibraryItems:(id)sender
{
  [(MyDocument*)[[NSDocumentController sharedDocumentController] currentDocument] removeLibraryItems:sender];
}

-(IBAction) refreshLibraryItems:(id)sender
{
  [(MyDocument*)[[NSDocumentController sharedDocumentController] currentDocument] refreshLibraryItems:sender];
}

-(IBAction) saveLibrary:(id)sender
{
  NSSavePanel* savePanel = [NSSavePanel savePanel];
  [savePanel setTitle:NSLocalizedString(@"Save library as...", @"Save library as...")];
  [savePanel setRequiredFileType:@"latexlib"];
  [savePanel setCanSelectHiddenExtension:YES];
  int ok = [savePanel runModal];
  if (ok == NSFileHandlingPanelOKButton)
  {
    [[LibraryManager sharedManager] saveAs:[[savePanel URL] path]];
  }
}

-(IBAction) loadLibrary:(id)sender
{
  NSOpenPanel* openPanel = [NSOpenPanel openPanel];
  [openPanel setTitle:NSLocalizedString(@"Open library...", @"Open library...")];
  int ok = [openPanel runModalForTypes:[NSArray arrayWithObject:@"latexlib"]];
  if (ok == NSOKButton)
  {
    [[LibraryManager sharedManager] loadFrom:[[[openPanel URLs] lastObject] path]];
  }
}

//returns the preamble that should be used, according to the fact that color.sty is available or not
-(NSAttributedString*) preamble
{
  //return [[NSAttributedString alloc] initWithString:@""];
  NSData* preambleData = [[NSUserDefaults standardUserDefaults] objectForKey:DefaultPreambleAttributedKey];
  NSMutableAttributedString* preamble = [[NSMutableAttributedString alloc] initWithRTF:preambleData documentAttributes:NULL];
  NSString* preambleString = [preamble string];
  if (!isColorStyAvailable)
  {
    NSRange pdftexColorRange = [preambleString rangeOfString:@"\\usepackage[pdftex]{color}"];
    if (pdftexColorRange.location != NSNotFound)
      [preamble insertAttributedString:[[[NSAttributedString alloc] initWithString:@"%"] autorelease]
                               atIndex:pdftexColorRange.location];
  }
  return [preamble autorelease];
}

-(IBAction) removeHistoryEntries:(id)sender
{
  MyDocument* document = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
  if (document)
    [document removeHistoryEntries:sender];
}

-(BOOL) isGsAvailable
{
  return isGsAvailable;
}

-(BOOL) isPdfLatexAvailable
{
  return isPdfLatexAvailable;
}

-(BOOL) isColorStyAvailable
{
  return isColorStyAvailable;
}

//try to find gs program, searching by its name
-(void) _findGsPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSString* gsPath             = [userDefaults stringForKey:GsPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[gsPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:gsPath])
    gsPath = [self findUnixProgram:@"gs" tryPrefixes:prefixes environment:environmentDict];
  if ([fileManager fileExistsAtPath:gsPath])
  {
    [userDefaults setObject:gsPath forKey:GsPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}

//try to find pdflatex program, searching by its name
-(void) _findPdfLatexPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
  NSString* pdfLatexPath       = [userDefaults stringForKey:PdfLatexPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[pdfLatexPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:pdfLatexPath])
    pdfLatexPath = [self findUnixProgram:@"pdflatex" tryPrefixes:prefixes environment:environmentDict];
  if ([fileManager fileExistsAtPath:pdfLatexPath])
  {
    [userDefaults setObject:pdfLatexPath forKey:PdfLatexPathKey];
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
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
    [gsTask setLaunchPath:[userDefaults stringForKey:GsPathKey]];
    [gsTask setArguments:[NSArray arrayWithObject:@"-v"]];
    [gsTask setStandardOutput:nullDevice];
    [gsTask setStandardError:nullDevice];
    [gsTask launch];
    [gsTask waitUntilExit];
    ok = ([gsTask terminationStatus] == 0);
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
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
    [pdfLatexTask setLaunchPath:[userDefaults stringForKey:PdfLatexPathKey]];
    [pdfLatexTask setArguments:[NSArray arrayWithObject:@"-v"]];
    [pdfLatexTask setStandardOutput:nullDevice];
    [pdfLatexTask setStandardError:nullDevice];
    [pdfLatexTask launch];
    [pdfLatexTask waitUntilExit];
    ok = ([pdfLatexTask terminationStatus] == 0);
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

//checks if color.sty is available, by compiling a simple latex string that uses it
-(BOOL) _checkColorSty
{
  BOOL ok = YES;
  NSTask* pdfLatexTask = [[NSTask alloc] init];
  @try
  {
    NSString* testString = @"\\documentclass[10pt]{article}\\usepackage[pdftex]{color}\\begin{document}\\end{document}";
    NSString* directory      = NSTemporaryDirectory();
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
    [pdfLatexTask setCurrentDirectoryPath:directory];
    [pdfLatexTask setLaunchPath:[userDefaults stringForKey:PdfLatexPathKey]];
    [pdfLatexTask setArguments:[NSArray arrayWithObjects:@"--interaction", @"nonstopmode", testString, nil]];
    [pdfLatexTask setStandardOutput:nullDevice];
    [pdfLatexTask setStandardError:nullDevice];
    [pdfLatexTask launch];
    [pdfLatexTask waitUntilExit];
    ok = ([pdfLatexTask terminationStatus] == 0);
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

-(void) _checkConfiguration
{
  isGsAvailable       = [self _checkGs];
  isPdfLatexAvailable = [self _checkPdfLatex];
  isColorStyAvailable = isPdfLatexAvailable && [self _checkColorSty];
}

//when the user has clicked a palette element, we must put some text in the current document.
//sometimes, we must add symbols, and sometimes, we must encapsulate the selection into a symbol function
//The difference is made using the cell tag
-(IBAction) paletteClick:(id)sender
{
  id cell = [sender selectedCell];
  NSString* string = cell ? [cell alternateTitle] : nil;
  if (!string || ![string length]) string = cell ? [cell title] : nil;
  MyDocument* myDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
  if (string && myDocument)
  {
    if ([cell tag])
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
  MyDocument* currentDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] currentDocument];
  if (!currentDocument)
    currentDocument = (MyDocument*) [[NSDocumentController sharedDocumentController] openUntitledDocumentOfType:@"MyDocumentType" display:YES];
  if (currentDocument && historyItem)
  {
    [currentDocument setLinkBackLink:link];//automatically closes previous links
    [currentDocument applyHistoryItem:historyItem]; //defines the state of the document
    [currentDocument deselectItems];
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
-(void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  [LinkBack publishServerWithName:[NSApp applicationName] delegate:self];

  NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];

  if (!isGsAvailable)
    [self _findGsPath];
  BOOL retry = YES;
  while (!isGsAvailable && retry)
  {
    int returnCode = NSRunAlertPanel(NSLocalizedString(@"gs not found or not working as expected",
                                                       @"gs not found or not working as expected"),
                                     NSLocalizedString(@"Without GhostScript (gs) installed the software won't work at all.\n"\
                                                        "You should install a LaTeX distribution packaging gs",
                                                       @"Without GhostScript (gs) installed the software won't work at all.\n"\
                                                        "You should install a LaTeX distribution packaging gs"),
                                                       NSLocalizedString(@"Find gs...", @"Find gs..."),
                                                       @"Cancel",
                                                       nil);
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
          [userDefaults setObject:filepath forKey:GsPathKey];
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
    int returnCode = NSRunAlertPanel(NSLocalizedString(@"pdflatex not found or not working as expected",
                                                       @"pdflatex not found or not working as expected"),
                                     NSLocalizedString(@"Without pdflatex installed the software won't work at all.\n"\
                                                       @"You should install a LaTeX distribution packaging pdflatex",
                                                       @"Without pdflatex installed the software won't work at all.\n"\
                                                       @"You should install a LaTeX distribution packaging pdflatex"),
                                                       NSLocalizedString(@"Find pdflatex...", @"Find pdflatex..."),
                                                       @"Cancel",
                                                       nil);
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
          [userDefaults setObject:filepath forKey:PdfLatexPathKey];
          [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
          retry &= !isPdfLatexAvailable;
        }
      }
    }
  }
  
  if (isGsAvailable && isPdfLatexAvailable && !isColorStyAvailable)
    NSRunInformationalAlertPanel(NSLocalizedString(@"color.sty seems to be unavailable", @"color.sty seems to be unavailable"),
                                 NSLocalizedString(@"Without the color.sty package, you won't be able to change the font color",
                                                   @"Without the color.sty package, you won't be able to change the font color"),
                                 @"OK", nil, nil);
  if (isGsAvailable)
    [self _addInEnvironmentPath:[[userDefaults stringForKey:GsPathKey] stringByDeletingLastPathComponent]];
  if (isPdfLatexAvailable)
    [self _addInEnvironmentPath:[[userDefaults stringForKey:PdfLatexPathKey] stringByDeletingLastPathComponent]];

  [self _setEnvironment];
}

-(void) serviceLatexisationDisplay:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:DISPLAY error:error];
}
-(void) serviceLatexisationInline:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:INLINE error:error];
}
-(void) serviceLatexisationText:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error
{
  [self _serviceLatexisation:pboard userData:userData mode:TEXT error:error];
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
          NSString* directory          = NSTemporaryDirectory();
          NSString* filePrefix         = [NSString stringWithFormat:@"latexit-%d", 0];
          NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
          NSString* dragExportType     = [[userDefaults stringForKey:DragExportTypeKey] lowercaseString];
          NSArray* components          = [dragExportType componentsSeparatedByString:@" "];
          NSString* extension          = [components count] ? [components objectAtIndex:0] : nil;
          NSColor* color               = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
          float  quality               = [userDefaults floatForKey:DragExportJpegQualityKey];
          NSString* attachedFile       = [NSString stringWithFormat:@"%@.%@", filePrefix, extension];
          NSString* attachedFilePath   = [directory stringByAppendingPathComponent:attachedFile];
          NSData*   attachedData       = [self dataForType:dragExportType pdfData:pdfData jpegColor:color jpegQuality:quality];
          
          //Now we must feed the pasteboard
          [pboard declareTypes:[NSArray array] owner:nil];

           //we try to make RTFD data only if the user wants to use the baseline, because there is
           //a side-effect : it "disables" LinkBack (can't click on an image embedded in RTFD)
          if (useBaseline)
          {
            //extracts the baseline of the equation, if possible
            NSMutableString* equationBaselineAsString = [NSMutableString stringWithString:@"0"];
            BOOL needsToCheckLEEAnnotations = YES;
            #ifndef PANTHER
            PDFDocument* pdfDocument = [[PDFDocument alloc] initWithData:pdfData];
            NSArray* pdfMetaData     = [[pdfDocument documentAttributes] objectForKey:PDFDocumentKeywordsAttribute];
            needsToCheckLEEAnnotations = !(pdfMetaData && ([pdfMetaData count] >= 6));
            if (!needsToCheckLEEAnnotations)
              [equationBaselineAsString setString:[pdfMetaData objectAtIndex:5]];
            [pdfDocument release];
            #endif

            if (needsToCheckLEEAnnotations)
            {
              NSString* dataAsString = [[[NSString alloc] initWithData:pdfData encoding:NSASCIIStringEncoding] autorelease];
              NSArray*  testArray    = [dataAsString componentsSeparatedByString:@"/Baseline (EEbas"];
              if (testArray && ([testArray count] >= 2))
              {
                [equationBaselineAsString setString:[testArray objectAtIndex:1]];
                NSRange range = [equationBaselineAsString rangeOfString:@"EEbasend"];
                range.length  = (range.location != NSNotFound) ? [equationBaselineAsString length]-range.location : 0;
                [equationBaselineAsString deleteCharactersInRange:range];
              }
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
            [HistoryItem historyItemWithPdfData:pdfData preamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]
                                     sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                          color:color pointSize:pointSize date:[NSDate date] mode:mode];
          NSArray* historyItemArray = [NSArray arrayWithObject:historyItem];
          NSData* historyItemData = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
          NSDictionary* linkBackPlist = [NSDictionary linkBackDataWithServerName:[NSApp applicationName] appData:historyItemData]; 
        
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
           [[document windowForSheet] makeFirstResponder:[document sourceTextView]];
           [document makeLatex:self];
          }
        }//end if pdfData (LaTeXisation has worked)
      }
      //if the input is not RTF but just string, we will use default color and size
      else if ([types containsObject:NSStringPboardType])
      {
        NSAttributedString* preamble = [self preamble];
        NSString* pboardString = [pboard stringForType:NSStringPboardType];

        //performs effective latexisation
        NSData* pdfData = [[self _myDocumentServiceProvider] latexiseWithPreamble:[preamble string] body:pboardString
                                                                            color:[NSColor blackColor] mode:mode
                                                                    magnification:defaultPointSize];

        //if it has worked, put back data in the service pasteboard
        if (pdfData)
        {
          //translates the data to the right format
          NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
          NSString* dragExportType     = [[userDefaults stringForKey:DragExportTypeKey] lowercaseString];
          NSArray* components          = [dragExportType componentsSeparatedByString:@" "];
          NSString* extension          = [components count] ? [components objectAtIndex:0] : nil;
          NSColor* color               = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
          float  quality               = [userDefaults floatForKey:DragExportJpegQualityKey];
          NSData*   data               = [self dataForType:dragExportType pdfData:pdfData jpegColor:color jpegQuality:quality];

          //now feed the pasteboard
          [pboard declareTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:nil];
                
          //LinkBack data
          HistoryItem* historyItem =
          [HistoryItem historyItemWithPdfData:pdfData
                                     preamble:preamble
                                   sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                        color:[NSColor blackColor]
                                    pointSize:defaultPointSize date:[NSDate date] mode:mode];
          NSArray* historyItemArray = [NSArray arrayWithObject:historyItem];
          NSData* historyItemData = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
          NSDictionary* linkBackPlist = [NSDictionary linkBackDataWithServerName:[NSApp applicationName] appData:historyItemData]; 
          [pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];
          
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
           [[document windowForSheet] makeFirstResponder:[document sourceTextView]];
           [document makeLatex:self];
          }
        }//end if pdfData (LaTeXisation has worked)
      }//end if not RTF
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

-(IBAction) showHelp:(id)sender
{
  NSString* string = [readmeTextView string];
  if (!string || ![string length])
  {
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* file = [mainBundle pathForResource:NSLocalizedString(@"Read Me", @"Read Me") ofType:@"rtfd"];
    [readmeTextView readRTFDFromFile:file];
  }
  [readmeWindow makeKeyAndOrderFront:self];
}

//whenever a document is selected, we should change menuNeedsUpdate to ensure good show/hide state of library and history
-(void) windowDidBecomeMain:(NSNotification *)aNotification
{
  [self menuNeedsUpdate:nil];
}

//if a path has changed in the preferences, pdflatex may become [un]available, so we must update
//the "Latexise" button of the documents
-(void) _somePathDidChangeNotification:(NSNotification *)aNotification
{
  [self _checkConfiguration];
  NSArray* documents = [NSApp orderedDocuments];
  [documents makeObjectsPerformSelector:@selector(updateAvailabilities)];
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
  NSRange pdftexColorRange = [preamble rangeOfString:@"\\usepackage[pdftex]{color}"];
  if ([self isColorStyAvailable])
  {
    if (pdftexColorRange.location != NSNotFound)
    {
      int insertionPoint = pdftexColorRange.location+pdftexColorRange.length;
      [preamble insertString:colorString atIndex:insertionPoint];
    }
    else //try to find a good place of insertion
    {
      colorString = [NSString stringWithFormat:@"\\usepackage[pdftex]{color}%@", colorString];
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
-(NSData*) dataForType:(NSString*)format pdfData:(NSData*)pdfData
             jpegColor:(NSColor*)color jpegQuality:(float)quality
{
  NSData* data = nil;
  @synchronized(self) //only one person may ask that service at a time
  {
    //prepare file names
    NSString* directory      = NSTemporaryDirectory();
    NSString* filePrefix     = [NSString stringWithFormat:@"latexit-controller"];
    NSString* pdfFile        = [NSString stringWithFormat:@"%@.pdf", filePrefix];
    NSString* pdfFilePath    = [directory stringByAppendingPathComponent:pdfFile];
    NSString* tmpEpsFile     = [NSString stringWithFormat:@"%@-2.eps", filePrefix];
    NSString* tmpEpsFilePath = [directory stringByAppendingPathComponent:tmpEpsFile];

     if (pdfData)
    {
      if ([format isEqualToString:@"pdf"])
      {
        data = pdfData;
      }
      else if ([format isEqualToString:@"eps"])
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
      else if ([format isEqualToString:@"tiff"])
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentation];
        [image release];
      }
      else if ([format isEqualToString:@"png"])
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        data = [image TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:15.0];
        NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:data];
        data = [imageRep representationUsingType:NSPNGFileType properties:nil];
        [image release];
      }
      else if ([format isEqualToString:@"jpeg"])
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

//returns a file icon to represent the given PDF data
-(NSImage*) makeIconForData:(NSData*)pdfData
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
  NSColor* backgroundColor = [NSColor colorWithCalibratedRed:1 green:1 blue:1 alpha:0.25];
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
@end
