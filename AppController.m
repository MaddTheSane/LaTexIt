//  AppController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//The AppController is a singleton, a unique instance that acts as a bridge between the menu and the documents.
//It is also responsible for shared operations (like utilities : finding a program)
//It is also a bridge for the application service : it creates a dummy, invisible document that will perform
//the latexisation
//It is also the LinkBack server

#import "AppController.h"

#import "AdditionalFilesController.h"
#import "CompositionConfigurationController.h"
#import "EncapsulationController.h"
#import "HistoryController.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LatexPalettesController.h"
#import "LatexProcessor.h"
#import "LibraryController.h"
#import "LibraryFile.h"
#import "LibraryManager.h"
#import "LineCountTextView.h"
#import "MyDocument.h"
#import "MyImageView.h"
#import "NSApplicationExtended.h"
#import "NSAttributedStringExtended.h"
#import "NSColorExtended.h"
#import "NSFileManagerExtended.h"
#import "NSStringExtended.h"
#import "MarginController.h"
#import "PaletteItem.h"
#import "PreferencesController.h"
#import "Semaphore.h"
#import "SystemTask.h"
//#import "Utils.h"

#include <sys/types.h>
#include <sys/wait.h>

#import <Sparkle/Sparkle.h>
#import <Security/Security.h>

@interface AppController (PrivateAPI)

//specialized quick version of findUnixProgram... that does not take environment in account.
//It only looks for the existence of the file in the given paths, but does not look more.
-(NSString*) findUnixProgram:(NSString*)programName inPrefixes:(NSArray*)prefixes;

-(void) _addInEnvironmentPath:(NSString*)path; //increase the environmentPath
-(void) _setEnvironment:(NSDictionary*)environment; //utility that calls setenv() with the current content of environmentPath

//check the configuration, updates isGsAvailable, isPdfLatexAvailable and isColorStyAvailable
-(void) _checkConfiguration;

-(void) _checkGs:(id)object;      //called by _checkConfiguration to check for gs's presence
-(void) _checkPs2pdf:(id)object;  //called by _checkConfiguration to check for gs's presence
-(void) _checkDvipdf:(id)object;  //called by _checkConfiguration to check for dvipdf's presence
-(void) _checkPdfLatex:(id)object;//called by _checkConfiguration to check for pdflatex's presence
-(void) _checkXeLatex:(id)object; //called by _checkConfiguration to check for pdflatex's presence
-(void) _checkLatex:(id)object;   //called by _checkConfiguration to check for pdflatex's presence
-(void) _checkColorSty:(id)object;//called by _checkConfiguration to check for color.sty's presence

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

-(NSAttributedString*) modifyPreamble:(NSAttributedString*)preamble;

//private method factorizing the work of the different application service calls
-(void) _serviceLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData mode:(latex_mode_t)mode
                       error:(NSString **)error;
-(void) _serviceMultiLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;
-(void) _serviceDeLatexisation:(NSPasteboard *)pboard userData:(NSString *)userData error:(NSString **)error;

//delegate method to filter file opening                       
-(BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename;
@end

@implementation AppController

//the unique instance of the appController
static AppController* appControllerInstance = nil;

//usual environment and PATH to find a program on the command line
static NSMutableString*     environmentPath = nil;
static NSMutableDictionary* fullEnvironmentDict = nil;
static NSMutableDictionary* extraEnvironmentDict = nil;
static NSMutableArray*      unixBins = nil;

static NSMutableDictionary* cachePaths = nil;

+(void) initialize
{
  //Yes, it seems ugly, but I need it to force the user defaults to be initialized
  [PreferencesController initialize];
  
  NSString* temporaryPathFileName = @"latexit-paths";
  NSString* temporaryPathFilePath = [[AppController latexitTemporaryPath] stringByAppendingPathComponent:temporaryPathFileName];
  NSString* systemCall =
    [NSString stringWithFormat:@". /etc/profile && /bin/echo \"$PATH\" >| %@",
      temporaryPathFilePath, temporaryPathFilePath];
  int error = system([systemCall UTF8String]);
  NSError* nserror = nil;
  NSStringEncoding encoding = NSUTF8StringEncoding;
  NSArray* profileBins = error ? [NSArray array] 
                               : [[[NSString stringWithContentsOfFile:temporaryPathFilePath guessEncoding:&encoding error:&nserror] trim]
                                   componentsSeparatedByString:@":"];
    
  if (!unixBins)
    unixBins = [[NSMutableArray alloc] initWithArray:profileBins];
  
  //usual unix PATH (to find latex)
  NSArray* usualBins = 
    [NSArray arrayWithObjects:@"/bin", @"/sbin",
      @"/usr/bin", @"/usr/sbin",
      @"/usr/local/bin", @"/usr/local/sbin",
      @"/usr/texbin", @"/usr/local/texbin",
      @"/sw/bin", @"/sw/sbin",
      @"/sw/usr/bin", @"/sw/usr/sbin",
      @"/sw/local/bin", @"/sw/local/sbin",
      @"/sw/usr/local/bin", @"/sw/usr/local/sbin",
      @"/opt/local/bin", @"/opt/local/sbin",
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
      [components addObjectsFromArray:[[[propertyList objectForKey:@"PATH"] trim] componentsSeparatedByString:@":"]];
      [environmentPath setString:[components componentsJoinedByString:@":"]];
    }
  }
  
  if (!extraEnvironmentDict)
    extraEnvironmentDict = [[NSMutableDictionary alloc] init];

  if (!fullEnvironmentDict)
  {
    fullEnvironmentDict = [[[NSProcessInfo processInfo] environment] mutableCopy];

    NSString* pathEnv = [[fullEnvironmentDict objectForKey:@"PATH"] trim];
    if (pathEnv)
    {
      NSMutableSet* pathsSet = [NSMutableSet setWithCapacity:30];
      [pathsSet addObjectsFromArray:[environmentPath componentsSeparatedByString:@":"]];
      [pathsSet addObjectsFromArray:[pathEnv componentsSeparatedByString:@":"]];
      [environmentPath setString:[[pathsSet allObjects] componentsJoinedByString:@":"]];
      [fullEnvironmentDict setObject:environmentPath forKey:@"PATH"];
      [extraEnvironmentDict setObject:environmentPath forKey:@"PATH"];
    }
    
    //run the "set" command to get the environment variables
    /*
    SystemTask* task = [[SystemTask alloc] initWithWorkingDirectory:[AppController latexitTemporaryPath]];
    [task setLaunchPath:@"/bin/bash"];
    [task setArguments:[NSArray arrayWithObjects:@"-l", @"-c", @"set", nil]];
    [task setEnvironment:extraEnvironmentDict];
    [task launch];
    [task waitUntilExit];
    NSData* ouputData = [task dataForStdOutput];
    [task release];
    NSString* outputString = ouputData ? [[[NSString alloc] initWithData:ouputData encoding:NSUTF8StringEncoding] autorelease] : nil;
    NSEnumerator* linesEnumerator = [[outputString componentsSeparatedByString:@"\n"] objectEnumerator];
    NSString* line = nil;
    while((line = [linesEnumerator nextObject]))
    {
      NSRange equalCharacter = [line rangeOfString:@"="];
      if (equalCharacter.location != NSNotFound)
      {
        NSString* key   = [line substringWithRange:NSMakeRange(0, equalCharacter.location)];
        NSString* value = (equalCharacter.location+1 < [line length]) ?
                            [line substringFromIndex:equalCharacter.location+equalCharacter.length] : @"";
        if (![key isEqualToString:@"PATH"])
          [fullEnvironmentDict setObject:[value trim] forKey:key];
        else
        {
          NSString* path1 = [fullEnvironmentDict objectForKey:@"PATH"];
          NSArray*  components1 = path1 ? [path1 componentsSeparatedByString:@":"] : [NSArray array];
          NSArray*  components2 = value ? [value componentsSeparatedByString:@":"] : [NSArray array];
          NSArray*  allComponents = [components1 arrayByAddingObjectsFromArray:components2];
          [fullEnvironmentDict setObject:[allComponents componentsJoinedByString:@":"] forKey:key];
          [extraEnvironmentDict setObject:[allComponents componentsJoinedByString:@":"] forKey:key];
        }
      }//end if equalCharacter found
    }//end for each line
    */
  }//end if !fullEnvironmentDict
}
//end initialize

+(NSDictionary*) fullEnvironmentDict
{
  return fullEnvironmentDict;
}
//end fullEnvironmentDict

+(NSDictionary*) extraEnvironmentDict
{
  return extraEnvironmentDict;
}
//end extraEnvironmentDict

+(NSArray*) unixBins
{
  return unixBins;
}
//end unixBins

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
    if (![super init])
      return nil;
    appControllerInstance = self;
    configurationSemaphore = [[Semaphore alloc] init];
    [self _setEnvironment:extraEnvironmentDict];     //performs a setenv()
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
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [additionalFilesController release];
  [configurationSemaphore release];
  [compositionConfigurationController release];
  [encapsulationController release];
  [historyController release];
  [marginController release];
  [latexPalettesController release];
  [libraryController release];
  [super dealloc];
}
//end dealloc

-(SUUpdater*) sparkleUpdater
{
  return sparkleUpdater;
}
//end sparkleUpdater

-(NSDocument*) currentDocument
{
  return [[self class] currentDocument];
}
//end currentDocument

-(NSWindow*) whiteColorWarningWindow
{
  return whiteColorWarningWindow;
}
//end whiteColorWarningWindow

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
//end latexitTemporaryPath

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

-(AdditionalFilesController*) additionalFilesController
{
  if (!additionalFilesController)
    additionalFilesController = [[AdditionalFilesController alloc] init];
  return additionalFilesController;
}
//end additionalFilesController

-(CompositionConfigurationController*) compositionConfigurationController
{
  if (!compositionConfigurationController)
    compositionConfigurationController = [[CompositionConfigurationController alloc] init];
  return compositionConfigurationController;
}
//end compositionConfigurationController

