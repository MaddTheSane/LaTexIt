//  HistoryManager.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//This file is the history manager, data source of every historyView.
//It is a singleton, holding a single copy of the history items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

//Note that access to historyItem will be @synchronized

#import "HistoryManager.h"

#import "Compressor.h"
#import "HistoryItem.h"
#import "LatexitEquation.h"
#import "LaTeXProcessor.h"
#import "NSArrayExtended.h"
#import "NSColorExtended.h"
#import "NSFileManagerExtended.h"
#import "NSIndexSetExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSUndoManagerDebug.h"
#import "NSWorkspaceExtended.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>

@interface HistoryManager (PrivateAPI)
-(NSString*) defaultHistoryPath;
-(NSManagedObjectContext*) managedObjectContextAtPath:(NSString*)path;
-(void) applicationWillTerminate:(NSNotification*)aNotification; //saves history when quitting
-(void) saveHistory;
-(void) createHistoryMigratingIfNeeded;
-(BOOL) tableView:(NSTableView*)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
-(BOOL) tableView:(NSTableView*)aTableView writeRowsWithIndexes:(NSIndexSet*)rowIndexes toPasteboard:(NSPasteboard*)pboard;
@end

@implementation HistoryManager

static HistoryManager* sharedManagerInstance = nil; //the (private) singleton

+(HistoryManager*) sharedManager //access the unique instance of HistoryManager
{
  if (!sharedManagerInstance)
  {
    @synchronized(self)
    {
      if (!sharedManagerInstance)
        sharedManagerInstance = [[self  alloc] init];
    }//end @synchronized(self)
  }//end if (!sharedManagerInstance)
  return sharedManagerInstance;
}

+(id) allocWithZone:(NSZone *)zone
{
  @synchronized(self)
  {
    if (!sharedManagerInstance)
       return [super allocWithZone:zone];
  }
  return sharedManagerInstance;
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

//The init method can be called several times, it will only be applied once on the singleton
-(id) init
{
  if (self && (self != sharedManagerInstance))  //do not recreate an instance
  {
    if ((!(self = [super init])))
      return nil;
    sharedManagerInstance = self;

    [self createHistoryMigratingIfNeeded];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                                 name:NSApplicationWillTerminateNotification object:nil];
  }//end if (self && (self != sharedManagerInstance))  //do not recreate an instance
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->managedObjectContext       release];
  [super dealloc];
}
//end dealloc

-(NSString*) defaultHistoryPath
{
  NSString* result = nil;
  NSString* userLibraryPath =
    [[NSWorkspace sharedWorkspace] getBestStandardPast:NSLibraryDirectory domain:NSAllDomainsMask
                                          defaultValue:[NSHomeDirectory() stringByAppendingString:@"Library"]];
  NSString* userLibraryApplicationSupportPath =
    [[NSWorkspace sharedWorkspace] getBestStandardPast:NSApplicationSupportDirectory domain:NSAllDomainsMask
                                          defaultValue:[userLibraryPath stringByAppendingString:@"Application Support"]];
  NSArray* libraryPathComponents =
    [NSArray arrayWithObjects:userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName],
                              @"history.db", nil];
  result = [NSString pathWithComponents:libraryPathComponents];
  return result;
}
//end defaultHistoryPath

-(NSManagedObjectContext*) managedObjectContext
{
  return self->managedObjectContext;
}
//end managedObjectContext

-(NSUndoManager*) undoManager
{
  return [[self managedObjectContext] undoManager];
}
//end undoManager

//Management methods, undo-aware

