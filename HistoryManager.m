//  HistoryManager.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.

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
#import "NSObjectExtended.h"
#import "NSUndoManagerDebug.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>
#include <sqlite3.h>

#if __has_feature(objc_arc)
#error this file needs to be compiled without Automatic Reference Counting (ARC)
#endif

@interface HistoryManager () <NSTableViewDelegate>
-(void) _migrateLatexitManagedModel:(NSString*)path;
-(NSString*) defaultHistoryPath;
-(NSManagedObjectContext*) managedObjectContextAtPath:(NSString*)path setVersion:(BOOL)setVersion;
-(void) applicationWillTerminate:(NSNotification*)aNotification; //saves history when quitting
-(void) createHistoryMigratingIfNeeded;
//-(BOOL) tableView:(NSTableView*)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
//-(BOOL) tableView:(NSTableView*)tableView writeRowsWithIndexes:(NSIndexSet*)rowIndexes toPasteboard:(NSPasteboard*)pboard;
-(NSModalSession) showMigratingProgressionWindow:(NSWindowController**)outMigratingWindowController progressIndicator:(NSProgressIndicator**)outProgressIndicator;
-(void) hideMigratingProgressionWindow:(NSModalSession)modalSession windowController:(NSWindowController*)windowController;
@end

@implementation HistoryManager
@synthesize locked;

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

#ifdef ARC_ENABLED
#else
-(id) retain
{
  return self;
}

-(NSUInteger) retainCount
{
  return NSUIntegerMax;  //denotes an object that cannot be released
}

-(oneway void) release
{
}

-(id) autorelease
{
  return self;
}
#endif

//The init method can be called several times, it will only be applied once on the singleton
-(instancetype) init
{
  if (self && (self != sharedManagerInstance))  //do not recreate an instance
  {
    if ((!(self = [super init])))
      return nil;
    sharedManagerInstance = self;

    bindController = [[NSObjectController alloc] initWithContent:self];
    //[self->bindController bind:NSContentBinding toObject:self withKeyPath:@"locked" options:nil];
    [self createHistoryMigratingIfNeeded];
    [self deleteOldEntries];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                                 name:NSApplicationWillTerminateNotification object:nil];
  }//end if (self && (self != sharedManagerInstance))  //do not recreate an instance
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  #ifdef ARC_ENABLED
  #else
  [self->managedObjectContext release];
  [self->bindController release];
  [super dealloc];
  #endif
}
//end dealloc

-(NSObjectController*) bindController {return self->bindController;}

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
    @[userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName],
                              @"history.latexhist"];
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
  return [self managedObjectContext].undoManager;
}
//end undoManager

//Management methods, undo-aware

-(BOOL) isLocked              {return self->locked;}
-(void) setLocked:(BOOL)value
{
  if (value != self->locked)
  {
    [self willChangeValueForKey:@"locked"];
    self->locked = value;
    [self didChangeValueForKey:@"locked"];
  }//end if (value != self->locked)
}
//end setLocked:

-(NSUInteger) numberOfItems
{
  NSUInteger result = 0;
  NSManagedObjectContext* moc = [self managedObjectContext];
  NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
  NSError* error = nil;
  fetchRequest.entity = [HistoryItem entity];
  if ([moc respondsToSelector:@selector(countForFetchRequest:error:)])
    result = [moc countForFetchRequest:fetchRequest error:&error];
  else
    result = [moc executeFetchRequest:fetchRequest error:&error].count;
  #ifdef ARC_ENABLED
  #else
  [fetchRequest release];
  #endif
  if (error)
    {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
  return result;
}
//end numberOfItems

-(void) deleteOldEntries
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSNumber* historyDeleteOldEntriesLimit = ![preferencesController historyDeleteOldEntriesEnabled] ? nil :
    [preferencesController historyDeleteOldEntriesLimit];
  NSDate* oldestDate = !historyDeleteOldEntriesLimit ? nil :
    [[NSCalendarDate calendarDate] dateByAddingYears:0 months:0 days:-[historyDeleteOldEntriesLimit integerValue] hours:0 minutes:0 seconds:0];
  if (oldestDate)
  {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"date < %@" argumentArray:@[oldestDate]];
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [LatexitEquation entity];
    fetchRequest.predicate = predicate;
    NSError* error = nil;
    NSArray* oldEntries = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
      {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
    NSArray* oldHistoryItems = [oldEntries valueForKey:@"wrapper"];
    #ifdef ARC_ENABLED
    #else
    [fetchRequest release];
    #endif
    if (oldHistoryItems.count)
    {
      [managedObjectContext disableUndoRegistration];
      [managedObjectContext safeDeleteObjects:oldHistoryItems];
      [managedObjectContext enableUndoRegistration];
    }//end if ([oldHistoryItems count])
  }//end if (oldestDate)
}
//end deleteOldEntries