-(EncapsulationController*) encapsulationController
{
  if (!encapsulationController)
    encapsulationController = [[EncapsulationController alloc] init];
  return encapsulationController;
}
//end encapsulationController

-(HistoryController*) historyController
{
  if (!historyController)
    historyController = [[HistoryController alloc] init];
  return historyController;
}
//end historyController

-(LatexPalettesController*) latexPalettesController
{
  if (!latexPalettesController)
    latexPalettesController = [[LatexPalettesController alloc] init];
  return latexPalettesController;
}
//end latexPalettesController

-(LibraryController*) libraryController
{
  if (!libraryController)
    libraryController = [[LibraryController alloc] init];
  return libraryController;
}
//end libraryController

-(MarginController*) marginController
{
  if (!marginController)
    marginController = [[MarginController alloc] init];
  return marginController;
}
//end marginController

//increase environmentPath
-(void) _addInEnvironmentPath:(NSString*)path
{
  NSMutableSet* componentsSet = [NSMutableSet setWithArray:[environmentPath componentsSeparatedByString:@":"]];
  [componentsSet addObject:path];
  [componentsSet removeObject:@"."];
  [environmentPath setString:[[componentsSet allObjects] componentsJoinedByString:@":"]];
}
//end _addInEnvironmentPath

//performs a setenv()
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

-(BOOL) applicationShouldOpenUntitledFile:(NSApplication*)sender
{
  return YES;
}
//end applicationShouldOpenUntitledFile:

-(IBAction) makeDonation:(id)sender//display info panel
{
  if (![donationPanel isVisible])
    [donationPanel center];
  [donationPanel orderFront:sender];
}
//end makeDonation:

-(IBAction) newFromClipboard:(id)sender
{
  NSColor* color = nil;
  NSData* data = nil;
  NSString* filename = @"clipboard";
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
  NSString* filepath = [[AppController latexitTemporaryPath] stringByAppendingPathComponent:filename];
  BOOL ok = data ? [data writeToFile:filepath atomically:YES] : NO;
  if (ok)
  {
    #ifdef PANTHER
    MyDocument* document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfFile:filepath display:NO];
    ok = (document != nil);
    #else
    NSError* error = nil;
    MyDocument* document = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:filepath] display:NO error:&error];
    ok = (error == nil) && (document != nil);
    #endif
    if (!ok)
      [document close];
    else
    {
      #ifndef PANTHER
      [document makeWindowControllers];
      #endif
      [[document windowControllers] makeObjectsPerformSelector:@selector(window)];//force loading nib file
      if (color) [document setColor:color];
      [document showWindows];
    }
  }
}
//end newFromClipboard:

-(IBAction) copyAs:(id)sender
{
  [[(MyDocument*)[self currentDocument] imageView] copy:sender]; 
}
//end copyAs:

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
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [myDocument hasImage];
    if ([sender tag] == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      ok &= isGsAvailable && isPs2PdfAvailable;
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
    ok = (myDocument != nil) && ![myDocument isBusy] && [myDocument hasImage];
  }
  else if ([sender action] == @selector(makeLatex:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [self isPdfLatexAvailable];
  }
  else if ([sender action] == @selector(makeLatexAndExport:))
  {
    MyDocument* myDocument = (MyDocument*) [self currentDocument];
    ok = (myDocument != nil) && ![myDocument isBusy] && [self isPdfLatexAvailable] && [[myDocument fileURL] path];
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
  else if ([sender action] == @selector(libraryRenameItem:))
  {
    ok = libraryController && [[libraryController window] isVisible] && [libraryController canRenameSelectedItems];
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
  else if ([sender action] == @selector(showOrHideAdditionalFiles:))
    [sender setState:(additionalFilesController && [[additionalFilesController window] isVisible]) ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideCompositionConfiguration:))
    [sender setState:(compositionConfigurationController && [[compositionConfigurationController window] isVisible]) ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideEncapsulation:))
    [sender setState:(encapsulationController && [[encapsulationController window] isVisible]) ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideMargin:))
    [sender setState:(marginController && [[marginController window] isVisible]) ? NSOnState : NSOffState];
  else if ([sender action] == @selector(showOrHideLatexPalettes:))
    [sender setState:(latexPalettesController && [[latexPalettesController window] isVisible]) ? NSOnState : NSOffState];
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
  return ok;
}
//end validateMenuItem:

-(IBAction) historyRemoveHistoryEntries:(id)sender
{
  [[self historyController] removeHistoryEntries:sender];
}
//end historyRemoveHistoryEntries:

-(IBAction) historyClearHistory:(id)sender
{
  [[self historyController] clearHistory:sender];
}
//end historyClearHistory:

-(IBAction) showOrHideHistory:(id)sender
{
  NSWindowController* controller = [self historyController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideHistory:

-(IBAction) libraryImportCurrent:(id)sender //creates a library item with the current document state
{
  [[self libraryController] importCurrent:sender];
}
//end libraryImportCurrent:

-(IBAction) libraryNewFolder:(id)sender     //creates a folder
{
  [[self libraryController] newFolder:sender];
}
//end libraryNewFolder:

-(IBAction) libraryRemoveSelectedItems:(id)sender    //removes some items
{
  [[self libraryController] removeSelectedItems:sender];
}
//end libraryRemoveSelectedItems:

-(IBAction) libraryRenameItem:(id)sender    //rename some items
{
  [[self libraryController] renameItem:sender];
}
//end libraryRenameItem:

-(IBAction) libraryRefreshItems:(id)sender   //refresh an item
{
  [[self libraryController] refreshItems:sender];
}
//end libraryRefreshItems:

-(IBAction) libraryOpen:(id)sender
{
  [[self libraryController] open:sender];
}
//end libraryOpen:

-(IBAction) librarySaveAs:(id)sender
{
  [[self libraryController] saveAs:sender];
}
//end librarySaveAs:

-(IBAction) showOrHideLibrary:(id)sender
{
  NSWindowController* controller = [self libraryController];
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
    BOOL makePreambleVisible = ![document isPreambleVisible];
    [document setPreambleVisible:makePreambleVisible];
  }
}
//end showOrHidePreamble:

-(IBAction) showOrHideLatexPalettes:(id)sender
{
  NSWindowController* controller = [self latexPalettesController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideLatexPalettes:

-(IBAction) showOrHideAdditionalFiles:(id)sender
{
  NSWindowController* controller = [self additionalFilesController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideAdditionalFiles:

-(IBAction) showOrHideCompositionConfiguration:(id)sender
{
  NSWindowController* controller = [self compositionConfigurationController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideCompositionConfiguration:

-(IBAction) showOrHideEncapsulation:(id)sender
{
  NSWindowController* controller = [self encapsulationController];
  if ([[controller window] isVisible])
    [controller close];
  else
    [controller showWindow:self];
}
//end showOrHideEncapsulation:

-(IBAction) showOrHideMargin:(id)sender
{
  NSWindowController* controller = [self marginController];
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
//end findUnixProgram:inPrefixes:

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
    SystemTask* whichTask = [[SystemTask alloc] initWithWorkingDirectory:[AppController latexitTemporaryPath]];
    @try
    {
      [whichTask setArguments:[NSArray arrayWithObject:programName]];
      [whichTask setEnvironment:environment];
      [whichTask setLaunchPath:whichPath];
      [whichTask setUsingLoginShell:[[NSUserDefaults standardUserDefaults] boolForKey:UseLoginShellKey]];
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
//end findUnixProgram:tryPrefixes:environment

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
                    @"OK", nil, nil);
  }
}
//end openWebSite:

//check for updates on LaTeXiT's web site
//if <sender> is nil, it's considered as a background task and will only present a panel if a new version is available.
-(IBAction) checkUpdates:(id)sender
{
  if (!sender)
    [sparkleUpdater checkForUpdatesInBackground];
  else
    [sparkleUpdater checkForUpdates:sender];
}
//end checkUpdates:

-(IBAction) makeLatexAndExport:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document makeLatexAndExport:sender];
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
    [[document makeLatexButton] performClick:self];
}
//end makeLatex:

-(IBAction) displayLog:(id)sender
{
  MyDocument* document = (MyDocument*) [self currentDocument];
  if (document)
    [document displayLastLog:sender];
}
//end displayLog:

//returns the preamble that should be used, according to the fact that color.sty is available or not
-(NSAttributedString*) preambleForLatexisation
{
  return [self modifyPreamble:[[PreferencesController sharedController] preambleForLatexisation]];
}
//end preamble

-(NSAttributedString*) preambleForService
{
  return [self modifyPreamble:[[PreferencesController sharedController] preambleForService]];
}
//end preambleForService

-(NSAttributedString*) modifyPreamble:(NSAttributedString*)preamble
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
//end modifyPreamble:

-(BOOL) isGsAvailable
{
  return isGsAvailable;
}
//end isGsAvailable

-(BOOL) isDvipdfAvailable
{
  return isDvipdfAvailable;
}
//end isDvipdfAvailable

-(BOOL) isPdfLatexAvailable
{
  return isPdfLatexAvailable;
}
//end isPdfLatexAvailable

-(BOOL) isPs2PdfAvailable
{
  return isPs2PdfAvailable;
}
//end isPs2PdfAvailable

-(BOOL) isXeLatexAvailable
{
  return isXeLatexAvailable;
}
//end isXeLatexAvailable

-(BOOL) isLatexAvailable
{
  return isLatexAvailable;
}
//end isLatexAvailable

-(BOOL) isColorStyAvailable
{
  return isColorStyAvailable;
}
//end isColorStyAvailable

//try to find gs program, searching by its name
-(void) _findGsPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* gsPath             = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[gsPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:gsPath])
    gsPath = [self findUnixProgram:@"gs" tryPrefixes:prefixes environment:extraEnvironmentDict];
  if ([fileManager fileExistsAtPath:gsPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:gsPath forKey:CompositionConfigurationGsPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}
//end _findGsPath

//try to find pdflatex program, searching by its name
-(void) _findPdfLatexPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* pdfLatexPath       = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPdfLatexPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[pdfLatexPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:pdfLatexPath])
    pdfLatexPath = [self findUnixProgram:@"pdflatex" tryPrefixes:prefixes environment:extraEnvironmentDict];
  if ([fileManager fileExistsAtPath:pdfLatexPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:pdfLatexPath forKey:CompositionConfigurationPdfLatexPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}
//end _findPdfLatexPath

//try to find pdflatex program, searching by its name
-(void) _findPs2PdfPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* ps2PdfPath         = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPs2PdfPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[ps2PdfPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:ps2PdfPath])
    ps2PdfPath = [self findUnixProgram:@"ps2pdf" tryPrefixes:prefixes environment:extraEnvironmentDict];
  if ([fileManager fileExistsAtPath:ps2PdfPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:ps2PdfPath forKey:CompositionConfigurationPs2PdfPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}
//end _findPs2PdfPath

//try to find xelatex program, searching by its name
-(void) _findXeLatexPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* xeLatexPath        = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationXeLatexPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[xeLatexPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:xeLatexPath])
    xeLatexPath = [self findUnixProgram:@"xelatex" tryPrefixes:prefixes environment:extraEnvironmentDict];
  if ([fileManager fileExistsAtPath:xeLatexPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:xeLatexPath forKey:CompositionConfigurationXeLatexPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}
//end _findXeLatexPath

//try to find latex program, searching by its name
-(void) _findLatexPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* latexPath          = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationLatexPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[latexPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:latexPath])
    latexPath = [self findUnixProgram:@"latex" tryPrefixes:prefixes environment:extraEnvironmentDict];
  if ([fileManager fileExistsAtPath:latexPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:latexPath forKey:CompositionConfigurationLatexPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}
//end _findLatexPath

//try to find dvipdf program, searching by its name
-(void) _findDvipdfPath
{
  NSFileManager* fileManager   = [NSFileManager defaultManager];
  NSString* dvipdfPath         = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationDvipdfPathKey];
  NSMutableArray* prefixes     = [NSMutableArray arrayWithArray:unixBins];
  [prefixes addObjectsFromArray:[NSArray arrayWithObject:[dvipdfPath stringByDeletingLastPathComponent]]];

  if (![fileManager fileExistsAtPath:dvipdfPath])
    dvipdfPath = [self findUnixProgram:@"dvipdf" tryPrefixes:prefixes environment:extraEnvironmentDict];
  if ([fileManager fileExistsAtPath:dvipdfPath])
  {
    [PreferencesController currentCompositionConfigurationSetObject:dvipdfPath forKey:CompositionConfigurationDvipdfPathKey];
    [[NSNotificationCenter defaultCenter] postNotificationName:SomePathDidChangeNotification object:nil];
  }
}
//end _findDvipdfPath

//check if gs work as expected. The user may have given a name different from "gs"
-(void) _checkGs:(id)object
{
  BOOL ok =
    [[NSFileManager defaultManager]
     isExecutableFileAtPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey]];
  int error = !ok ? 127 : system([[NSString stringWithFormat:@"%@ -v 1>|/dev/null 2>&1",
                          [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey]] UTF8String]);
  error = !ok ? 127 : (WIFEXITED(error) ? WEXITSTATUS(error) : 127);
  isGsAvailable = (error != 127);
  [configurationSemaphore P];
}
//end _checkGs:

//check if pdflatex works as expected. The user may have given a name different from "pdflatex"
-(void) _checkPdfLatex:(id)object
{
  //currently, the only check is the option -v, at least to see if the program can be executed
  BOOL ok =
    [[NSFileManager defaultManager]
     isExecutableFileAtPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPdfLatexPathKey]];
  int error = !ok ? 127 : system([[NSString stringWithFormat:@"%@ -v 1>|/dev/null 2>&1",
                        [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPdfLatexPathKey]] UTF8String]);
  error = !ok ? 127 : (WIFEXITED(error) ? WEXITSTATUS(error) : 127);
  isPdfLatexAvailable = (error != 127);
  [configurationSemaphore P];
}
//end _checkPdfLatex:

//check if ps2pdf works as expected. The user may have given a name different from "ps2pdf"
-(void) _checkPs2Pdf:(id)object
{
  BOOL ok =
    [[NSFileManager defaultManager]
     isExecutableFileAtPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPs2PdfPathKey]];
  int error = !ok ? 127 : system([[NSString stringWithFormat:@"%@ -v 1>|/dev/null 2>&1",
                        [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPs2PdfPathKey]] UTF8String]);
  error = !ok ? 127 : (WIFEXITED(error) ? WEXITSTATUS(error) : 127);
  isPs2PdfAvailable = (error != 127);
  [configurationSemaphore P];
}
//end _checkPs2Pdf:

//check if xelatex works as expected. The user may have given a name different from "pdflatex"
-(void) _checkXeLatex:(id)object
{
  //currently, the only check is the option -v, at least to see if the program can be executed
  BOOL ok =
    [[NSFileManager defaultManager]
     isExecutableFileAtPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationXeLatexPathKey]];
  int error = !ok ? 127 : system([[NSString stringWithFormat:@"%@ -v 1>|/dev/null 2>&1",
                        [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationXeLatexPathKey]] UTF8String]);
  error = !ok ? 127 : (WIFEXITED(error) ? WEXITSTATUS(error) : 127);
  isXeLatexAvailable = (error != 127);
  [configurationSemaphore P];
}
//end _checkXeLatex:

//check if latex works as expected. The user may have given a name different from "pdflatex"
-(void) _checkLatex:(id)object
{
  //currently, the only check is the option -v, at least to see if the program can be executed
  BOOL ok =
    [[NSFileManager defaultManager]
     isExecutableFileAtPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationLatexPathKey]];
  int error = !ok ? 127 : system([[NSString stringWithFormat:@"%@ -v 1>|/dev/null 2>&1",
                        [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationLatexPathKey]] UTF8String]);
  error = !ok ? 127 : (WIFEXITED(error) ? WEXITSTATUS(error) : 127);
  isLatexAvailable = (error != 127);
  [configurationSemaphore P];
}
//end _checkLatex:

//check if dvipdf works as expected. The user may have given a name different from "pdflatex"
-(void) _checkDvipdf:(id)object
{
  //currently, the only check is the option -v, at least to see if the program can be executed
  BOOL ok =
    [[NSFileManager defaultManager]
     isExecutableFileAtPath:[PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationDvipdfPathKey]];
  int error = !ok ? 127 : system([[NSString stringWithFormat:@"%@ -v 1>|/dev/null 2>&1",
                        [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationDvipdfPathKey]] UTF8String]);
  error = !ok ? 127 : (WIFEXITED(error) ? WEXITSTATUS(error) : 127);
  isDvipdfAvailable = (error != 127);
  [configurationSemaphore P];
}
//end _checkDvipdf:

//checks if color.sty is available, by compiling a simple latex string that uses it
-(void) _checkColorSty:(id)object
{
  BOOL ok = YES;
  
  //first try with kpsewhich
  NSString* kpseWhichPath = [self findUnixProgram:@"kpsewhich" tryPrefixes:unixBins environment:extraEnvironmentDict];
  ok = kpseWhichPath && ![kpseWhichPath isEqualToString:@""];
  if (ok)
  {
    SystemTask* kpseWhichTask = [[SystemTask alloc] init];
    @try{
      NSString* directory      = [AppController latexitTemporaryPath];
      //NSFileHandle* nullDevice  = [NSFileHandle fileHandleWithNullDevice];
      [kpseWhichTask setCurrentDirectoryPath:directory];
      NSString* launchPath = kpseWhichPath;
      BOOL isDirectory = YES;
      if ([[NSFileManager defaultManager] fileExistsAtPath:launchPath isDirectory:&isDirectory] && !isDirectory)
      {
        [kpseWhichTask setEnvironment:extraEnvironmentDict];
        [kpseWhichTask setLaunchPath:launchPath];
        [kpseWhichTask setArguments:[NSArray arrayWithObjects:@"color.sty", nil]];
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
    NSTask* checkTask = [[NSTask alloc] init];
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
          [checkTask setEnvironment:extraEnvironmentDict];
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
    [checkTask release];
  }//end if kpsewhich failed

  isColorStyAvailable = ok;
  [configurationSemaphore P];
}
//end _checkColorSty:

-(void) _checkConfiguration
{
  [NSApplication detachDrawingThread:@selector(sharedSpellChecker) toTarget:[NSSpellChecker class] withObject:nil];//meanwhile... let's not loose time
  [configurationSemaphore V:7];
  [NSApplication detachDrawingThread:@selector(_checkGs:)       toTarget:self withObject:nil];
  [NSApplication detachDrawingThread:@selector(_checkPdfLatex:) toTarget:self withObject:nil];
  [NSApplication detachDrawingThread:@selector(_checkPs2Pdf:)   toTarget:self withObject:nil];
  [NSApplication detachDrawingThread:@selector(_checkXeLatex:)  toTarget:self withObject:nil];
  [NSApplication detachDrawingThread:@selector(_checkLatex:)    toTarget:self withObject:nil];
  [NSApplication detachDrawingThread:@selector(_checkDvipdf:)   toTarget:self withObject:nil];
  [NSApplication detachDrawingThread:@selector(_checkColorSty:) toTarget:self withObject:nil];
  [configurationSemaphore Z];
}
//end _checkConfiguration

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
    if (([item numberOfArguments] >= 1) || ([item type] == LATEX_ITEM_TYPE_ENVIRONMENT))
      string = [NSString stringWithFormat:[item formatStringToInsertText],[myDocument selectedText]];
    [myDocument insertText:string];
  }
}
//end latexPalettesClick:

-(void) linkBackDidClose:(LinkBack*)link
{
  NSArray* documents = [NSApp orderedDocuments];
  [documents makeObjectsPerformSelector:@selector(closeLinkBackLink:) withObject:link];
}
//end linkBackDidClose:

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
    if ([currentDocument linkBackLink] != link)
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
//end linkBackClientDidRequestEdit:

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
          NSLocalizedString(@"%@ not found or does not work as expected", @"%@ not found or does not work as expected"),
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
          NSLocalizedString(@"%@ not found or does not work as expected", @"%@ not found or does not work as expected"),
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
          NSLocalizedString(@"%@ not found or does not work as expected", @"%@ not found or does not work as expected"),
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
          NSLocalizedString(@"%@ not found or does not work as expected", @"%@ not found or does not work as expected"),
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
          NSLocalizedString(@"%@ not found or does not work as expected", @"%@ not found or does not work as expected"),
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
          NSLocalizedString(@"%@ not found or does not work as expected", @"%@ not found or does not work as expected"),
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

  [self _setEnvironment:extraEnvironmentDict];

  //From LateXiT 1.13.0, move Library/LaTeXiT to Library/ApplicationSupport/LaTeXiT
  NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask , YES);
  paths = [paths count] ? [paths subarrayWithRange:NSMakeRange(0, 1)] : nil;
  NSArray* oldPaths = [paths arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:[NSApp applicationName], nil]];
  NSArray* newPaths = [paths arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"Application Support", [NSApp applicationName], nil]];
  NSString* oldPath = [NSString pathWithComponents:oldPaths];
  NSString* newPath = [NSString pathWithComponents:newPaths];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  if (![fileManager fileExistsAtPath:newPath] && [fileManager fileExistsAtPath:oldPath])
    [fileManager copyPath:oldPath toPath:newPath handler:nil];

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
  [self changeServiceShortcutsWithDiscrepancyFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK
                               authenticationFallback:CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK];

  if ([sparkleUpdater automaticallyChecksForUpdates])
    [sparkleUpdater checkForUpdatesInBackground];
  
  [NSThread detachNewThreadSelector:@selector(_triggerHistoryBackgroundLoading:) toTarget:self withObject:nil];
}
//end applicationDidFinishLaunching:

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
      NSArray* types = [[[pboard types] mutableCopy] autorelease];
      NSMutableDictionary* dummyPboard = [NSMutableDictionary dictionary];

      NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
      BOOL useColor     = [userDefaults boolForKey:ServiceRespectsColorKey];
      BOOL useBaseline  = [userDefaults boolForKey:ServiceRespectsBaselineKey];
      BOOL usePointSize = [userDefaults boolForKey:ServiceRespectsPointSizeKey];
      float pointSizeFactor = [userDefaults floatForKey:ServicePointSizeFactorKey];
      double defaultPointSize = [userDefaults floatForKey:DefaultPointSizeKey];
      
      //in the case of RTF input, we may deduce size, color, and change baseline
      if ([types containsObject:NSRTFPboardType] || [types containsObject:@"public.rtf"])
      {
        NSDictionary* documentAttributes = nil;
        NSData* pboardData = [pboard dataForType:NSRTFPboardType];
        if (!pboardData) pboardData = [pboard dataForType:@"public.rtf"];
        NSAttributedString* attrString = [[[NSAttributedString alloc] initWithRTF:pboardData
                                                               documentAttributes:&documentAttributes] autorelease];
        NSDictionary* contextAttributes = [attrString attributesAtIndex:0 effectiveRange:NULL];
        NSFont*  font  = usePointSize ? [contextAttributes objectForKey:NSFontAttributeName] : nil;
        float pointSize = font ? [font pointSize]*pointSizeFactor : defaultPointSize;
        float magnification = pointSize;
        NSColor* color = useColor ? [contextAttributes objectForKey:NSForegroundColorAttributeName] : nil;
        if (!color) color = [NSColor colorWithData:[userDefaults objectForKey:DefaultColorKey]];
        NSNumber* originalBaseline = [contextAttributes objectForKey:NSBaselineOffsetAttributeName];
        if (!originalBaseline) originalBaseline = [NSNumber numberWithFloat:0.0];
        NSString* pboardString = [attrString string];
        NSString* preamble = [LatexProcessor insertColorInPreamble:[[self preambleForService] string] color:color isColorStyAvailable:[self isColorStyAvailable]];
        NSString* body = pboardString;
        
        //perform effective latexisation
        NSData* pdfData = nil;
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        BOOL useLoginShell = [userDefaults boolForKey:UseLoginShellKey];
        NSString* workingDirectory = [AppController latexitTemporaryPath];
        NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-service"];
        NSDictionary* fullEnvironment  = [AppController fullEnvironmentDict];
        NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
        int compositionConfigurationIndex = [userDefaults integerForKey:CurrentCompositionConfigurationIndexKey];
        NSDictionary* configuration = ((compositionConfigurationIndex<0) ||
                                       ((unsigned)compositionConfigurationIndex >= [compositionConfigurations count])) ? nil :
                                      [compositionConfigurations objectAtIndex:compositionConfigurationIndex];
        composition_mode_t compositionMode =
          [[configuration objectForKey:CompositionConfigurationCompositionModeKey] intValue];
        NSString* pdfLatexPath = [configuration objectForKey:CompositionConfigurationPdfLatexPathKey];
        NSString* xeLatexPath = [configuration objectForKey:CompositionConfigurationXeLatexPathKey];
        NSString* latexPath = [configuration objectForKey:CompositionConfigurationLatexPathKey];
        NSString* dviPdfPath = [configuration objectForKey:CompositionConfigurationDvipdfPathKey];
        NSString* gsPath = [configuration objectForKey:CompositionConfigurationGsPathKey];
        NSString* ps2PdfPath = [configuration objectForKey:CompositionConfigurationPs2PdfPathKey];
        NSDictionary* additionalProcessingScripts = [configuration objectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];
        float leftMargin   = [self marginControllerLeftMargin];
        float rightMargin  = [self marginControllerRightMargin];
        float bottomMargin = [self marginControllerBottomMargin];
        float topMargin    = [self marginControllerTopMargin];
        [LatexProcessor latexiseWithPreamble:preamble body:body color:color mode:mode magnification:magnification
                           compositionMode:compositionMode workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
                           additionalFilepaths:nil fullEnvironment:fullEnvironment useLoginShell:useLoginShell
                                  pdfLatexPath:pdfLatexPath xeLatexPath:xeLatexPath latexPath:latexPath
                                    dviPdfPath:dviPdfPath gsPath:gsPath ps2PdfPath:ps2PdfPath
                                    leftMargin:leftMargin rightMargin:rightMargin
                                     topMargin:topMargin bottomMargin:bottomMargin
                               backgroundColor:nil additionalProcessingScripts:additionalProcessingScripts
                                    outFullLog:nil outErrors:nil outPdfData:&pdfData];

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
          NSData*   attachedData       = [self dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality
                                            scaleAsPercent:[userDefaults floatForKey:DragExportScaleAsPercentKey]];
          
          //Now we must feed the pasteboard
          //[pboard declareTypes:[NSArray array] owner:nil];

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
            //NSMutableAttributedString* space = [[[NSMutableAttributedString alloc] initWithString:@" "] autorelease];
            //[space setAttributes:contextAttributes range:NSMakeRange(0, [space length])];
            //[mutableAttributedStringWithImage appendAttributedString:space];

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
          HistoryItem* historyItem =
            [HistoryItem historyItemWithPDFData:pdfData preamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]
                                     sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                          color:color pointSize:pointSize date:[NSDate date] mode:mode backgroundColor:nil];
          NSArray* historyItemArray = [NSArray arrayWithObject:historyItem];
          NSData* historyItemData = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
          NSDictionary* linkBackPlist = [NSDictionary linkBackDataWithServerName:[NSApp applicationName] appData:historyItemData];
          if ([userDefaults boolForKey:ServiceUsesHistoryKey])//we may add the item to the history
            [[HistoryManager sharedManager] addItem:historyItem];
        
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
        NSAttributedString* preamble = [self preambleForService];
        NSString* pboardString = nil;
        #ifndef PANTHER
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
        #endif
        if (!pboardString)
          pboardString = [pboard stringForType:NSStringPboardType];
        if (!pboardString)
          pboardString = [pboard stringForType:@"public.utf8-plain-text"];
        NSString* body = pboardString;

        //perform effective latexisation
        NSData* pdfData = nil;
        NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
        BOOL useLoginShell = [userDefaults boolForKey:UseLoginShellKey];
        NSString* workingDirectory = [AppController latexitTemporaryPath];
        NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-service"];
        NSDictionary* fullEnvironment  = [AppController fullEnvironmentDict];
        NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
        int compositionConfigurationIndex = [userDefaults integerForKey:CurrentCompositionConfigurationIndexKey];
        NSDictionary* configuration = ((compositionConfigurationIndex<0) ||
                                       ((unsigned)compositionConfigurationIndex >= [compositionConfigurations count])) ? nil :
                                      [compositionConfigurations objectAtIndex:compositionConfigurationIndex];
        composition_mode_t compositionMode =
          [[configuration objectForKey:CompositionConfigurationCompositionModeKey] intValue];
        NSString* pdfLatexPath = [configuration objectForKey:CompositionConfigurationPdfLatexPathKey];
        NSString* xeLatexPath = [configuration objectForKey:CompositionConfigurationXeLatexPathKey];
        NSString* latexPath = [configuration objectForKey:CompositionConfigurationLatexPathKey];
        NSString* dviPdfPath = [configuration objectForKey:CompositionConfigurationDvipdfPathKey];
        NSString* gsPath = [configuration objectForKey:CompositionConfigurationGsPathKey];
        NSString* ps2PdfPath = [configuration objectForKey:CompositionConfigurationPs2PdfPathKey];
        NSDictionary* additionalProcessingScripts = [configuration objectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];
        float leftMargin   = [self marginControllerLeftMargin];
        float rightMargin  = [self marginControllerRightMargin];
        float bottomMargin = [self marginControllerBottomMargin];
        float topMargin    = [self marginControllerTopMargin];
        [LatexProcessor latexiseWithPreamble:[preamble string] body:body color:[NSColor blackColor] mode:mode magnification:defaultPointSize
                           compositionMode:compositionMode workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
                           additionalFilepaths:nil fullEnvironment:fullEnvironment useLoginShell:useLoginShell
                                  pdfLatexPath:pdfLatexPath xeLatexPath:xeLatexPath latexPath:latexPath
                                    dviPdfPath:dviPdfPath gsPath:gsPath ps2PdfPath:ps2PdfPath
                                    leftMargin:leftMargin rightMargin:rightMargin
                                     topMargin:topMargin bottomMargin:bottomMargin
                               backgroundColor:nil additionalProcessingScripts:additionalProcessingScripts
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

          NSColor* color               = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
          float  quality               = [userDefaults floatForKey:DragExportJpegQualityKey];
          NSData*   data               = [self dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality
                                               scaleAsPercent:[userDefaults floatForKey:DragExportScaleAsPercentKey]];

          //now feed the pasteboard
          //[pboard declareTypes:[NSArray arrayWithObject:LinkBackPboardType] owner:nil];
          //LinkBack data
          HistoryItem* historyItem =
          [HistoryItem historyItemWithPDFData:pdfData
                                     preamble:preamble
                                   sourceText:[[[NSAttributedString alloc] initWithString:pboardString] autorelease]
                                        color:[NSColor blackColor]
                                    pointSize:defaultPointSize date:[NSDate date] mode:mode backgroundColor:nil];
          NSArray* historyItemArray = [NSArray arrayWithObject:historyItem];
          NSData* historyItemData = [NSKeyedArchiver archivedDataWithRootObject:historyItemArray];
          NSDictionary* linkBackPlist = [NSDictionary linkBackDataWithServerName:[NSApp applicationName] appData:historyItemData]; 
          //[pboard setPropertyList:linkBackPlist forType:LinkBackPboardType];
          if (linkBackPlist)
            [dummyPboard setObject:linkBackPlist forKey:LinkBackPboardType];

          if ([userDefaults boolForKey:ServiceUsesHistoryKey])//we may add the item to the history
            [[HistoryManager sharedManager] addItem:historyItem];
          
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
           [[document windowForSheet] makeFirstResponder:[document sourceTextView]];
           [document makeLatex:self];
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
  if (!isPdfLatexAvailable || !isGsAvailable)
  {
    NSString* message = NSLocalizedString(@"LaTeXiT cannot be run properly, please check its configuration",
                                          @"LaTeXiT cannot be run properly, please check its configuration");
    *error = message;
    NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), message, @"OK", nil, nil);
  }
  else
  {
    [pboard types];//it is better o call it once
    @synchronized(self) //one latexisation at a time
    {
      NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
      BOOL useColor     = [userDefaults boolForKey:ServiceRespectsColorKey];
      BOOL useBaseline  = [userDefaults boolForKey:ServiceRespectsBaselineKey];
      BOOL usePointSize = [userDefaults boolForKey:ServiceRespectsPointSizeKey];
      float pointSizeFactor = [userDefaults floatForKey:ServicePointSizeFactorKey];
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
            float pointSize = font ? [font pointSize]*pointSizeFactor : defaultPointSize;
            float magnification = pointSize;
            NSColor* color = useColor ? [contextAttributes objectForKey:NSForegroundColorAttributeName] : nil;
            if (!color) color = [NSColor colorWithData:[userDefaults objectForKey:DefaultColorKey]];
            NSNumber* originalBaseline = [contextAttributes objectForKey:NSBaselineOffsetAttributeName];
            if (!originalBaseline) originalBaseline = [NSNumber numberWithFloat:0.0];
            NSString* body     = [string substringWithRange:rangeOfTextOfEquation];
            NSString* preamble = [LatexProcessor insertColorInPreamble:[[self preambleForService] string] color:color isColorStyAvailable:[self isColorStyAvailable]];
            
            //perform effective latexisation
            NSData* pdfData = nil;
            NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
            BOOL useLoginShell = [userDefaults boolForKey:UseLoginShellKey];
            NSString* workingDirectory = [AppController latexitTemporaryPath];
            NSString* uniqueIdentifier = [NSString stringWithFormat:@"latexit-service"];
            NSDictionary* fullEnvironment  = [AppController fullEnvironmentDict];
            NSArray* compositionConfigurations = [userDefaults arrayForKey:CompositionConfigurationsKey];
            int compositionConfigurationIndex = [userDefaults integerForKey:CurrentCompositionConfigurationIndexKey];
            NSDictionary* configuration = ((compositionConfigurationIndex<0) ||
                                           ((unsigned)compositionConfigurationIndex >= [compositionConfigurations count])) ? nil :
                                          [compositionConfigurations objectAtIndex:compositionConfigurationIndex];
            composition_mode_t compositionMode =
              [[configuration objectForKey:CompositionConfigurationCompositionModeKey] intValue];
            NSString* pdfLatexPath = [configuration objectForKey:CompositionConfigurationPdfLatexPathKey];
            NSString* xeLatexPath = [configuration objectForKey:CompositionConfigurationXeLatexPathKey];
            NSString* latexPath = [configuration objectForKey:CompositionConfigurationLatexPathKey];
            NSString* dviPdfPath = [configuration objectForKey:CompositionConfigurationDvipdfPathKey];
            NSString* gsPath = [configuration objectForKey:CompositionConfigurationGsPathKey];
            NSString* ps2PdfPath = [configuration objectForKey:CompositionConfigurationPs2PdfPathKey];
            NSDictionary* additionalProcessingScripts = [configuration objectForKey:CompositionConfigurationAdditionalProcessingScriptsKey];
            float leftMargin   = [self marginControllerLeftMargin];
            float rightMargin  = [self marginControllerRightMargin];
            float bottomMargin = [self marginControllerBottomMargin];
            float topMargin    = [self marginControllerTopMargin];
            [LatexProcessor latexiseWithPreamble:preamble body:body color:color mode:mode magnification:magnification
                               compositionMode:compositionMode workingDirectory:workingDirectory uniqueIdentifier:uniqueIdentifier
                               additionalFilepaths:nil fullEnvironment:fullEnvironment useLoginShell:useLoginShell
                                      pdfLatexPath:pdfLatexPath xeLatexPath:xeLatexPath latexPath:latexPath
                                        dviPdfPath:dviPdfPath gsPath:gsPath ps2PdfPath:ps2PdfPath
                                        leftMargin:leftMargin rightMargin:rightMargin
                                         topMargin:topMargin bottomMargin:bottomMargin
                                   backgroundColor:nil additionalProcessingScripts:additionalProcessingScripts
                                        outFullLog:nil outErrors:nil outPdfData:&pdfData];            //if it has worked, put back data in the attributedString. First, we get rid of the error case
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

              HistoryItem* historyItem =
                [HistoryItem historyItemWithPDFData:pdfData preamble:[[[NSAttributedString alloc] initWithString:preamble] autorelease]
                                         sourceText:[[[NSAttributedString alloc] initWithString:body] autorelease]
                                              color:color pointSize:pointSize date:[NSDate date] mode:mode backgroundColor:nil];
              if ([userDefaults boolForKey:ServiceUsesHistoryKey])//we may add the item to the history
                [[HistoryManager sharedManager] addItem:historyItem];

              NSColor*  color              = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
              float     quality            = [userDefaults floatForKey:DragExportJpegQualityKey];
              NSString* attachedFile       = [NSString stringWithFormat:@"%@.%@", filePrefix, extension];
              NSString* attachedFilePath   = [directory stringByAppendingPathComponent:attachedFile];
              NSData*   attachedData       = [self dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality
                                                scaleAsPercent:[userDefaults floatForKey:DragExportScaleAsPercentKey]];

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
              NSMutableAttributedString* space = [[[NSMutableAttributedString alloc] initWithString:@""] autorelease];
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
        int choice = NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"), message, NSLocalizedString(@"Cancel", @"Cancel"),
                                     NSLocalizedString(@"Open in LaTeXiT", @"Open in LaTeXiT"), nil);
        if (choice == NSAlertAlternateReturn)
        {
          NSEnumerator* enumerator = [errorDocuments objectEnumerator];
          MyDocument* document = nil;
          while((document = [enumerator nextObject]))
          {
            [document showWindows];
            [[document windowForSheet] makeFirstResponder:[document sourceTextView]];
            [document makeLatex:self];
          }
        }
      }//if there were failures
      
      //Now we must feed the pasteboard
      NSData* rtfdData = [mutableAttrString RTFDFromRange:NSMakeRange(0, [mutableAttrString length])
                                       documentAttributes:documentAttributes];
      [pboard declareTypes:[NSArray arrayWithObjects:NSRTFDPboardType, @"com.apple.flat-rtfd", nil] owner:nil];
      [pboard setData:rtfdData forType:NSRTFDPboardType];
      [pboard setData:rtfdData forType:@"com.apple.flat-rtfd"];
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
    HistoryItem* item = [[HistoryItem alloc] initWithPDFData:pdfData useDefaults:YES];
    NSMutableAttributedString* source = !item ? nil :
      [[[NSMutableAttributedString alloc] initWithAttributedString:[item sourceText]] autorelease];
    if (source)
    {
      NSFont* font = [[source fontAttributesInRange:NSMakeRange(0, [source length])] objectForKey:NSFontAttributeName];
      font = font ? font : [NSFont userFontOfSize:[item pointSize]];
      font = [NSFont fontWithName:[font fontName] size:[item pointSize]];
      NSDictionary* attributes = 
        [NSDictionary dictionaryWithObjectsAndKeys:
          font, NSFontAttributeName,
          [NSString stringWithFormat:@"%f",  [item pointSize]], NSFontSizeAttribute,
          [item color], NSForegroundColorAttributeName, nil];
      [source addAttributes:attributes range:NSMakeRange(0, [source length])];
      [pboard declareTypes:[NSArray arrayWithObjects:NSStringPboardType, @"public.utf8-plain-text",
                                                     NSRTFPboardType, @"public.rtf", nil]  owner:nil];
      [pboard setString:[source string] forType:NSStringPboardType];
      [pboard setString:[source string] forType:@"public.utf8-plain-text"];
      NSData* rtfData = [source RTFFromRange:NSMakeRange(0, [source length]) documentAttributes:nil];
      [pboard setData:rtfData forType:NSRTFPboardType];
      [pboard setData:rtfData forType:@"public.rtf"];
    }
    [item release];
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
          HistoryItem* item = [[HistoryItem alloc] initWithPDFData:pdfData useDefaults:YES];
          NSMutableAttributedString* source = !item ? nil :
            [[[NSMutableAttributedString alloc] initWithAttributedString:[item encapsulatedSource]] autorelease];
          if (!source)
            location += effectiveRange.length;
          else
          {
            NSFont* font = [[attributedString fontAttributesInRange:effectiveRange] objectForKey:NSFontAttributeName];
            font = font ? font : [NSFont userFontOfSize:[item pointSize]];
            font = [NSFont fontWithName:[font fontName] size:[item pointSize]];
            NSDictionary* attributes = 
              [NSDictionary dictionaryWithObjectsAndKeys:
                font, NSFontAttributeName,
                [NSString stringWithFormat:@"%f",  [item pointSize]], NSFontSizeAttribute,
                [item color], NSForegroundColorAttributeName, nil];
            [attributedString replaceCharactersInRange:effectiveRange withAttributedString:source];
            [attributedString addAttributes:attributes range:NSMakeRange(effectiveRange.location, [source length])];
            location += [source length];
          }
          [item release];
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