-(void) saveHistory
{
  NSError* error = nil;
  [self->managedObjectContext save:&error];
  if (error)
    {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
}
//end saveHistory

-(void) createHistoryMigratingIfNeeded
{
  NSWindowController* migratingWindowController = nil;
  NSModalSession      modalSession              = 0;
  NSProgressIndicator* progressIndicator        = nil;

  NSFileManager* fileManager = [NSFileManager defaultManager];

  @try
  {
    //from LaTeXiT 1.13.0, use Application Support
    NSString* userLibraryPath = [[NSWorkspace sharedWorkspace] getBestStandardPast:NSLibraryDirectory domain:NSAllDomainsMask defaultValue:[NSHomeDirectory() stringByAppendingString:@"Library"]];
    NSString* userLibraryApplicationSupportPath = [[NSWorkspace sharedWorkspace] getBestStandardPast:NSApplicationSupportDirectory domain:NSAllDomainsMask defaultValue:[userLibraryPath stringByAppendingString:@"Application Support"]];

    NSString* newFilePath  = [self defaultHistoryPath];
    NSString* oldFilePath = nil;
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        [NSArray arrayWithObjects:userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName], @"history.dat", nil];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        [NSArray arrayWithObjects:userLibraryPath, [[NSWorkspace sharedWorkspace] applicationName], @"history.dat", nil];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }

    BOOL shouldMigrateHistory = ![fileManager isReadableFileAtPath:newFilePath] && oldFilePath;
    BOOL shouldDisplayMigrationProgression = shouldMigrateHistory && [[NSApp class] isEqual:[NSApplication class]];
    if (shouldDisplayMigrationProgression)
    {
      NSWindow* migratingWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 36) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:YES];
      migratingWindowController = [[[NSWindowController alloc] initWithWindow:migratingWindow] autorelease];
      [migratingWindow center];
      [migratingWindow setTitle:NSLocalizedString(@"Migrating history to new format", @"Migrating history to new format")];
      NSRect contentView = [[migratingWindow contentView] frame];
      progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSInsetRect(contentView, 8, 8)];
      [[migratingWindow contentView] addSubview:progressIndicator];
      [progressIndicator setMinValue:0.];
      [progressIndicator setUsesThreadedAnimation:YES];
      [progressIndicator startAnimation:self];
      [progressIndicator release];
      [migratingWindowController showWindow:migratingWindow];
      modalSession = [NSApp beginModalSessionForWindow:migratingWindow];
    }//end if ([[NSApp class] isEqual:[NSApplication class]])

    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:newFilePath isDirectory:&isDirectory] && !isDirectory &&
                  [fileManager isReadableFileAtPath:newFilePath];
    if (!exists)
      [fileManager createDirectoryPath:[newFilePath stringByDeletingLastPathComponent] attributes:nil];

    self->managedObjectContext = [[self managedObjectContextAtPath:newFilePath] retain];
    
    if (shouldMigrateHistory)
    {
      BOOL migrationError = NO;
      NSError* error = nil;
      NSData* legacyHistoryData = [NSData dataWithContentsOfFile:oldFilePath options:NSUncachedRead error:&error];
      if (error) {DebugLog(0, @"error : %@", error);}
      NSPropertyListFormat format;
      id plist = [NSPropertyListSerialization propertyListFromData:legacyHistoryData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:nil];
      NSData* compressedData = nil;
      if (!plist)
        compressedData = legacyHistoryData;
      else
        compressedData = [plist objectForKey:@"data"];

      NSData* uncompressedData = [Compressor zipuncompress:compressedData];
      if (uncompressedData)
      {
        NSArray* historyItems = nil;
        @try{
          historyItems = [NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData];
        }
        @catch(NSException* e){
          migrationError = YES;
          DebugLog(0, @"exception : %@", e);
        }
        unsigned int count = [historyItems count];
        [progressIndicator setIndeterminate:NO];
        [progressIndicator setMaxValue:1.*count];
        HistoryItem* historyItem = nil;
        NSEnumerator* enumerator = [historyItems objectEnumerator];
        unsigned int progression = 0;
        [[self->managedObjectContext undoManager] removeAllActions];
        [self->managedObjectContext disableUndoRegistration];
        while((historyItem = [enumerator nextObject]))
        {
          [self->managedObjectContext safeInsertObject:historyItem];
          [self->managedObjectContext safeInsertObject:[historyItem equation]];
          [progressIndicator setDoubleValue:1.*(++progression)/count];
        }//end for each historyItem
        [self->managedObjectContext enableUndoRegistration];
      }//end if (uncompressedData)
      migrationError |= (error != nil);
      if (!migrationError)
        [[NSFileManager defaultManager] removeFileAtPath:oldFilePath handler:0];
    }//end if (shouldMigrateHistory)
  }
  @catch(NSException* e) //reading may fail for some reason
  {
    DebugLog(0, @"exception : %@", e);
  }
  @finally //if the history could not be created, make it (empty) now
  {
  }
  
  if (modalSession) [NSApp endModalSession:modalSession];
  [[migratingWindowController window] close]; 
}
//end createHistoryMigratingIfNeeded

//When the application quits, the notification is caught to perform saving
-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  [self saveHistory];
}
//end applicationWillTerminate:

-(NSManagedObjectContext*) managedObjectContextAtPath:(NSString*)path
{
  NSManagedObjectContext* result = nil;
  NSPersistentStoreCoordinator* persistentStoreCoordinator = !path ? nil :
    [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel]];
  NSURL* storeURL = [NSURL fileURLWithPath:path];
  NSError* error = nil;
  id persistentStore = nil;
  @try{
    persistentStore =
      [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error];
  }
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
  }
  if (error)
    {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
  NSString* version = [[persistentStoreCoordinator metadataForPersistentStore:persistentStore] valueForKey:@"version"];
  if ([version compare:@"2.0.0" options:NSNumericSearch] > 0){
  }
  if (persistentStore)
    [persistentStoreCoordinator setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:@"2.0.1", @"version", nil] forPersistentStore:persistentStore];
  result = !persistentStore ? nil : [[NSManagedObjectContext alloc] init];
  //[result setUndoManager:(!result ? nil : [[[NSUndoManagerDebug alloc] init] autorelease])];
  [result setPersistentStoreCoordinator:persistentStoreCoordinator];
  [persistentStoreCoordinator release];
  [result setRetainsRegisteredObjects:YES];
  return [result autorelease];
}
//end managedObjectContextAtPath:

@end