-(void) saveHistory
{
  @try {
    NSError* error = nil;
    BOOL saved = [managedObjectContext save:&error];
    if (!saved || error)
      {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
  }//end @try
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
  }//end @catch
}
//end saveHistory

-(void) createHistoryMigratingIfNeeded
{
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSModalSession migratingModalSession = 0;
  NSWindowController* migratingWindowController = nil;
  NSProgressIndicator* migratingProgressIndicator = nil;

  @try
  {
    //from LaTeXiT 1.13.0, use Application Support
    NSString* userLibraryPath = [[NSWorkspace sharedWorkspace] getBestStandardPast:NSLibraryDirectory domain:NSAllDomainsMask defaultValue:[NSHomeDirectory() stringByAppendingString:@"Library"]];
    NSString* userLibraryApplicationSupportPath = [[NSWorkspace sharedWorkspace] getBestStandardPast:NSApplicationSupportDirectory domain:NSAllDomainsMask defaultValue:[userLibraryPath stringByAppendingString:@"Application Support"]];

    NSString* newFilePath  = [self defaultHistoryPath];
    NSString* oldFilePathDat = nil;
    if (!oldFilePathDat)
    {
      NSArray* pathComponents =
        @[userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName], @"history.dat"];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePathDat = filePath;
    }//end if (!oldFilePathDat)
    if (!oldFilePathDat)
    {
      NSArray* pathComponents =
        @[userLibraryPath, [[NSWorkspace sharedWorkspace] applicationName], @"history.dat"];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePathDat = filePath;
    }//end if (!oldFilePathDat)

    NSString* oldFilePathDb = nil;
    if (!oldFilePathDb)
    {
      NSArray* pathComponents =
      @[userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName], @"history.db"];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePathDb = filePath;
    }//end if (!oldFilePathDb)
    if (!oldFilePathDb)
    {
      NSArray* pathComponents =
      @[userLibraryPath, [[NSWorkspace sharedWorkspace] applicationName], @"history.db"];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePathDb = filePath;
    }//end if (!oldFilePathDb)
    
    BOOL shouldRenameHistoryFile = ![fileManager isReadableFileAtPath:newFilePath] && oldFilePathDb;
    BOOL shouldMigrateHistoryToCoreData = !shouldRenameHistoryFile && ![fileManager isReadableFileAtPath:newFilePath] && oldFilePathDat;
    if (shouldRenameHistoryFile)
    {
      NSError* error = nil;
      BOOL moved = [fileManager moveItemAtPath:oldFilePathDb toPath:newFilePath error:&error];
      if (error)
        {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
      if (!moved)
        newFilePath = oldFilePathDb;
    }//end if (shouldRenameHistoryFile)

    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:newFilePath isDirectory:&isDirectory] && !isDirectory &&
                  [fileManager isReadableFileAtPath:newFilePath];
    if (!exists)
      [fileManager createDirectoryAtPath:newFilePath.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:0];

    #ifdef ARC_ENABLED
    self->managedObjectContext = [self managedObjectContextAtPath:newFilePath setVersion:NO];
    #else
    self->managedObjectContext = [[self managedObjectContextAtPath:newFilePath setVersion:NO] retain];
    #endif
    NSPersistentStoreCoordinator* persistentStoreCoordinator = self->managedObjectContext.persistentStoreCoordinator;
    NSArray* persistentStores = persistentStoreCoordinator.persistentStores;
    id oldVersionObject =
      [persistentStoreCoordinator metadataForPersistentStore:persistentStores.lastObject][@"version"];
    #ifdef ARC_ENABLED
    NSString* oldVersion = [oldVersionObject isKindOfClass:[NSString class]] ? (NSString*)[oldVersionObject copy] : nil;
    #else
    NSString* oldVersion = [oldVersionObject isKindOfClass:[NSString class]] ? (NSString*)[[oldVersionObject copy] autorelease] : nil;
    #endif
    BOOL shouldMigrateHistoryToAlign = ([oldVersion compare:@"2.1.0"] == NSOrderedAscending);

    BOOL shouldDisplayMigrationProgression = (shouldMigrateHistoryToCoreData && [[NSApp class] isEqual:[NSApplication class]]) ||
                                             shouldMigrateHistoryToAlign;
    if (shouldDisplayMigrationProgression)
      migratingModalSession =
        [self showMigratingProgressionWindow:&migratingWindowController progressIndicator:&migratingProgressIndicator];

    BOOL migrationError = NO;
    if (shouldMigrateHistoryToCoreData)
    {
      NSError* error = nil;
      NSData* legacyHistoryData = [NSData dataWithContentsOfFile:oldFilePathDat options:NSUncachedRead error:&error];
      if (error) {DebugLog(0, @"error : %@", error);}
      NSPropertyListFormat format;
      id plist = [NSPropertyListSerialization propertyListWithData:legacyHistoryData options:NSPropertyListImmutable format:&format error:nil];
      NSData* compressedData = nil;
      if (!plist)
        compressedData = legacyHistoryData;
      else
        compressedData = plist[@"data"];

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
        NSUInteger count = historyItems.count;
        [migratingProgressIndicator setIndeterminate:NO];
        migratingProgressIndicator.minValue = 0.;
        migratingProgressIndicator.maxValue = 1.*count;
        migratingProgressIndicator.doubleValue = 0.;
        HistoryItem* historyItem = nil;
        NSEnumerator* enumerator = [historyItems objectEnumerator];
        NSUInteger progression = 0;
        [self->managedObjectContext.undoManager removeAllActions];
        [self->managedObjectContext disableUndoRegistration];
        while((historyItem = [enumerator nextObject]))
        {
          [self->managedObjectContext safeInsertObject:historyItem];
          [self->managedObjectContext safeInsertObject:[historyItem equation]];
          migratingProgressIndicator.doubleValue = 1.*(progression++);
          if (!(progression%25))
            [migratingProgressIndicator display];
        }//end for each historyItem
        [self->managedObjectContext enableUndoRegistration];
      }//end if (uncompressedData)
      migrationError |= (error != nil);
      if (!migrationError)
        [[NSFileManager defaultManager] removeItemAtPath:oldFilePathDat error:0];
    }//end if (shouldMigrateHistoryToCoreData)
    else if (shouldMigrateHistoryToAlign)
    {
      NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
      fetchRequest.entity = [LatexitEquation entity];
      NSError* error = nil;
      NSArray* latexitEquations = [self->managedObjectContext executeFetchRequest:fetchRequest error:&error];
      NSUInteger progression = 0;
      NSUInteger count = latexitEquations.count;
      [migratingProgressIndicator setIndeterminate:NO];
      migratingProgressIndicator.maxValue = 1.*count;
      migratingProgressIndicator.doubleValue = 0.;
      [migratingProgressIndicator display];
      if (error)
        DebugLog(0, @"error : %@", error);
      NSEnumerator* enumerator = [latexitEquations objectEnumerator];
      LatexitEquation* latexitEquation = nil;
      @try{
        while((latexitEquation = [enumerator nextObject]))
        {
          [latexitEquation checkAndMigrateAlign];//force fetch and update
          migratingProgressIndicator.doubleValue = 1.*(progression++);
          if (!(progression%25))
            [migratingProgressIndicator display];
        }//end for each latexitEquation
      }
      @catch(NSException* e){
        DebugLog(0, @"exception : %@", e);
        migrationError = YES;
      }
      @finally{
      }
      #ifdef ARC_ENABLED
      #else
      [fetchRequest release];
      #endif
      error = nil;
      [self->managedObjectContext save:&error];
      if (error)
        DebugLog(0, @"error : %@", error);
    }//end if (shouldMigrateHistoryToAlign)
    
    if (!migrationError)
    {
      NSString* applicationVersion = [[NSWorkspace sharedWorkspace] applicationVersion];
      NSEnumerator* enumerator = [persistentStores objectEnumerator];
      id persistentStore = nil;
      while((persistentStore = [enumerator nextObject]))
        [persistentStoreCoordinator setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:applicationVersion, @"version", nil]
                             forPersistentStore:persistentStore];
    }//end if (!migrationError)

  }
  @catch(NSException* e) //reading may fail for some reason
  {
    DebugLog(0, @"exception : %@", e);
  }
  @finally //if the history could not be created, make it (empty) now
  {
  }
  [self hideMigratingProgressionWindow:migratingModalSession windowController:migratingWindowController];
}
//end createHistoryMigratingIfNeeded