-(IBAction) showPreferencesPane:(id)sender
{
  NSWindow* window = [[PreferencesController sharedController] window];
  [window makeKeyAndOrderFront:self];
}
//end showPreferencesPane:

-(void) showPreferencesPaneWithItemIdentifier:(NSString*)itemIdentifier//showPreferencesPane + select one pane
{
  [self showPreferencesPane:self];
  [[PreferencesController sharedController] selectPreferencesPaneWithItemIdentifier:itemIdentifier];
}
//end showPreferencesPaneWithItemIdentifier:

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

//if a path has changed in the preferences, pdflatex may become [un]available, so we must update
//the "Latexise" button of the documents
-(void) _somePathDidChangeNotification:(NSNotification *)aNotification
{
  [self _checkConfiguration];
  NSArray* documents = [NSApp orderedDocuments];
  [documents makeObjectsPerformSelector:@selector(updateAvailabilities:) withObject:nil];
}
//end _somePathDidChangeNotification:

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

//returns data representing data derived from pdfData, but in the format specified (pdf, eps, tiff, png...)
-(NSData*) dataForType:(export_format_t)format pdfData:(NSData*)pdfData
             jpegColor:(NSColor*)color jpegQuality:(float)quality scaleAsPercent:(float)scaleAsPercent
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
      if (scaleAsPercent != 100)//if scale is not 100%, change image scale
      {
        NSPDFImageRep* pdfImageRep = [[NSPDFImageRep alloc] initWithData:pdfData];
        NSSize originalSize = [pdfImageRep size];
        NSImage* pdfImage = [[NSImage alloc] initWithSize:originalSize];
        [pdfImage setCacheMode:NSImageCacheNever];
        [pdfImage setDataRetained:YES];
        [pdfImage setScalesWhenResized:YES];
        [pdfImage addRepresentation:pdfImageRep];
        NSImageView* imageView =
          [[NSImageView alloc] initWithFrame:
            NSMakeRect(0, 0, originalSize.width*scaleAsPercent/100,originalSize.height*scaleAsPercent/100)];
        [imageView setImageScaling:NSScaleToFit];
        [imageView setImage:pdfImage];
        pdfData = [imageView dataWithPDFInsideRect:[imageView bounds]];
        [imageView release];
        [pdfImage release];
        [pdfImageRep release];
      }
    
      if (format == EXPORT_FORMAT_PDF)
      {
        data = pdfData;
      }
      else if (format == EXPORT_FORMAT_PDF_NOT_EMBEDDED_FONTS)
      {
        [pdfData writeToFile:pdfFilePath atomically:NO];
        NSString* gsPath       = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey];
        NSString* epstopdfPath = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationPs2PdfPathKey];
        if (gsPath && ![gsPath isEqualToString:@""] && epstopdfPath && ![epstopdfPath isEqualToString:@""])
        {
          NSString* tmpFilePath = nil;
          NSFileHandle* tmpFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"export.XXXXXXXXX" extension:@"log" outFilePath:&tmpFilePath
                                                                                workingDirectory:[AppController latexitTemporaryPath]];
          if (!tmpFilePath)
            tmpFilePath = @"/dev/null";
          NSString* systemCall =
            [NSString stringWithFormat:
              @"%@ -sDEVICE=pswrite -dNOCACHE -sOutputFile=- -q -dbatch -dNOPAUSE -dQUIET %@ -c quit 2>|%@ | %@ - %@ 1>>%@ 2>&1",
              gsPath, pdfFilePath, tmpFilePath, epstopdfPath, tmpPdfFilePath, tmpFilePath];
          int error = system([systemCall UTF8String]);
          if (error)
          {
            int displayError =
              NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                              [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file with command:\n%@",
                                                                           @"An error occured while trying to create the file with command:\n%@"),
                                                         systemCall],
                              NSLocalizedString(@"OK", @"OK"),
                              NSLocalizedString(@"Display the error message", @"Display the error message"),
                              nil);
            if (displayError == NSAlertAlternateReturn)
            {
              NSString* output = [[[NSString alloc] initWithData:[tmpFileHandle availableData] encoding:NSUTF8StringEncoding] autorelease];
              [[NSAlert alertWithMessageText:NSLocalizedString(@"Error message", @"Error message")
                                               defaultButton:NSLocalizedString(@"OK", @"OK") alternateButton:nil otherButton:nil
                                   informativeTextWithFormat:@"%@ %d:\n%@", NSLocalizedString(@"Error", @"Error"), error, output] runModal];
            }//end if displayError
            unlink([tmpFilePath UTF8String]);
          }//end if error
          else
          {
            HistoryItem* historyItem = [HistoryItem historyItemWithPDFData:pdfData useDefaults:YES];
            data = [NSData dataWithContentsOfFile:tmpPdfFilePath];
            data = [LatexProcessor annotatePdfDataInLEEFormat:data preamble:[[historyItem preamble] string]
                                             source:[[historyItem sourceText] string]
                                              color:[historyItem color] mode:[historyItem mode]
                                      magnification:[historyItem pointSize]
                                           baseline:0
                                    backgroundColor:[historyItem backgroundColor] title:[historyItem title]];
          }
        }
      }
      else if (format == EXPORT_FORMAT_EPS)
      {
        [pdfData writeToFile:pdfFilePath atomically:NO];
        SystemTask* gsTask = [[SystemTask alloc] initWithWorkingDirectory:[AppController latexitTemporaryPath]];
        NSMutableString* errorString = [NSMutableString string];
        NSString* gsPath = [PreferencesController currentCompositionConfigurationObjectForKey:CompositionConfigurationGsPathKey];
        @try
        {
          [gsTask setUsingLoginShell:[[NSUserDefaults standardUserDefaults] boolForKey:UseLoginShellKey]];
          [gsTask setCurrentDirectoryPath:directory];
          [gsTask setEnvironment:extraEnvironmentDict];
          [gsTask setLaunchPath:gsPath];
          [gsTask setArguments:[NSArray arrayWithObjects:@"-dNOPAUSE", @"-dNOCACHE", @"-dBATCH", @"-sDEVICE=epswrite",
                                                         [NSString stringWithFormat:@"-sOutputFile=%@", tmpEpsFilePath],
                                                         pdfFilePath, nil]];
          [gsTask launch];
          [gsTask waitUntilExit];
        }
        @catch(NSException* e)
        {
          [errorString appendString:[NSString stringWithFormat:@"exception ! name : %@ reason : %@\n", [e name], [e reason]]];
        }
        @finally
        {
          NSData* errorData = [gsTask dataForStdError];
          [errorString appendString:[[[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] autorelease]];

          if ([gsTask terminationStatus] != 0)
          {
            NSRunAlertPanel(NSLocalizedString(@"Error", @"Error"),
                            [NSString stringWithFormat:NSLocalizedString(@"An error occured while trying to create the file :\n%@",
                                                                         @"An error occured while trying to create the file :\n%@"),
                                                       errorString],
                            @"OK", nil, nil);
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
        NSBitmapImageRep* imageRep = [NSBitmapImageRep imageRepWithData:data];
        data = [imageRep representationUsingType:NSPNGFileType properties:nil];
        [image release];
      }
      else if (format == EXPORT_FORMAT_JPEG)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        NSSize size = [image size];
        NSImage* opaqueImage = [[NSImage alloc] initWithSize:size];
        NSRect rect = NSMakeRect(0, 0, size.width, size.height);
        @try{
        [opaqueImage lockFocus];
          [color set];
          NSRectFill(rect);
          [image drawInRect:rect fromRect:rect operation:NSCompositeSourceOver fraction:1.0];
        [opaqueImage unlockFocus];
        }
        @catch(NSException* e)//may occur if lockFocus fails
        {
        }
        data = [opaqueImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:15.0];
        [opaqueImage release];
        NSBitmapImageRep *opaqueImageRep = [NSBitmapImageRep imageRepWithData:data];
        NSDictionary* properties =
          [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:quality/100], NSImageCompressionFactor, nil];
        data = [opaqueImageRep representationUsingType:NSJPEGFileType properties:properties];
        [image release];
      }
      /*else if (format == EXPORT_FORMAT_PICT)
      {
        NSImage* image = [[NSImage alloc] initWithData:pdfData];
        NSSize size = [image size];
        NSPICTImageRep* pictImageRep = [[NSPICTImageRep alloc] initWithData:nil]
        NSRect rect = NSMakeRect(0, 0, size.width, size.height);
        @try{
        [opaqueImage lockFocus];
          [color set];
          NSRectFill(rect);
          [image drawInRect:rect fromRect:rect operation:NSCompositeSourceOver fraction:1.0];
        [opaqueImage unlockFocus];
        }
        @catch(NSException* e)//may occur if lockFocus fails
        {
        }
        data = [opaqueImage TIFFRepresentationUsingCompression:NSTIFFCompressionLZW factor:15.0];
        [opaqueImage release];
        NSBitmapImageRep *opaqueImageRep = [NSBitmapImageRep imageRepWithData:data];
        NSDictionary* properties =
          [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithFloat:quality/100], NSImageCompressionFactor, nil];
        data = [opaqueImageRep representationUsingType:NSJPEGFileType properties:properties];
        [image release];
      }//end if PICT
      */
    }//end if pdfData available
  }//end @synchronized
  return data;
}
//end dataForType:pdfData:jpegColor:jpegQuality:scaleAsPercent:

//application delegate methods
-(BOOL) application:(NSApplication *)theApplication openFile:(NSString *)filename
{
  BOOL ok = NO;
  NSString* type = [[filename pathExtension] lowercaseString];
  if ([type isEqualTo:@"latexpalette"])
  {
    ok = [self installLatexPalette:filename];
    if (ok)
      [latexPalettesController reloadPalettes];
    ok = YES;
  }
  else if ([type isEqualTo:@"latexlib"] || [type isEqualTo:@"library"])
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
      ok = [[LibraryManager sharedManager] loadFrom:filename option:LIBRARY_IMPORT_MERGE];
    else if (confirm == NSAlertOtherReturn)
      ok = [[LibraryManager sharedManager] loadFrom:filename option:LIBRARY_IMPORT_OVERWRITE];
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
  
  [[PreferencesController sharedController] commitChanges];
}
//end applicationWillTerminate:

//if the marginController is not loaded, just use the user defaults values
-(float) marginControllerTopMargin
{
  return marginController ? [marginController topMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalTopMarginKey];
}
//end marginControllerTopMargin

-(float) marginControllerBottomMargin
{
  return marginController ? [marginController bottomMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalBottomMarginKey];
}
//end marginControllerBottomMargin

-(float) marginControllerLeftMargin
{
  return marginController ? [marginController leftMargin]
                          : [[NSUserDefaults standardUserDefaults] floatForKey:AdditionalLeftMarginKey];
}
//end marginControllerLeftMargin

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
//end _triggerHistoryBackgroundLoading:

