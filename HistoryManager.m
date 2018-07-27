//  HistoryManager.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.

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
#import "PreferencesController.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>

@interface HistoryManager (PrivateAPI)
-(NSString*) defaultHistoryPath;
-(NSManagedObjectContext*) managedObjectContextAtPath:(NSString*)path setVersion:(BOOL)setVersion;
-(void) applicationWillTerminate:(NSNotification*)aNotification; //saves history when quitting
-(void) saveHistory;
-(void) createHistoryMigratingIfNeeded;
-(BOOL) tableView:(NSTableView*)tableView writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard;
-(BOOL) tableView:(NSTableView*)tableView writeRowsWithIndexes:(NSIndexSet*)rowIndexes toPasteboard:(NSPasteboard*)pboard;
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

-(NSUInteger) retainCount
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

    self->bindController = [[NSObjectController alloc] initWithContent:self];
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
  [self->managedObjectContext release];
  [self->bindController release];
  [super dealloc];
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

-(void) deleteOldEntries
{
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSNumber* historyDeleteOldEntriesLimit = ![preferencesController historyDeleteOldEntriesEnabled] ? nil :
    [preferencesController historyDeleteOldEntriesLimit];
  NSDate* oldestDate = !historyDeleteOldEntriesLimit ? nil :
    [[NSCalendarDate calendarDate] dateByAddingYears:0 months:0 days:-[historyDeleteOldEntriesLimit intValue] hours:0 minutes:0 seconds:0];
  if (oldestDate)
  {
    NSPredicate* predicate = [NSPredicate predicateWithFormat:@"date < %@" argumentArray:[NSArray arrayWithObjects:oldestDate, nil]];
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[LatexitEquation entity]];
    [fetchRequest setPredicate:predicate];
    NSError* error = nil;
    NSArray* oldEntries = [self->managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
      {DebugLog(0, @"error : %@", error);}
    NSArray* oldHistoryItems = [oldEntries valueForKey:@"wrapper"];
    [fetchRequest release];
    if ([oldHistoryItems count])
    {
      [self->managedObjectContext disableUndoRegistration];
      [self->managedObjectContext safeDeleteObjects:oldHistoryItems];
      [self->managedObjectContext enableUndoRegistration];
    }//end if ([oldHistoryItems count])
  }//end if (oldestDate)
}
//end deleteOldEntries

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

    BOOL shouldMigrateHistoryToCoreData = ![fileManager isReadableFileAtPath:newFilePath] && oldFilePath;

    BOOL isDirectory = NO;
    BOOL exists = [fileManager fileExistsAtPath:newFilePath isDirectory:&isDirectory] && !isDirectory &&
                  [fileManager isReadableFileAtPath:newFilePath];
    if (!exists)
      [fileManager createDirectoryPath:[newFilePath stringByDeletingLastPathComponent] attributes:nil];

    self->managedObjectContext = [[self managedObjectContextAtPath:newFilePath setVersion:NO] retain];
    NSPersistentStoreCoordinator* persistentStoreCoordinator = [self->managedObjectContext persistentStoreCoordinator];
    NSArray* persistentStores = [persistentStoreCoordinator persistentStores];
    id oldVersionObject =
      [[persistentStoreCoordinator metadataForPersistentStore:[persistentStores lastObject]] objectForKey:@"version"];
    NSString* oldVersion = [oldVersionObject isKindOfClass:[NSString class]] ? (NSString*)[[oldVersionObject copy] autorelease] : nil;
    BOOL shouldMigrateHistoryToAlign = ([oldVersion compare:@"2.1.0"] == NSOrderedAscending);

    BOOL shouldDisplayMigrationProgression = (shouldMigrateHistoryToCoreData && [[NSApp class] isEqual:[NSApplication class]]) ||
                                             shouldMigrateHistoryToAlign;
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

    BOOL migrationError = NO;
    if (shouldMigrateHistoryToCoreData)
    {
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
        [progressIndicator setDoubleValue:0.];
        HistoryItem* historyItem = nil;
        NSEnumerator* enumerator = [historyItems objectEnumerator];
        unsigned int progression = 0;
        [[self->managedObjectContext undoManager] removeAllActions];
        [self->managedObjectContext disableUndoRegistration];
        while((historyItem = [enumerator nextObject]))
        {
          [self->managedObjectContext safeInsertObject:historyItem];
          [self->managedObjectContext safeInsertObject:[historyItem equation]];
          [progressIndicator setDoubleValue:1.*(progression++)];
          if (!(progression%25))
            [progressIndicator display];
        }//end for each historyItem
        [self->managedObjectContext enableUndoRegistration];
      }//end if (uncompressedData)
      migrationError |= (error != nil);
      if (!migrationError)
        [[NSFileManager defaultManager] removeFileAtPath:oldFilePath handler:0];
    }//end if (shouldMigrateHistoryToCoreData)
    else if (shouldMigrateHistoryToAlign)
    {
      NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
      [fetchRequest setEntity:[LatexitEquation entity]];
      NSError* error = nil;
      NSArray* latexitEquations = [self->managedObjectContext executeFetchRequest:fetchRequest error:&error];
      unsigned int progression = 0;
      unsigned int count = [latexitEquations count];
      [progressIndicator setIndeterminate:NO];
      [progressIndicator setMaxValue:1.*count];
      [progressIndicator setDoubleValue:0.];
      [progressIndicator display];
      if (error)
        DebugLog(0, @"error : %@", error);
      NSEnumerator* enumerator = [latexitEquations objectEnumerator];
      LatexitEquation* latexitEquation = nil;
      @try{
        while((latexitEquation = [enumerator nextObject]))
        {
          [latexitEquation checkAndMigrateAlign];//force fetch and update
          [progressIndicator setDoubleValue:1.*(progression++)];
          if (!(progression%25))
            [progressIndicator display];
        }//end for each latexitEquation
      }
      @catch(NSException* e){
        DebugLog(0, @"exception : %@", e);
        migrationError = YES;
      }
      @finally{
      }
      [fetchRequest release];
      error = nil;
      [self->managedObjectContext save:&error];
      if (error)
        DebugLog(0, @"error : %@", error);
    }//end if (shouldMigrateHistoryToAlign)
    
    if (!migrationError)
    {
      NSEnumerator* enumerator = [persistentStores objectEnumerator];
      id persistentStore = nil;
      while((persistentStore = [enumerator nextObject]))
        [persistentStoreCoordinator setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:@"2.4.1", @"version", nil]
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

  if (modalSession)
    [NSApp endModalSession:modalSession];
  [migratingWindowController close]; 
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
  if (setVersion && persistentStore)
    [persistentStoreCoordinator setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:@"2.4.1", @"version", nil]
                         forPersistentStore:persistentStore];
  result = !persistentStore ? nil : [[NSManagedObjectContext alloc] init];
  //[result setUndoManager:(!result ? nil : [[[NSUndoManagerDebug alloc] init] autorelease])];
  [result setPersistentStoreCoordinator:persistentStoreCoordinator];
  [persistentStoreCoordinator release];
  [result setRetainsRegisteredObjects:YES];
  return [result autorelease];
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
    [fetchRequest setEntity:[HistoryItem entity]];
    itemsToSave = [[self managedObjectContext] executeFetchRequest:fetchRequest error:nil];
    [fetchRequest release];
  }
  if (!itemsToSave)
    itemsToSave = [NSArray array];

  switch(format)
  {
    case HISTORY_EXPORT_FORMAT_INTERNAL:
      {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        ok = (![fileManager fileExistsAtPath:path isDirectory:&isDirectory] || (!isDirectory && [fileManager removeFileAtPath:path handler:nil]));
        if (ok)
        {
          NSManagedObjectContext* saveManagedObjectContext = [self managedObjectContextAtPath:path setVersion:YES];
          NSData* data = [NSKeyedArchiver archivedDataWithRootObject:itemsToSave];
          [LatexitEquation pushManagedObjectContext:saveManagedObjectContext];
          NSArray* savedItems = [NSKeyedUnarchiver unarchiveObjectWithData:data];
          [LatexitEquation popManagedObjectContext];
          NSError* error = nil;
          [saveManagedObjectContext save:&error];
          if (error)
            {DebugLog(0, @"error : %@", error);}
          [savedItems makeObjectsPerformSelector:@selector(dispose)];
        }//end if (ok)
      }//end case HISTORY_EXPORT_FORMAT_INTERNAL
      break;
    case HISTORY_EXPORT_FORMAT_PLIST:
      {
        NSMutableArray* descriptions = [NSMutableArray arrayWithCapacity:[itemsToSave count]];
        NSEnumerator* enumerator = [itemsToSave objectEnumerator];
        LatexitEquation* equation = nil;
        while((equation = [enumerator nextObject]))
          [descriptions addObject:[equation plistDescription]];
        NSDictionary* library = !descriptions ? nil : [NSDictionary dictionaryWithObjectsAndKeys:
          [NSDictionary dictionaryWithObjectsAndKeys:descriptions, @"content", nil], @"history",
          @"2.4.1", @"version",
          nil];
        NSString* errorDescription = nil;
        NSData* dataToWrite = !library ? nil :
          [NSPropertyListSerialization dataFromPropertyList:library format:NSPropertyListXMLFormat_v1_0 errorDescription:&errorDescription];
        if (errorDescription) {DebugLog(0, @"errorDescription : %@", errorDescription);}
        ok = [dataToWrite writeToFile:path atomically:YES];
        if (ok)
        {
          [[NSFileManager defaultManager]
             changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt'] forKey:NSFileHFSCreatorCode]
                                                              atPath:path];
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

  NSUndoManager* undoManager = [self->managedObjectContext undoManager];
  [undoManager removeAllActions];
  [undoManager disableUndoRegistration];

  NSMutableArray* itemsToRemove = [NSMutableArray array];
  if (option == HISTORY_IMPORT_OVERWRITE)
  {
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[HistoryItem entity]];
    NSError* error = nil;
    [itemsToRemove setArray:[self->managedObjectContext executeFetchRequest:fetchRequest error:&error]];
    if (error) {DebugLog(0, @"error : %@", error);}
    [fetchRequest release];
  }//end if (option == HISTORY_IMPORT_OVERWRITE)

  if ([[path pathExtension] isEqualToString:@"latexhist"])
  {
    NSManagedObjectContext* sourceManagedObjectContext = [self managedObjectContextAtPath:path setVersion:NO];
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[HistoryItem entity]];
    NSError* error = nil;
    NSArray* historyItemsToAdd = [sourceManagedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
    {
      ok = NO;
      DebugLog(0, @"error : %@", error);
    }
    [fetchRequest release];
    
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
  else if ([[path pathExtension] isEqualToString:@"plist"])
  {
    NSData* data = [NSData dataWithContentsOfFile:path options:NSUncachedRead error:nil];
    NSString* errorDescription = nil;
    NSPropertyListFormat format = 0;
    id plist = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:&format
      errorDescription:&errorDescription];
    if (errorDescription)
    {
      DebugLog(0, @"error : %@", errorDescription);
    }
    else if ([plist isKindOfClass:[NSDictionary class]])
    {
      NSString* version = [plist objectForKey:@"version"];
      BOOL isOldLibrary = ([version compare:@"2.0.0" options:NSNumericSearch] == NSOrderedAscending);
      id content = isOldLibrary ? nil : [plist objectForKey:@"history"];
      content = ![content isKindOfClass:[NSDictionary class]] ? nil : [content objectForKey:@"content"];
      if (isOldLibrary && !content)
        content = [plist objectForKey:@"content"];
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
//end loadFrom:


@end