//When the application quits, the notification is caught to perform saving
-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  [self saveHistory];
}
//end applicationWillTerminate:

-(NSManagedObjectContext*) managedObjectContextAtPath:(NSString*)path setVersion:(BOOL)setVersion
{
  NSManagedObjectContext* result = nil;
  NSPersistentStoreCoordinator* persistentStoreCoordinator =
    [[NSPersistentStoreCoordinator alloc]
      initWithManagedObjectModel:[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel]];
  id persistentStore = nil;
  @try{
    NSURL* storeURL = [NSURL fileURLWithPath:path];
    NSError* error = nil;
    NSMutableDictionary* options = [NSMutableDictionary dictionary];
    if (DebugLogLevel >= 1)
    {
      if (isMacOS10_6OrAbove())
        [options setObject:[NSNumber numberWithBool:YES] forKey:NSSQLiteManualVacuumOption];
    }//end if (DebugLogLevel >= 1)
    
    if (isMacOS10_5OrAbove())
    {
      [options setValue:@YES forKey:NSMigratePersistentStoresAutomaticallyOption];
      NSDictionary* journalMode = @{@"journal_mode": @"DELETE"};
      [options setValue:journalMode forKey:NSSQLitePragmasOption];
    }//end if (isMacOS10_5OrAbove())
    if (isMacOS10_6OrAbove())
      [options setValue:@YES forKey:NSInferMappingModelAutomaticallyOption];
    persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                        configuration:nil URL:storeURL options:options error:&error];
    if (error)
      {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
    if (!persistentStore)
    {
      NSError* error = nil;
      [self _migrateLatexitManagedModel:path];
      persistentStore = [persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                          configuration:nil URL:storeURL options:options error:&error];
      if (error)
        {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
    }//end if (!persistentStore)
  }//end @try
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
  }//end @catch
  @finally{
  }//end @finally
  NSString* version = !persistentStore ? nil :
    [[persistentStoreCoordinator metadataForPersistentStore:persistentStore] valueForKey:@"version"];
  if ([version compare:@"2.0.0" options:NSNumericSearch] > 0){
  }
  if (setVersion && persistentStore)
  {
    NSString* applicationVersion = [[NSWorkspace sharedWorkspace] applicationVersion];
    [persistentStoreCoordinator setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:applicationVersion, @"version", nil]
                         forPersistentStore:persistentStore];
  }//end if (setVersion && persistentStore)
  result = !persistentStore ? nil : [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
  //[result setUndoManager:(!result ? nil : [[[NSUndoManagerDebug alloc] init] autorelease])];
  result.persistentStoreCoordinator = persistentStoreCoordinator;
  [result setRetainsRegisteredObjects:YES];
  #ifdef ARC_ENABLED
  #else
  [persistentStoreCoordinator release];
  #endif
  #ifdef ARC_ENABLED
  #else
  [result autorelease];
  #endif
  return result;
}
//end managedObjectContextAtPath:setVersion:

-(BOOL) saveAs:(NSString*)path onlySelection:(BOOL)onlySelection selection:(NSArray*)selectedItems format:(history_export_format_t)format
{
  BOOL ok = NO;
  NSArray* itemsToSave = nil;
  if (onlySelection)
    itemsToSave = selectedItems;
  else
  {
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [HistoryItem entity];
    itemsToSave = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
    #ifdef ARC_ENABLED
    #else
    [fetchRequest release];
    #endif
  }
  if (!itemsToSave)
    itemsToSave = @[];

  switch(format)
  {
    case HISTORY_EXPORT_FORMAT_INTERNAL:
      {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        ok = (![fileManager fileExistsAtPath:path isDirectory:&isDirectory] || (!isDirectory && [fileManager removeItemAtPath:path error:0]));
        if (ok)
        {
          BOOL done = NO;
          if (!onlySelection)
          {
            NSPersistentStoreCoordinator* persistentStoreCoordinator = [self->managedObjectContext persistentStoreCoordinator];
            NSArray* persistentStores = [persistentStoreCoordinator persistentStores];
            NSPersistentStore* singlePersistentStore = ([persistentStores count] != 1) ? nil : [persistentStores lastObject];
            NSURL* singlePersistentStoreURL = [singlePersistentStore URL];
            NSString* singlePersistentStorePath = [singlePersistentStoreURL path];
            if ([singlePersistentStorePath length])
            {
              NSError* error = nil;
              if ([self->managedObjectContext save:&error] && !error)
              {
                sqlite3* srcDB = 0;
                sqlite3* dstDB = 0;
                sqlite3_backup* backup = 0;
                NSInteger error = SQLITE_OK;
                if (error == SQLITE_OK)
                  error = sqlite3_open_v2([singlePersistentStorePath UTF8String], &srcDB, SQLITE_OPEN_READONLY, 0);
                if (error == SQLITE_OK)
                  error = sqlite3_open_v2([path UTF8String], &dstDB, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, 0);
                if (srcDB && dstDB && (error == SQLITE_OK))
                  backup = sqlite3_backup_init(dstDB, "main", srcDB, "main");
                if (backup && (error == SQLITE_OK))
                  sqlite3_backup_step(backup, -1);
                if (backup)
                  sqlite3_backup_finish(backup);
                done = (error == SQLITE_OK);
                if (dstDB)
                  sqlite3_close(dstDB);
                if (srcDB)
                  sqlite3_close(srcDB);
              }//end if ([self->managedObjectContext save:&error] && !error)
              else
                {DebugLog(0, @"error %@", error);}
            }//end if ([singlePersistentStorePath length])
          }//end if (!onlySelection)
          if (!done)
          {
            NSManagedObjectContext* saveManagedObjectContext = [self managedObjectContextAtPath:path setVersion:YES];
            NSData* data = [NSKeyedArchiver archivedDataWithRootObject:itemsToSave];
            [LatexitEquation pushManagedObjectContext:saveManagedObjectContext];
            NSArray* savedItems = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            [LatexitEquation popManagedObjectContext];
            NSError* error = nil;
            [saveManagedObjectContext save:&error];
            if (error)
              {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
            [savedItems makeObjectsPerformSelector:@selector(dispose)];
            done = YES;
          }//end if (!done)
        }//end if (ok)
      }//end case HISTORY_EXPORT_FORMAT_INTERNAL
      break;
    case HISTORY_EXPORT_FORMAT_PLIST:
      {
        NSMutableArray* descriptions = [NSMutableArray arrayWithCapacity:itemsToSave.count];
        NSEnumerator* enumerator = [itemsToSave objectEnumerator];
        LatexitEquation* equation = nil;
        while((equation = [enumerator nextObject]))
          [descriptions addObject:[equation plistDescription]];
        NSString* applicationVersion = [[NSWorkspace sharedWorkspace] applicationVersion];
        NSDictionary* library = !descriptions ? nil : [NSDictionary dictionaryWithObjectsAndKeys:
          [NSDictionary dictionaryWithObjectsAndKeys:descriptions, @"content", nil], @"history",
          applicationVersion, @"version",
          nil];
        NSError* errorDescription = nil;
        NSData* dataToWrite = !library ? nil :
          [NSPropertyListSerialization dataWithPropertyList:library format:NSPropertyListXMLFormat_v1_0 options:0 error:&errorDescription];
        if (errorDescription) {DebugLog(0, @"errorDescription : %@", errorDescription);}
        ok = [dataToWrite writeToFile:path atomically:YES];
        if (ok)
        {
          [[NSFileManager defaultManager]
             setAttributes:@{NSFileHFSCreatorCode: @((OSType)'LTXt')}
                     ofItemAtPath:path error:0];
          [[NSWorkspace sharedWorkspace] setIcon:[NSImage imageNamed:@"latexit-lib.icns"] forFile:path options:NSExclude10_4ElementsIconCreationOption];
        }//end if file has been created
      }//end case HISTORY_EXPORT_FORMAT_PLIST
      break;
  }
  return ok;
}
//end saveAs:onlySelection:selection:format:

-(BOOL) loadFrom:(NSString*)path option:(history_import_option_t)option
{
  BOOL ok = NO;

  NSUndoManager* undoManager = self->managedObjectContext.undoManager;
  [undoManager removeAllActions];
  [undoManager disableUndoRegistration];

  NSMutableArray* itemsToRemove = [NSMutableArray array];
  if (option == HISTORY_IMPORT_OVERWRITE)
  {
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [HistoryItem entity];
    NSError* error = nil;
    [itemsToRemove setArray:[self->managedObjectContext executeFetchRequest:fetchRequest error:&error]];
    if (error)
      {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
    #ifdef ARC_ENABLED
    #else
    [fetchRequest release];
    #endif
  }//end if (option == HISTORY_IMPORT_OVERWRITE)

  if ([path.pathExtension isEqualToString:@"latexhist"])
  {
    NSManagedObjectContext* sourceManagedObjectContext = [self managedObjectContextAtPath:path setVersion:NO];
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [HistoryItem entity];
    NSError* error = nil;
    NSArray* historyItemsToAdd = [sourceManagedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
    {
      ok = NO;
      DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);
    }
    #ifdef ARC_ENABLED
    #else
    [fetchRequest release];
    #endif
    
    NSData* historyItemsToAddAsData = !historyItemsToAdd ? nil :
      [NSKeyedArchiver archivedDataWithRootObject:historyItemsToAdd];
    if (historyItemsToAddAsData)
    {
      [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
      @try{
        [NSKeyedUnarchiver unarchiveObjectWithData:historyItemsToAddAsData];
        ok = YES;
      }
      @catch(NSException* e){
        DebugLog(0, @"exception : %@", e);
      }
      [LatexitEquation popManagedObjectContext];
    }//end if (historyItemsToAddAsData)
    NSEnumerator* enumerator = [historyItemsToAdd objectEnumerator];
    HistoryItem* historyItem = nil;
    while((historyItem = [enumerator nextObject]))
    {
      [[historyItem equation] dispose];
      [historyItem dispose];
    }//end for each historyItem
  }//end if ([[path pathExtension] isEqualToString:@"latexhist"])
  else if ([path.pathExtension isEqualToString:@"plist"])
  {
    NSData* data = [NSData dataWithContentsOfFile:path options:NSUncachedRead error:nil];
    NSError* errorDescription = nil;
    NSPropertyListFormat format = 0;
    id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format
      error:&errorDescription];
    if (errorDescription)
    {
      DebugLog(0, @"error : %@", errorDescription);
    }
    else if ([plist isKindOfClass:[NSDictionary class]])
    {
      NSString* version = plist[@"version"];
      BOOL isOldLibrary = ([version compare:@"2.0.0" options:NSNumericSearch] == NSOrderedAscending);
      id content = isOldLibrary ? nil : plist[@"history"];
      content = ![content isKindOfClass:[NSDictionary class]] ? nil : content[@"content"];
      if (isOldLibrary && !content)
        content = plist[@"content"];
      if ([content isKindOfClass:[NSArray class]])
      {
        [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
        @try{
          NSMutableArray* historyItemsAdded = [NSMutableArray arrayWithCapacity:[content count]];
          NSEnumerator* enumerator = [content objectEnumerator];
          id description = nil;
          while((description = [enumerator nextObject]))
          {
            HistoryItem* historyItem = [HistoryItem historyItemWithDescription:description];
            if (historyItem)
              [historyItemsAdded addObject:historyItem];
          }//end for each description
          ok = YES;
        }
        @catch(NSException* e){
          DebugLog(0, @"exception : %@", e);
        }
        [LatexitEquation popManagedObjectContext];
      }//end if ([content isKindOfClass:[NSArray class]])
    }//end if ([plist isKindOfClass:[NSDictionary class]])
  }//if ([[path pathExtension] isEqualToString:@"plist"])

  [self->managedObjectContext safeDeleteObjects:itemsToRemove];
  [self->managedObjectContext processPendingChanges];

  [undoManager enableUndoRegistration];
  return ok;
}
//end loadFrom:option:

-(void) _migrateLatexitManagedModel:(NSString*)path
{
  BOOL isManagedObjectModelPrevious250 = NO;
  BOOL isManagedObjectModelPrevious260 = NO;

  NSArray* oldDataModelNames = @[/*@"Latexit-2.5.0",*/ @"Latexit-2.4.0"];
  NSEnumerator* enumerator = [oldDataModelNames objectEnumerator];
  NSString* oldDataModelName = nil;
  id oldPersistentStore = nil;
  NSPersistentStoreCoordinator* oldPersistentStoreCoordinator = nil;
  NSString* oldPath = nil;
  NSManagedObjectModel* oldManagedObjectModel = nil;
  while(!oldPersistentStore && ((oldDataModelName = [enumerator nextObject])))
  {
    NSString* oldManagedObjectModelPath =
      [[NSBundle bundleForClass:[self class]] pathForResource:oldDataModelName ofType:@"mom"];
    NSURL* oldManagedObjectModelURL  = [NSURL fileURLWithPath:oldManagedObjectModelPath];
    oldManagedObjectModel =
      [[NSManagedObjectModel alloc] initWithContentsOfURL:oldManagedObjectModelURL];
    oldPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:oldManagedObjectModel];
    #ifdef ARC_ENABLED
    oldPath = [path copy];
    #else
    oldPath = [[path copy] autorelease];
    #endif
    NSURL* oldStoreURL = [NSURL fileURLWithPath:oldPath];
    @try{
      NSError* error = nil;
      oldPersistentStore = !oldStoreURL ? nil :
        [oldPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:oldStoreURL
                                                          options:nil error:&error];
      isManagedObjectModelPrevious260 = oldPersistentStore && !error;
      isManagedObjectModelPrevious250 = [oldDataModelName isEqualToString:@"Latexit-2.4.0"] && oldPersistentStore && !error;
      if (error)
        {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
    }
    @catch (NSException* e){
      DebugLog(0, @"exception : %@", e);
    }
    if (!oldPersistentStore)
    {
      #ifdef ARC_ENABLED
      #else
      [oldPersistentStoreCoordinator release];
      #endif
      oldPersistentStoreCoordinator = nil;
      oldPath = nil;
      #ifdef ARC_ENABLED
      #else
      [oldManagedObjectModel release];
      #endif
      oldManagedObjectModel = nil;
    }//end if (!oldPersistentStore)
  }//end for each oldDataModelName
  NSManagedObjectContext* oldManagedObjectContext = !oldPersistentStore ? nil : [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
  [oldManagedObjectContext setUndoManager:nil];
  oldManagedObjectContext.persistentStoreCoordinator = oldPersistentStoreCoordinator;

  NSManagedObjectModel* newManagedObjectModel = !isManagedObjectModelPrevious250 && !isManagedObjectModelPrevious260 ? nil :
    [[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel];
  NSPersistentStoreCoordinator* newPersistentStoreCoordinator =
    [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:newManagedObjectModel];
  NSString* newPath = nil;
  NSFileHandle* newPathFileHandle = !newPersistentStoreCoordinator ? nil :
    [[NSFileManager defaultManager]
      temporaryFileWithTemplate:[NSString stringWithFormat:@"%@.XXXXXXXX", oldPath.lastPathComponent] extension:@"db"
                    outFilePath:&newPath workingDirectory:[[NSWorkspace sharedWorkspace] temporaryDirectory]];
  newPathFileHandle = nil;
  NSURL* newStoreURL = !newPath ? nil : [NSURL fileURLWithPath:newPath];

  id newPersistentStore = nil;
  @try{
    NSError* error = nil;
    newPersistentStore = !newStoreURL ? nil :
      [newPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:newStoreURL
                                                        options:nil error:&error];
    if (error)
      {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
  }
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
  }

  NSManagedObjectContext* newManagedObjectContext = !newPersistentStore ? nil : [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
  [newManagedObjectContext setUndoManager:nil];
  newManagedObjectContext.persistentStoreCoordinator = newPersistentStoreCoordinator;

  NSModalSession migratingModalSession = 0;
  NSWindowController* migratingWindowController = nil;
  NSProgressIndicator* migratingProgressIndicator = nil;
  BOOL shouldDisplayMigrationProgression = (oldManagedObjectContext && newManagedObjectContext);
  if (shouldDisplayMigrationProgression)
    migratingModalSession =
      [self showMigratingProgressionWindow:&migratingWindowController progressIndicator:&migratingProgressIndicator];
  @try{
    BOOL migrationOK = NO;
    if (oldManagedObjectContext && newManagedObjectContext)
    {
      #ifdef ARC_ENABLED
      @autoreleasepool {
      #else
      NSAutoreleasePool* ap1 = [[NSAutoreleasePool alloc] init];
      #endif
      NSEntityDescription* oldHistoryItemEntityDescription = !oldManagedObjectContext ? nil :
        [NSEntityDescription entityForName:NSStringFromClass([HistoryItem class])
                    inManagedObjectContext:oldManagedObjectContext];
      NSFetchRequest* oldFetchRequest = !oldHistoryItemEntityDescription ? nil : [[NSFetchRequest alloc] init];
      oldFetchRequest.entity = oldHistoryItemEntityDescription;
      NSError* error = nil;
      NSArray* oldHistoryItems = !oldFetchRequest ? nil :
        [oldManagedObjectContext executeFetchRequest:oldFetchRequest error:&error];
      #ifdef ARC_ENABLED
      #else
      [oldFetchRequest release];
      #endif
      if (error)
        {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
        
      NSEnumerator* oldEnumerator = [oldHistoryItems objectEnumerator];
      HistoryItem* oldHistoryItem = nil;
      [LatexitEquation pushManagedObjectContext:newManagedObjectContext];
      @try{
        NSUInteger progression = 0;
        [migratingProgressIndicator setIndeterminate:NO];
        migratingProgressIndicator.minValue = 0;
        migratingProgressIndicator.maxValue = oldHistoryItems.count;
        migratingProgressIndicator.doubleValue = 0.;
        [migratingProgressIndicator display];
        while((oldHistoryItem = [oldEnumerator nextObject]))
        {
          #ifdef ARC_ENABLED
          @autoreleasepool{
          #else
          NSAutoreleasePool* ap2 = [[NSAutoreleasePool alloc] init];
          #endif
          [oldHistoryItem setCustomKVOInhibited:YES];
          id oldHistoryItemDescription = [oldHistoryItem plistDescription];
          [[oldHistoryItem equation] dispose];
          [oldHistoryItem dispose];
          HistoryItem* newHistoryItem = !oldHistoryItemDescription ? nil :
            [HistoryItem historyItemWithDescription:oldHistoryItemDescription];
          [newHistoryItem setDate:[newHistoryItem equation].date];
          [newHistoryItem dispose];
          migratingProgressIndicator.doubleValue = 1.*(progression++);
          if (!(progression%25))
            [migratingProgressIndicator display];
          #ifdef ARC_ENABLED
          }//end @autoreleasepool
          #else
          [ap2 drain];
          #endif
        }//end for each oldHistoryItem
        error = nil;
        [migratingProgressIndicator setIndeterminate:YES];
        [migratingProgressIndicator display];
        [newManagedObjectContext save:&error];
        if (!error)
          migrationOK = YES;
        else
          {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
      }//end for each historyItem
      @catch(NSException* e){
        DebugLog(0, @"exception : %@", e);
      }
      [LatexitEquation popManagedObjectContext];
      #ifdef ARC_ENABLED
      }//end @autoreleasepool
      #else
      [ap1 drain];
      #endif
    }//end if (oldManagedObjectContext && newManagedObjectContext)
    #ifdef ARC_ENABLED
    #else
    [oldManagedObjectContext release];
    [oldPersistentStoreCoordinator release];
    [oldManagedObjectModel release];
    [newPersistentStoreCoordinator release];
    [newManagedObjectContext release];
    #endif
    oldManagedObjectContext = nil;
    oldPersistentStoreCoordinator = nil;
    oldManagedObjectModel = nil;
    newManagedObjectContext = nil;
    newPersistentStoreCoordinator = nil;

    if (!migrationOK)
    {
      NSError* error = nil;
      [[NSFileManager defaultManager] removeItemAtPath:newPath error:&error];
      if (error)
        {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
    }//end if (!migrationOK)
    else if (migrationOK)
    {
      [migratingProgressIndicator setIndeterminate:YES];
      [migratingProgressIndicator display];
      NSError* error = nil;
      NSFileManager* fileManager = [NSFileManager defaultManager];
      BOOL removedOldStore = [fileManager removeItemAtPath:oldPath error:&error];
      if (error)
        {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
      if (!removedOldStore || error)
      {
        error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:newPath error:&error];
        if (error)
          {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
      }//end if (!removedOldStore || error)
      else//if (removedOldStore && !error)
      {
        BOOL movedNewStore = [fileManager moveItemAtPath:newPath toPath:oldPath error:&error];
        if (error)
          {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
        if (!movedNewStore)
        {
          error = nil;
          [[NSFileManager defaultManager] removeItemAtPath:newPath error:&error];
          if (error)
            {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
        }//end if (!movedNewStore)
      }//end if (removedOldStore)
    }//end if (migrationOK)
  }//end @try
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
  }
  @finally //if the history could not be created, make it (empty) now
  {
  }
  [self hideMigratingProgressionWindow:migratingModalSession windowController:migratingWindowController];
}
//end _migrateLatexitManagedModel:

-(NSModalSession) showMigratingProgressionWindow:(NSWindowController**)outMigratingWindowController
                               progressIndicator:(NSProgressIndicator**)outProgressIndicator
{
  NSModalSession result = 0;
  NSWindow* migratingWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 36) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:YES];
  #ifdef ARC_ENABLED
  NSWindowController* migratingWindowController = [[NSWindowController alloc] initWithWindow:migratingWindow];
  #else
  NSWindowController* migratingWindowController =
    [[[NSWindowController alloc] initWithWindow:migratingWindow] autorelease];
  #endif
  [migratingWindow center];
  [migratingWindow setTitle:NSLocalizedString(@"Migrating history to new format", @"Migrating history to new format")];
  NSRect contentView = migratingWindow.contentView.frame;
  NSProgressIndicator* progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSInsetRect(contentView, 8, 8)];
  [migratingWindow.contentView addSubview:progressIndicator];
  progressIndicator.minValue = 0.;
  [progressIndicator setUsesThreadedAnimation:YES];
  [progressIndicator startAnimation:self];
  #ifdef ARC_ENABLED
  #else
  [progressIndicator release];
  #endif
  progressIndicator = nil;
  [migratingWindowController showWindow:migratingWindow];
  if (outMigratingWindowController)
    *outMigratingWindowController = migratingWindowController;
  if (outProgressIndicator)
    *outProgressIndicator = progressIndicator;
  result = [NSApp beginModalSessionForWindow:migratingWindow];
  return result;
}
//end showMigratingProgressionWindow:

-(void) hideMigratingProgressionWindow:(NSModalSession)modalSession windowController:(NSWindowController*)windowController
{
  if (modalSession)
    [NSApp endModalSession:modalSession];
  [windowController close]; 
}
//end hideMigratingProgressionWindow:windowController:

-(void) vacuum
{
  NSPersistentStoreCoordinator* persistentStoreCoordinator = [self->managedObjectContext persistentStoreCoordinator];
  NSArray* persistentStores = [persistentStoreCoordinator persistentStores];
  NSEnumerator* enumerator = [persistentStores objectEnumerator];
  NSPersistentStore* persistentStore = nil;
  while((persistentStore = [enumerator nextObject]))
  {
    NSURL* url = [persistentStoreCoordinator URLForPersistentStore:persistentStore];
    NSString* filePath = [url path];
    sqlite3* db = 0;
    sqlite3_open_v2([filePath UTF8String], &db, SQLITE_OPEN_READWRITE, 0);
    if (db)
    {
      char* errmsg = 0;
      sqlite3_exec(db, "VACUUM", 0, 0, &errmsg);
      if (errmsg)
        DebugLog(0, @"VACUUM : %s", errmsg);
      sqlite3_close(db);
    }//end if (db)
  }//end for each persistentStore
}
//end vacuum

@end