-(BOOL) changeServiceShortcutsWithDiscrepancyFallback:(change_service_shortcuts_fallback_t)discrepancyFallback
                               authenticationFallback:(change_service_shortcuts_fallback_t)authenticationFallback
{
  BOOL ok = true;
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
    NSNumber* objectFalse = [NSNumber numberWithBool:NO];
    NSMutableDictionary* infoPlist = (NSMutableDictionary*) cfInfoPlist;
    NSArray* currentServicesInInfoPlist = [[[infoPlist objectForKey:@"NSServices"] mutableCopy] autorelease];
    NSMutableDictionary* equivalentUserDefaultsToCurrentServicesInInfoPlist =
      [NSMutableDictionary dictionaryWithObjectsAndKeys:
        [NSMutableArray arrayWithObjects:objectFalse, objectFalse, objectFalse, objectFalse, objectFalse, objectFalse, nil], ServiceShortcutEnabledKey,
        [NSMutableArray arrayWithObjects:@"", @"", @"", @"", @"", @"", nil], ServiceShortcutStringsKey,
        nil];
    NSEnumerator* enumerator = [currentServicesInInfoPlist objectEnumerator];
    NSDictionary* service = nil;
    while((service = [enumerator nextObject]))
    {
      NSString* message  = [service objectForKey:@"NSMessage"];
      NSString* shortcutDefault = [[service objectForKey:@"NSKeyEquivalent"] objectForKey:@"default"];
      NSString* shortcutWhenEnabled = [[service objectForKey:@"NSKeyEquivalent"] objectForKey:@"whenEnabled"];
      NSNumber* enabled = [NSNumber numberWithBool:
                             (shortcutDefault && (!shortcutWhenEnabled || [shortcutDefault isEqualToString:shortcutWhenEnabled]))];
      if ([message isEqualToString:@"serviceLatexisationEqnarray"])
      {
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutEnabledKey]
           replaceObjectAtIndex:indexOfLatexMode(LATEX_MODE_EQNARRAY) withObject:enabled];
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutStringsKey]
           replaceObjectAtIndex:indexOfLatexMode(LATEX_MODE_EQNARRAY) withObject:shortcutDefault ? shortcutDefault : @""];
      }
      else if ([message isEqualToString:@"serviceLatexisationDisplay"])
      {
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutEnabledKey]
           replaceObjectAtIndex:indexOfLatexMode(LATEX_MODE_DISPLAY) withObject:enabled];
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutStringsKey]
           replaceObjectAtIndex:indexOfLatexMode(LATEX_MODE_DISPLAY) withObject:shortcutDefault ? shortcutDefault : @""];
      }
      else if ([message isEqualToString:@"serviceLatexisationInline"])
      {
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutEnabledKey]
           replaceObjectAtIndex:indexOfLatexMode(LATEX_MODE_INLINE) withObject:enabled];
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutStringsKey]
           replaceObjectAtIndex:indexOfLatexMode(LATEX_MODE_INLINE) withObject:shortcutDefault ? shortcutDefault : @""];
      }
      else if ([message isEqualToString:@"serviceLatexisationText"])
      {
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutEnabledKey]
           replaceObjectAtIndex:indexOfLatexMode(LATEX_MODE_TEXT) withObject:enabled];
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutStringsKey]
           replaceObjectAtIndex:indexOfLatexMode(LATEX_MODE_TEXT) withObject:shortcutDefault ? shortcutDefault : @""];
      }
      else if ([message isEqualToString:@"serviceMultiLatexisation"])
      {
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutEnabledKey]
           replaceObjectAtIndex:4 withObject:enabled];
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutStringsKey]
           replaceObjectAtIndex:4 withObject:shortcutDefault ? shortcutDefault : @""];
      }
      else if ([message isEqualToString:@"serviceDeLatexisation"])
      {
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutEnabledKey]
           replaceObjectAtIndex:5 withObject:enabled];
        [[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutStringsKey]
           replaceObjectAtIndex:5 withObject:shortcutDefault ? shortcutDefault : @""];
      }
    }//end for each service of info.plist

    NSMutableArray* equivalentServicesToCurrentUserDefaults = [NSMutableArray array];
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
        
        NSDictionary* serviceItemPlist =
          [NSDictionary dictionaryWithObjectsAndKeys:
            [NSDictionary dictionaryWithObjectsAndKeys:(disable ? @"" : shortcut), @"default",
                                                      shortcut, @"whenEnabled", nil], @"NSKeyEquivalent",
            [NSDictionary dictionaryWithObject:menuItemName forKey:@"default"], @"NSMenuItem",
            serviceMessage, @"NSMessage",
            @"LaTeXiT", @"NSPortName",
            [NSArray arrayWithObjects:@"NSRTFDPboardType", @"com.apple.flat-rtfd",
                                      @"NSPDFPboardType", @"com.adobe.pdf",
                                      @"NSPostScriptPboardType", @"com.adobe.encapsulated-postscript",
                                      @"NSTIFFPboardType", @"public.tiff",
                                      @"NSPNGPboardType", @"public.png",
                                      @"public.jpeg", nil], @"NSReturnTypes",
            [NSArray arrayWithObjects:@"NSRTFPboardType", @"public.rtf",
                                      @"NSPDFPboardType", @"com.adobe.pdf",
                                      @"NSStringPboardType", @"public.utf8-plain-text", nil], @"NSSendTypes",
            [NSNumber numberWithInt:30000], @"NSTimeOut",
            nil];
        [equivalentServicesToCurrentUserDefaults addObject:serviceItemPlist];
      }//end if index<count
    }//end for each latex mode
    //end adds each latex mode
      
    //adds multi-latexisation
    {
      NSString* shortcut = (NSString*) [shortcutStrings objectAtIndex:4];
      BOOL      disable  = ![[shortcutEnabled objectAtIndex:4] boolValue];
      NSDictionary* serviceItemPlist =
        [NSDictionary dictionaryWithObjectsAndKeys:
          [NSDictionary dictionaryWithObjectsAndKeys:(disable ? @"" : shortcut), @"default",
                                                      shortcut, @"whenEnabled", nil], @"NSKeyEquivalent",
          [NSDictionary dictionaryWithObject:@"LaTeXiT/Detect and typeset equations" forKey:@"default"], @"NSMenuItem",
          @"serviceMultiLatexisation", @"NSMessage",
          @"LaTeXiT", @"NSPortName",
          [NSArray arrayWithObjects:@"NSRTFDPboardType", @"com.apple.flat-rtfd", nil], @"NSReturnTypes",
          [NSArray arrayWithObjects:@"NSRTFDPboardType", @"com.apple.flat-rtfd",
                                    @"NSRTFPboardType", @"public.rtf", nil], @"NSSendTypes",
          [NSNumber numberWithInt:30000], @"NSTimeOut",
          nil];
      [equivalentServicesToCurrentUserDefaults addObject:serviceItemPlist];
    }
    //end adds multi-latexisation

    //adds de-latexisation
    {
      NSString* shortcut = (NSString*) [shortcutStrings objectAtIndex:5];
      BOOL      disable  = ![[shortcutEnabled objectAtIndex:5] boolValue];
      NSDictionary* serviceItemPlist =
        [NSDictionary dictionaryWithObjectsAndKeys:
          [NSDictionary dictionaryWithObjectsAndKeys:(disable ? @"" : shortcut), @"default",
                                                      shortcut, @"whenEnabled", nil], @"NSKeyEquivalent",
          [NSDictionary dictionaryWithObject:@"LaTeXiT/Un-latexize equations" forKey:@"default"], @"NSMenuItem",
          @"serviceDeLatexisation", @"NSMessage",
          @"LaTeXiT", @"NSPortName",
          [NSArray arrayWithObjects:@"NSRTFDPboardType", @"com.apple.flat-rtfd",
                                    @"NSPDFPboardType", @"com.adobe.pdf",
                                    @"NSRTFPboardType", @"public.rtf", nil], @"NSReturnTypes",
          [NSArray arrayWithObjects:@"NSRTFDPboardType", @"com.apple.flat-rtfd",
                                    @"NSPDFPboardType", @"com.adobe.pdf", nil], @"NSSendTypes",
          [NSNumber numberWithInt:30000], @"NSTimeOut",
          nil];
      [equivalentServicesToCurrentUserDefaults addObject:serviceItemPlist];
    }
    //end adds de-latexisation
    
    if (![currentServicesInInfoPlist isEqualToArray:equivalentServicesToCurrentUserDefaults])
    {
      if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK)
      {
        NSAlert* alert =
          [NSAlert alertWithMessageText:NSLocalizedString(@"The current Service shortcuts of LaTeXiT do not match the ones defined in the preferences",
                                                          @"The current Service shortcuts of LaTeXiT do not match the ones defined in the preferences")
                          defaultButton:NSLocalizedString(@"Apply preferences",
                                                          @"Apply preferences")
                        alternateButton:NSLocalizedString(@"Update preferences",
                                                          @"Update preferences")
                            otherButton:NSLocalizedString(@"Ignore", @"Ignore")
              informativeTextWithFormat:NSLocalizedString(@"__EXPLAIN_CHANGE_SHORTCUTS__", @"__EXPLAIN_CHANGE_SHORTCUTS__")];
        [[[alert buttons] objectAtIndex:2] setKeyEquivalent:[NSString stringWithFormat:@"%c", '\033']];//escape
        int result = [alert runModal];
        if (result == NSAlertDefaultReturn)
          discrepancyFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS;
        else if (result == NSAlertAlternateReturn)
          discrepancyFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS;
        else if (result == NSAlertOtherReturn)
          discrepancyFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE;
      }
      if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE)
      {
        ok = false;
      }
      else if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS)
      {
        [userDefaults setObject:[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutEnabledKey]
                         forKey:ServiceShortcutEnabledKey];
        [userDefaults setObject:[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutStringsKey]
                         forKey:ServiceShortcutStringsKey];
        NSUpdateDynamicServices();
        ok = true;
      }
      else if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS)
      {
        [infoPlist setObject:equivalentServicesToCurrentUserDefaults forKey:@"NSServices"];
        ok = [infoPlist writeToURL:infoPlistURL atomically:YES];
        if (!ok)
        {
          AuthorizationRef myAuthorizationRef = 0;
          OSStatus myStatus = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment,
                                                  kAuthorizationFlagDefaults, &myAuthorizationRef);
          AuthorizationItem myItems[1] = {{0}};
          myItems[0].name = kAuthorizationRightExecute;
          myItems[0].valueLength = 0;
          myItems[0].value = NULL;
          myItems[0].flags = 0;
          AuthorizationRights myRights = {0};
          myRights.count = sizeof(myItems) / sizeof(myItems[0]);
          myRights.items = myItems;
          AuthorizationFlags myFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
                                       kAuthorizationFlagExtendRights | kAuthorizationFlagPreAuthorize;
          myStatus = myStatus ? myStatus : AuthorizationCopyRights(myAuthorizationRef, &myRights,
                                                                   kAuthorizationEmptyEnvironment, myFlags, NULL);
          NSString* src = nil;
          [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-info.XXXXXXXX" extension:@"plist" outFilePath:&src
                                                   workingDirectory:[AppController latexitTemporaryPath]];
          NSString* dst = [infoPlistURL path];
          if (!myStatus && src && dst && [infoPlist writeToFile:src atomically:YES])
          {
            const char* args[] = {[src UTF8String], [dst UTF8String], NULL};
            myStatus = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/cp", kAuthorizationFlagDefaults, (char**)args, NULL);
          }
          if (src)
            [[NSFileManager defaultManager] removeFileAtPath:src handler:NULL];
          myStatus = myStatus ? myStatus : AuthorizationFree(myAuthorizationRef, kAuthorizationFlagDestroyRights);
          ok = (myStatus == 0);
        }//end if (!ok)
        if (ok)
           NSUpdateDynamicServices();
        else
        {
          if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_ASK)
          {
            NSAlert* alert =
            [NSAlert alertWithMessageText:NSLocalizedString(@"New Service shortcuts could not be set",
                                                            @"New Service shortcuts could not be set")
                            defaultButton:NSLocalizedString(@"Update preferences",@"Update preferences")
                          alternateButton:NSLocalizedString(@"Ignore",@"Ignore")
                              otherButton:nil
                informativeTextWithFormat:NSLocalizedString(@"Authentication failed or did not allow to rewrite the <Info.plist> file inside the LaTeXiT.app bundle",
                                                            @"Authentication failed or did not allow to rewrite the <Info.plist> file inside the LaTeXiT.app bundle")];
            [[[alert buttons] objectAtIndex:1] setKeyEquivalent:[NSString stringWithFormat:@"%c",'\033']];
            int result = [alert runModal];
            if (result == NSAlertDefaultReturn)
               authenticationFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS;
            else
               authenticationFallback = CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE;
          }
          if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_IGNORE)
          {
            ok = false;
          } //do nothing
          else if (authenticationFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_REPLACE_USERDEFAULTS)
          {
            [userDefaults setObject:[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutEnabledKey]
                             forKey:ServiceShortcutEnabledKey];
            [userDefaults setObject:[equivalentUserDefaultsToCurrentServicesInInfoPlist objectForKey:ServiceShortcutStringsKey]
                             forKey:ServiceShortcutStringsKey];
            NSUpdateDynamicServices();
            ok = true;
          }
        }//end if (authentication did not help writing)
      }//end if (discrepancyFallback == CHANGE_SERVICE_SHORTCUTS_FALLBACK_APPLY_USERDEFAULTS)
    }//end if (![currentServicesInInfoPlist iEqualTo:equivalentServicesToCurrentUserDefaults])
  }//end if (cfInfoPlist)
  CFRelease(cfInfoPlist);
  
  return ok;
}
//end changeServiceShortcutsWithDiscrepancyFallback:authenticationFallback:

-(void) startMessageProgress:(NSString*)message
{
  [[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(startMessageProgress:) withObject:message];
}
//end startMessageProgress:

-(void) stopMessageProgress
{
  [[[NSDocumentController sharedDocumentController] documents] makeObjectsPerformSelector:@selector(stopMessageProgress)];
}
//end stopMessageProgress

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
      libraryPaths ? [libraryPaths arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"Application Support", [NSApp applicationName], @"Palettes", nil]] : nil;
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

-(IBAction) returnFromWhiteColorWarningWindow:(id)sender
{
  [NSApp stopModalWithCode:([sender tag] == 0) ? NSCancelButton : NSOKButton];
  [whiteColorWarningWindow close];
}
//end returnFromWhiteColorWarningWindow:

-(IBAction) openFile:(id)sender
{
  if (![openFileTypePopUp numberOfItems])
  {
    [openFileTypePopUp addItemsWithTitles:[NSArray arrayWithObjects:
      NSLocalizedString(@"PDF Equation", @"PDF Equation"),
      NSLocalizedString(@"Text file", @"Text file"),
      NSLocalizedString(@"LaTeXiT library", @"LaTeXiT library"),
      NSLocalizedString(@"LaTeX Equation Editor library", @"LaTeX Equation Editor library"),
      NSLocalizedString(@"LaTeXiT LaTeX Palette", @"LaTeXiT  LaTeX Palette"), nil]];
    [openFileTypePopUp selectItemAtIndex:0];
  }
  openFileTypeOpenPanel = [NSOpenPanel openPanel];
  [self changeOpenFileType:openFileTypePopUp];
  [openFileTypeOpenPanel setAllowsMultipleSelection:NO];
  [openFileTypeOpenPanel setCanChooseDirectories:NO];
  [openFileTypeOpenPanel setCanChooseFiles:YES];
  [openFileTypeOpenPanel setCanCreateDirectories:NO];
  [openFileTypeOpenPanel setResolvesAliases:YES];
  [openFileTypeOpenPanel setAccessoryView:openFileTypeView];
  [openFileTypeOpenPanel setDelegate:self];
  int result = [openFileTypeOpenPanel runModalForDirectory:nil file:nil types:nil];
  if (result == NSOKButton)
  {
    NSString* filePath = [[openFileTypeOpenPanel filenames] lastObject];
    [self application:NSApp openFile:filePath];
  }
  openFileTypeOpenPanel = nil;
}
//end openFile:

-(IBAction) changeOpenFileType:(id)sender
{
  if (openFileTypeOpenPanel && (sender == openFileTypePopUp))
  {
    int selectedIndex = [openFileTypePopUp indexOfSelectedItem];
    if (selectedIndex == 0)
      [openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"com.adobe.pdf", nil]];
    else if (selectedIndex == 1)
      [openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"public.text", nil]];
    else if (selectedIndex == 2)
      [openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"latexlib", nil]];
    else if (selectedIndex == 3)
      [openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"library", nil]];
    else if (selectedIndex == 4)
      [openFileTypeOpenPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"latexpalette", nil]];
    else
      [openFileTypeOpenPanel setAllowedFileTypes:nil];
    [openFileTypeOpenPanel validateVisibleColumns];
  }
}
//end changeOpenFileType:

-(BOOL) panel:(id)sender shouldShowFilename:(NSString *)filename
{
  BOOL result = YES;
  if (sender == openFileTypeOpenPanel)
  {
    NSArray* allowedFileTypes = [openFileTypeOpenPanel allowedFileTypes];
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

@end
