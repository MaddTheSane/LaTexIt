//  LibraryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.

//This file is the library manager, data source of every libraryTableView.
//It is a singleton, holding a single copy of the library items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

//Note that the library will be @synchronized

#import "LibraryManager.h"

#import "AppController.h"
#import "Compressor.h"
#import "HistoryItem.h"
#import "LatexitEquation.h"
#import "LaTeXProcessor.h"
#import "LibraryGroupItem.h"
#import "LibraryEquation.h"
#import "LibraryView.h"
#import "LibraryWindowController.h"
#import "NSArrayExtended.h"
#import "NSColorExtended.h"
#import "NSFileManagerExtended.h"
#import "NSIndexSetExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSObjectExtended.h"
#import "NSObjectTreeNode.h"
#import "NSUndoManagerDebug.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>

NSString* LibraryItemsArchivedPboardType = @"LibraryItemsArchivedPboardType";
NSString* LibraryItemsWrappedPboardType  = @"LibraryItemsWrappedPboardType";

@interface LibraryManager (PrivateAPI)
-(void) _migrateLatexitManagedModel:(NSString*)path;
-(NSManagedObjectContext*) managedObjectContextAtPath:(NSString*)path setVersion:(BOOL)setVersion;
-(void) applicationWillTerminate:(NSNotification*)aNotification; //saves library when quitting
-(void) saveLibrary;
-(void) createLibraryMigratingIfNeeded;
-(NSModalSession) showMigratingProgressionWindow:(NSWindowController**)outMigratingWindowController progressIndicator:(NSProgressIndicator**)outProgressIndicator;
-(void) hideMigratingProgressionWindow:(NSModalSession)modalSession windowController:(NSWindowController*)windowController;
@end

@implementation LibraryManager

static LibraryManager* sharedManagerInstance = nil;

+(LibraryManager*) sharedManager //access the unique instance of LibraryManager
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

-(id) init
{
  if (self && (self != sharedManagerInstance)) //do not recreate an instance
  {
    if ((!(self = [super init])))
      return nil;
    sharedManagerInstance = self;
    
    [self createLibraryMigratingIfNeeded];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                                 name:NSApplicationWillTerminateNotification object:nil];
  }//end if (self && (self != sharedManagerInstance)) //do not recreate an instance
  return self;
}
//end init

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->managedObjectContext release];
  [super dealloc];
}
//end dealloc

-(NSString*) defaultLibraryPath
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
                              @"library-default.latexlib", nil];
  result = [NSString pathWithComponents:libraryPathComponents];
  return result;
}
//end defaultLibraryPath

-(NSManagedObjectContext*) managedObjectContext
{
  return self->managedObjectContext;
}
//end managedObjectContext

-(NSUndoManager*) undoManager
{
  return [self->managedObjectContext undoManager];
}
//end undoManager

//triggers saving when app is quitting
-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  NSError* error = nil;
  [self->managedObjectContext save:&error];
  if (error)
    {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
}
//end applicationWillTerminate:

-(BOOL) saveAs:(NSString*)path onlySelection:(BOOL)onlySelection selection:(NSArray*)selectedItems format:(library_export_format_t)format
{
  BOOL ok = NO;
  NSArray* rootLibraryItemsToSave = nil;
  if (onlySelection)
    rootLibraryItemsToSave = [LibraryItem minimumNodeCoverFromItemsInArray:selectedItems parentSelector:@selector(parent)];
  else
  {
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[LibraryItem entity]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"parent == nil"]];
    rootLibraryItemsToSave = [NSMutableArray arrayWithArray:[[self managedObjectContext] executeFetchRequest:fetchRequest error:nil]];
    [fetchRequest release];
  }
  if (!rootLibraryItemsToSave)
    rootLibraryItemsToSave = [NSArray array];

  switch(format)
  {
    case LIBRARY_EXPORT_FORMAT_INTERNAL:
      {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        BOOL isDirectory = NO;
        ok = (![fileManager fileExistsAtPath:path isDirectory:&isDirectory] || (!isDirectory && [fileManager bridge_removeItemAtPath:path error:0]));
        if (ok)
        {
          NSManagedObjectContext* saveManagedObjectContext = [self managedObjectContextAtPath:path setVersion:YES];
          NSData* data = [NSKeyedArchiver archivedDataWithRootObject:rootLibraryItemsToSave];
          [LatexitEquation pushManagedObjectContext:saveManagedObjectContext];
          NSArray* libraryItems = [NSKeyedUnarchiver unarchiveObjectWithData:data];
          [LatexitEquation popManagedObjectContext];
          NSError* error = nil;
          [saveManagedObjectContext save:&error];
          if (error)
            {DebugLog(0, @"error : %@", error);}
          [libraryItems makeObjectsPerformSelector:@selector(dispose)];
        }//end if (ok)
      }//end case LIBRARY_EXPORT_FORMAT_INTERNAL
      break;
    case LIBRARY_EXPORT_FORMAT_PLIST:
      {
        NSMutableArray* descriptions = [NSMutableArray arrayWithCapacity:[rootLibraryItemsToSave count]];
        NSEnumerator* enumerator = [rootLibraryItemsToSave objectEnumerator];
        LibraryItem* libraryItem = nil;
        while((libraryItem = [enumerator nextObject]))
          [descriptions addObject:[libraryItem plistDescription]];
        NSDictionary* library = !descriptions ? nil : [NSDictionary dictionaryWithObjectsAndKeys:
          [NSDictionary dictionaryWithObjectsAndKeys:descriptions, @"content", nil], @"library",
          @"2.6.0", @"version", nil];
        NSString* errorDescription = nil;
        NSData* dataToWrite = !library ? nil :
          [NSPropertyListSerialization dataFromPropertyList:library format:NSPropertyListXMLFormat_v1_0 errorDescription:&errorDescription];
        if (errorDescription) {DebugLog(0, @"errorDescription : %@", errorDescription);}
        ok = [dataToWrite writeToFile:path atomically:YES];
        if (ok)
        {
          [[NSFileManager defaultManager]
             bridge_setAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt'] forKey:NSFileHFSCreatorCode]
                     ofItemAtPath:path error:0];
          [[NSWorkspace sharedWorkspace] setIcon:[NSImage imageNamed:@"latexit-lib.icns"] forFile:path options:NSExclude10_4ElementsIconCreationOption];
        }//end if file has been created
      }//end case LIBRARY_EXPORT_FORMAT_PLIST
      break;
  }

  NSError* error = nil;
  [self->managedObjectContext save:&error];
  if (error) {DebugLog(0, @"error : %@", error);}
  return ok;
}
//end saveAs:onlySelection:selection:format:

-(BOOL) loadFrom:(NSString*)path option:(library_import_option_t)option parent:(LibraryItem*)parent
{
  BOOL ok = NO;

  NSUndoManager* undoManager = [self->managedObjectContext undoManager];
  [undoManager removeAllActions];
  [undoManager disableUndoRegistration];
  NSMutableArray* itemsToRemove = [NSMutableArray array];
  if (option == LIBRARY_IMPORT_OVERWRITE)
  {
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[LibraryItem entity]];
    NSError* error = nil;
    [itemsToRemove setArray:[self->managedObjectContext executeFetchRequest:fetchRequest error:&error]];
    if (error) {DebugLog(0, @"error : %@", error);}
    [fetchRequest release];
    
    [itemsToRemove makeObjectsPerformSelector:@selector(dispose)];
    [self->managedObjectContext safeDeleteObjects:itemsToRemove];
    [self->managedObjectContext processPendingChanges];
    [itemsToRemove removeAllObjects];
  }//end if (option == LIBRARY_IMPORT_OVERWRITE)

  if (option == LIBRARY_IMPORT_OPEN)
  {
    NSManagedObjectContext* newManagedObjectContext = [self managedObjectContextAtPath:path setVersion:NO];
    ok = (newManagedObjectContext != nil);
    if (ok)
    {
      [self->managedObjectContext release];
      self->managedObjectContext = newManagedObjectContext;
      [[PreferencesController sharedController] setLibraryPath:path];
    }//end if (ok)
  }//end if (options == LIBRARY_IMPORT_OPEN)
  else// if ((option == LIBRARY_IMPORT_MERGE) || (option == LIBRARY_IMPORT_OVERWRITE))
  {
    if ([[path pathExtension] isEqualToString:@"latexlib"] || [[path pathExtension] isEqualToString:@"dat"])
    {
      NSManagedObjectContext* sourceManagedObjectContext = [self managedObjectContextAtPath:path setVersion:NO];
      if (!sourceManagedObjectContext)//maybe it is old format ?
      {
        BOOL migrationError = NO;
        NSError* error = nil;
        NSData* fileData = [NSData dataWithContentsOfFile:path options:NSUncachedRead error:&error];
        if (error) {DebugLog(0, @"error : %@", error);}
        NSPropertyListFormat format = 0;
        NSString* errorDescription = nil;
        id plist =
          [NSPropertyListSerialization propertyListFromData:fileData mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&errorDescription];
        if (errorDescription) {DebugLog(0, @"errorDescription : %@", errorDescription);}
        NSData* compressedData = nil;
        if (!plist)
          compressedData = fileData;
        else if ([plist isKindOfClass:[NSDictionary class]])
          compressedData = [plist objectForKey:@"data"];
        NSData* uncompressedData = [Compressor zipuncompress:compressedData];
        if (!uncompressedData) uncompressedData = [Compressor zipuncompressDeprecated:compressedData];
        if (uncompressedData)
        {
          unsigned int nbRootLibraryItemsBeforeAdding = [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
          [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
          NSArray* libraryItemsAdded = nil;
          @try{
            [NSKeyedUnarchiver setClass:[LibraryEquation class] forClassName:@"LibraryFile"];
            [NSKeyedUnarchiver setClass:[LibraryGroupItem class] forClassName:@"LibraryFolder"];
            libraryItemsAdded = [NSArray arrayWithObjects:[NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData], nil];
            [self->managedObjectContext processPendingChanges];
          }
          @catch(NSException* e){
            migrationError = YES;
            DebugLog(0, @"exception : %@", e);
          }
          [LatexitEquation popManagedObjectContext];
          unsigned int sortIndex = 0;
          NSEnumerator* parentEnumerator = [libraryItemsAdded objectEnumerator];
          LibraryGroupItem* parentLibraryItem = nil;
          while((parentLibraryItem = [parentEnumerator nextObject]))
          {
            //remove dummy top-level group items from legacy data
            if ([parentLibraryItem isKindOfClass:[LibraryGroupItem class]] && ![parentLibraryItem parent])
            {
              [itemsToRemove addObject:parentLibraryItem];
              NSArray* childrenOrdered = [NSArray arrayWithArray:[(LibraryGroupItem*)parentLibraryItem childrenOrdered]];
              NSEnumerator* childEnumerator = [childrenOrdered objectEnumerator];
              LibraryItem* child = nil;
              while((child = [childEnumerator nextObject]))
              {
                [child setParent:nil];
                [child setSortIndex:nbRootLibraryItemsBeforeAdding+(sortIndex++)];
              }
            }
            else
              [parentLibraryItem setSortIndex:nbRootLibraryItemsBeforeAdding+(sortIndex++)];
          }
          migrationError |= (error != nil);
          ok = !migrationError;
        }//end if (uncompressedData)
      }
      else
      {
        NSError* error = nil;
        unsigned int nbRootLibraryItemsBeforeAdding = [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
        if (error) {ok = NO; DebugLog(0, @"error : %@", error);}
        NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:[LibraryItem entity]];
        error = nil;
        NSArray* libraryItemsToAdd = [sourceManagedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (error) {ok = NO; DebugLog(0, @"error : %@", error);}
        [fetchRequest release];
        NSData* libraryItemsToAddAsData = [NSKeyedArchiver archivedDataWithRootObject:libraryItemsToAdd];
        [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
        NSArray* libraryItemsAdded = [NSKeyedUnarchiver unarchiveObjectWithData:libraryItemsToAddAsData];
        [LatexitEquation popManagedObjectContext];
        unsigned int i = 0;
        unsigned int count = [libraryItemsAdded count];
        for(i = 0 ; i<count ; ++i)
          [[libraryItemsAdded objectAtIndex:i] setSortIndex:nbRootLibraryItemsBeforeAdding+i];
          
        NSEnumerator* enumerator = [libraryItemsToAdd objectEnumerator];
        LibraryItem* libraryItem = nil;
        while((libraryItem = [enumerator nextObject]))
        {
          if ([libraryItem isKindOfClass:[LibraryEquation class]])
          {
            [[(LibraryEquation*)libraryItem equation] dispose];
            [libraryItem dispose];
          }//end if ([libraryItem isKindOfClass:[LibraryEquation class]])
        }//end for each libraryItem

        ok = YES;
      }//end if (ok)
    }//end if ([[path pathExtension] isEqualToString:@"latexlib"] || [[path pathExtension] isEqualToString:@"dat"])
    else if ([[path pathExtension] isEqualToString:@"latexhist"] )
    {
      NSManagedObjectContext* sourceManagedObjectContext = [self managedObjectContextAtPath:path setVersion:NO];
      NSError* error = nil;
      unsigned int nbRootLibraryItemsBeforeAdding =
        [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
      if (error) {ok = NO; DebugLog(0, @"error : %@", error);}
      NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
      [fetchRequest setEntity:[HistoryItem entity]];
      error = nil;
      NSArray* historyItemsToAdd = [sourceManagedObjectContext executeFetchRequest:fetchRequest error:&error];
      if (error) {ok = NO; DebugLog(0, @"error : %@", error);}
      [fetchRequest release];
      NSData* historyItemsToAddAsData = [NSKeyedArchiver archivedDataWithRootObject:historyItemsToAdd];
      [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
      NSArray* historyItemsAdded = [NSKeyedUnarchiver unarchiveObjectWithData:historyItemsToAddAsData];
      [LatexitEquation popManagedObjectContext];
      unsigned int i = 0;
      unsigned int count = [historyItemsAdded count];
      for(i = 0 ; i<count ; ++i)
      {
        HistoryItem* historyItem = [historyItemsAdded objectAtIndex:i];
        LibraryEquation* libraryEquation =
          [[LibraryEquation alloc] initWithParent:nil equation:[historyItem equation]
             insertIntoManagedObjectContext:[historyItem managedObjectContext]];
        [libraryEquation setBestTitle];
        [libraryEquation release];
        [[historyItem managedObjectContext] safeDeleteObject:historyItem];
        [libraryEquation setSortIndex:nbRootLibraryItemsBeforeAdding+i];
      }//end for each historyItemAdded

      //dispose objets of sourceManagedObjectContext
      NSEnumerator* enumerator = [historyItemsToAdd objectEnumerator];
      HistoryItem* historyItem = nil;
      while((historyItem = [enumerator nextObject]))
      {
        [[historyItem equation] dispose];
        [historyItem dispose];
      }//end for each historyItem
      ok = YES;
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
        id content = isOldLibrary ? nil : [plist objectForKey:@"library"];
        content = ![content isKindOfClass:[NSDictionary class]] ? nil : [content objectForKey:@"content"];
        if (isOldLibrary && !content)
          content = [plist objectForKey:@"content"];
        BOOL wasHistory = NO;
        if (!content)
        {
          content = [[plist objectForKey:@"history"] objectForKey:@"content"];
          wasHistory = (content != nil);
        }
        if ([content isKindOfClass:[NSArray class]])
        {
          NSError* error = nil;
          unsigned int nbRootLibraryItemsBeforeAdding = [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
          [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
          NSMutableArray* libraryItemsAdded = [NSMutableArray arrayWithCapacity:[content count]];
          NSEnumerator* enumerator = [content objectEnumerator];
          id description = nil;
          unsigned int sortIndex = 0;
          while((description = [enumerator nextObject]))
          {
            LibraryItem* libraryItem = [LibraryItem libraryItemWithDescription:description];
            if (libraryItem)
            {
              [libraryItemsAdded addObject:libraryItem];
              if (isOldLibrary)
                [libraryItem setSortIndex:sortIndex++];
            }
            if (wasHistory)
              [libraryItem setBestTitle];
          }//end for each libraryItemDescription
          [LatexitEquation popManagedObjectContext];
          unsigned int i = 0;
          unsigned int count = [libraryItemsAdded count];
          for(i = 0 ; i<count ; ++i)
            [[libraryItemsAdded objectAtIndex:i] setSortIndex:nbRootLibraryItemsBeforeAdding+i];
          ok = YES;
        }//end if ([content isKindOfClass:[NSArray class]])
      }//end if ([plist isKindOfClass:[NSDictionary class]])
    }
    else if ([[path pathExtension] isEqualToString:@"library"]) //from LEE
    {
      NSString* xmlDescriptionPath = [path stringByAppendingPathComponent:@"library.dict"];
      NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
      NSString* errorDescription = nil;
      id plist = [NSPropertyListSerialization propertyListFromData:[NSData dataWithContentsOfFile:xmlDescriptionPath options:NSUncachedRead error:nil]
                                                  mutabilityOption:NSPropertyListImmutable format:&format errorDescription:&errorDescription];
      if (errorDescription)
      {
        DebugLog(0, @"error : %@", errorDescription);
      }
      else if ([plist isKindOfClass:[NSDictionary class]])
      {
        NSMutableArray* latexitEquations = [NSMutableArray arrayWithCapacity:[plist count]];
        NSEnumerator* enumerator = [(NSDictionary*)plist keyEnumerator];
        id key = nil;
        while((key = [enumerator nextObject]))
        {
          id item = [(NSDictionary*)plist objectForKey:key];
          if ([item isKindOfClass:[NSDictionary class]])
          {
            NSString* pdfFile = [path stringByAppendingPathComponent:[(NSDictionary*)item objectForKey:@"filename"]];
            NSData* someData = !pdfFile ? nil : [NSData dataWithContentsOfFile:pdfFile options:NSUncachedRead error:nil];
            LatexitEquation* latexitEquation = !someData ? nil : [LatexitEquation latexitEquationWithPDFData:someData useDefaults:YES];
            if (latexitEquation)
              [latexitEquations addObject:latexitEquation];
          }//end if ([item isKindOfClass:[NSDictionary class]])
        }//end for each key
        if ([latexitEquations count])
        {
          NSError* error = nil;
          unsigned int nbRootLibraryItemsBeforeAdding = [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
          unsigned int count = [latexitEquations count];
          unsigned int i = 0;
          for(i = 0 ; i<count ; ++i)
          {
            LatexitEquation* latexitEquation = [latexitEquations objectAtIndex:i];
            LibraryEquation* libraryEquation =
              [[LibraryEquation alloc] initWithParent:nil equation:latexitEquation insertIntoManagedObjectContext:self->managedObjectContext];
            [libraryEquation setSortIndex:nbRootLibraryItemsBeforeAdding+i];
            NSString* title = [libraryEquation title];
            if (!title)
              [libraryEquation setBestTitle];
            [libraryEquation release];
          }//end for each latexitEquation
        }//end if ([latexitEquations count])
        ok = YES;
      }//end if ([plist isKindOfClass:[NSDictionary class]])
    }//end if  ([[path pathExtension] isEqualToString:@"library"]) //from LEE
  }//end if (option != LIBRARY_IMPORT_OPEN)

  [itemsToRemove makeObjectsPerformSelector:@selector(dispose)];
  [self->managedObjectContext safeDeleteObjects:itemsToRemove];
  [self->managedObjectContext processPendingChanges];

  [self->managedObjectContext disableUndoRegistration];
  [self fixChildrenSortIndexesForParent:nil recursively:YES];
  [self->managedObjectContext enableUndoRegistration];

  [undoManager enableUndoRegistration];
  return ok;
}
//end loadFrom:option:

-(void) fixChildrenSortIndexesForParent:(LibraryGroupItem*)parent recursively:(BOOL)recursively
{
  if (parent)
    [parent fixChildrenSortIndexesRecursively:recursively];
  else //if (!parent)
  {
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[LibraryItem entity]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"parent == nil"]];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObjects:
      [[[NSSortDescriptor alloc] initWithKey:@"sortIndex" ascending:YES] autorelease], nil]];
    NSError* error = nil;
    NSArray* rootItemsOrdered = [self->managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error) {DebugLog(0, @"error : %@", error);}
    [fetchRequest release];

    unsigned int i = 0;
    unsigned int n = [rootItemsOrdered count];
    for(i = 0 ; i<n ; ++i)
    {
      LibraryItem* libraryItem = [rootItemsOrdered objectAtIndex:i];
      [libraryItem setSortIndex:i];
      if (recursively && [libraryItem isKindOfClass:[LibraryGroupItem class]])
        [(LibraryGroupItem*)libraryItem fixChildrenSortIndexesRecursively:YES];
    }//end for each root node
  }//end if (!parent)
}
//end fixSortIndices

-(NSArray*) libraryEquations
{
  NSArray* result = nil;
  NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
  [fetchRequest setEntity:[LibraryEquation entity]];
  NSError* error = nil;
  result = [self->managedObjectContext executeFetchRequest:fetchRequest error:&error];
  if (error)
    {DebugLog(0, @"error : %@", error);}
  [fetchRequest release];
  return result;
}
//end libraryEquations

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
    NSDictionary* options = nil;
    if (isMacOS10_6OrAbove())
      options = [NSDictionary dictionaryWithObjectsAndKeys:
                  [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                  [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                  nil];
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
  NSString* version = [[persistentStoreCoordinator metadataForPersistentStore:persistentStore] valueForKey:@"version"];
  if ([version compare:@"2.0.0" options:NSNumericSearch] > 0){
  }
  if (setVersion && persistentStore)
    [persistentStoreCoordinator setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:@"2.6.0", @"version", nil]
                         forPersistentStore:persistentStore];
  result = !persistentStore ? nil : [[NSManagedObjectContext alloc] init];
  //[result setUndoManager:(!result ? nil : [[[NSUndoManagerDebug alloc] init] autorelease])];
  [result setPersistentStoreCoordinator:persistentStoreCoordinator];
  [result setRetainsRegisteredObjects:YES];
  [persistentStoreCoordinator release];
  return [result autorelease];
}
//end managedObjectContextAtPath:setVersion:

-(void) createLibraryMigratingIfNeeded
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

    NSString* newFilePath  = [[PreferencesController sharedController] libraryPath];
    if (!newFilePath)
      newFilePath = [self defaultLibraryPath];
    NSString* oldFilePath = nil;
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        [NSArray arrayWithObjects:userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName], @"library.latexlib", nil];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        [NSArray arrayWithObjects:userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName], @"library.dat", nil];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        [NSArray arrayWithObjects:userLibraryPath, [[NSWorkspace sharedWorkspace] applicationName], @"library.latexlib", nil];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        [NSArray arrayWithObjects:userLibraryPath, [[NSWorkspace sharedWorkspace] applicationName], @"library.dat", nil];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }

    BOOL shouldMigrateLibraryToCoreData = ![fileManager isReadableFileAtPath:newFilePath] && oldFilePath;
    
    NSString* libraryPath = [[PreferencesController sharedController] libraryPath];
    BOOL isDirectory = NO;
    BOOL exists = libraryPath && [fileManager fileExistsAtPath:libraryPath isDirectory:&isDirectory] && !isDirectory &&
                  [fileManager isReadableFileAtPath:libraryPath];

    if (!exists)
    {
      libraryPath = [self defaultLibraryPath];
      if (![fileManager isReadableFileAtPath:libraryPath])
        [fileManager bridge_createDirectoryAtPath:[libraryPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:0];
    }//end if (!exists)
    
    self->managedObjectContext = [[self managedObjectContextAtPath:libraryPath setVersion:NO] retain];
    NSPersistentStoreCoordinator* persistentStoreCoordinator = [self->managedObjectContext persistentStoreCoordinator];
    NSArray* persistentStores = [persistentStoreCoordinator persistentStores];
    id oldVersionObject =
      [[persistentStoreCoordinator metadataForPersistentStore:[persistentStores lastObject]] objectForKey:@"version"];
    NSString* oldVersion = [oldVersionObject isKindOfClass:[NSString class]] ? (NSString*)[[oldVersionObject copy] autorelease] : nil;
    
    BOOL shouldMigrateLibraryToAlign = ([oldVersion compare:@"2.1.0"] == NSOrderedAscending);

    BOOL shouldDisplayMigrationProgression = (shouldMigrateLibraryToCoreData && [[NSApp class] isEqual:[NSApplication class]]) ||
                                             shouldMigrateLibraryToAlign;
    BOOL migrationError = NO;
    if (shouldDisplayMigrationProgression)
      migratingModalSession =
        [self showMigratingProgressionWindow:&migratingWindowController progressIndicator:&migratingProgressIndicator];

    if (shouldMigrateLibraryToCoreData)
    {
      BOOL ok = [self loadFrom:oldFilePath option:LIBRARY_IMPORT_OVERWRITE parent:nil];
      if (ok)
        [[NSFileManager defaultManager] bridge_removeItemAtPath:oldFilePath error:0];
    }
    else if (shouldMigrateLibraryToAlign)
    {
      NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
      [fetchRequest setEntity:[LatexitEquation entity]];
      NSError* error = nil;
      NSArray* latexitEquations = [self->managedObjectContext executeFetchRequest:fetchRequest error:&error];
      unsigned int progression = 0;
      unsigned int count = [latexitEquations count];
      [migratingProgressIndicator setIndeterminate:NO];
      [migratingProgressIndicator setMaxValue:1.*count];
      [migratingProgressIndicator setDoubleValue:0.];
      [migratingProgressIndicator display];
      if (error)
        DebugLog(0, @"error : %@", error);
      NSEnumerator* enumerator = [latexitEquations objectEnumerator];
      LatexitEquation* latexitEquation = nil;
      @try{
        while((latexitEquation = [enumerator nextObject]))
        {
          [latexitEquation checkAndMigrateAlign];//force fetch and update
          [migratingProgressIndicator setDoubleValue:1.*(progression++)];
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
      [fetchRequest release];
      error = nil;
      [self->managedObjectContext save:&error];
      if (error)
        DebugLog(0, @"error : %@", error);
    }//end if (shouldMigrateLibraryToAlign)
    
    if (!migrationError)
    {
      NSEnumerator* enumerator = [persistentStores objectEnumerator];
      id persistentStore = nil;
      while((persistentStore = [enumerator nextObject]))
        [persistentStoreCoordinator setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:@"2.6.0", @"version", nil]
                             forPersistentStore:persistentStore];
    }//end if (!migrationError)
  }
  @catch(NSException* e) //reading may fail for some reason
  {
    DebugLog(0, @"exception : %@", e);
  }
  @finally //if the library could not be created, make it (empty) now
  {
  }
  [self fixChildrenSortIndexesForParent:nil recursively:YES];
  [self hideMigratingProgressionWindow:migratingModalSession windowController:migratingWindowController];
}
//end createLibraryMigratingIfNeeded

-(void) _migrateLatexitManagedModel:(NSString*)path
{
  BOOL isManagedObjectModelPrevious250 = NO;
  BOOL isManagedObjectModelPrevious260 = NO;

  NSArray* oldDataModelNames = [NSArray arrayWithObjects:/*@"Latexit-2.5.0",*/ @"Latexit-2.4.0", nil];
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
    oldPath = [[path copy] autorelease];
    NSURL* oldStoreURL = [NSURL fileURLWithPath:oldPath];
    @try{
      NSError* error = nil;
      oldPersistentStore = !oldStoreURL ? nil :
        [oldPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:oldStoreURL
                                                          options:nil error:&error];
      isManagedObjectModelPrevious260 = oldPersistentStore && !error;
      isManagedObjectModelPrevious250 = [oldDataModelName isEqualToString:@"Latexit-2.4.0"] && oldPersistentStore && !error;
      if (error)
        {DebugLog(0, @"error : %@", error);}
    }
    @catch (NSException* e){
      DebugLog(0, @"exception : %@", e);
    }
    if (!oldPersistentStore)
    {
      [oldPersistentStoreCoordinator release];
      oldPersistentStoreCoordinator = nil;
      oldPath = nil;
      [oldManagedObjectModel release];
      oldManagedObjectModel = nil;
    }//end if (!oldPersistentStore)
  }//end for each oldDataModelName
  NSManagedObjectContext* oldManagedObjectContext = !oldPersistentStore ? nil : [[NSManagedObjectContext alloc] init];
  [oldManagedObjectContext setUndoManager:nil];
  [oldManagedObjectContext setPersistentStoreCoordinator:oldPersistentStoreCoordinator];

  NSManagedObjectModel* newManagedObjectModel = !isManagedObjectModelPrevious250 && !isManagedObjectModelPrevious260 ? nil :
    [[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel];
  NSPersistentStoreCoordinator* newPersistentStoreCoordinator =
    [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:newManagedObjectModel];
  NSString* newPath = nil;
  NSFileHandle* newPathFileHandle = !newPersistentStoreCoordinator ? nil :
    [[NSFileManager defaultManager]
      temporaryFileWithTemplate:[NSString stringWithFormat:@"%@.XXXXXXXX", [oldPath lastPathComponent]] extension:@"db"
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
      {DebugLog(0, @"error : %@", error);}
  }
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
  }

  NSManagedObjectContext* newManagedObjectContext = !newPersistentStore ? nil : [[NSManagedObjectContext alloc] init];
  [newManagedObjectContext setUndoManager:nil];
  [newManagedObjectContext setPersistentStoreCoordinator:newPersistentStoreCoordinator];

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
      NSAutoreleasePool* ap1 = [[NSAutoreleasePool alloc] init];
      NSEntityDescription* oldLibraryItemEntityDescription = !oldManagedObjectContext ? nil :
        [NSEntityDescription entityForName:NSStringFromClass([LibraryItem class])
                    inManagedObjectContext:oldManagedObjectContext];
      NSFetchRequest* oldFetchRequest = !oldLibraryItemEntityDescription ? nil : [[NSFetchRequest alloc] init];
      [oldFetchRequest setEntity:oldLibraryItemEntityDescription];
      [oldFetchRequest setPredicate:[NSPredicate predicateWithFormat:@"parent=%@", nil]];
      NSError* error = nil;
      NSArray* oldLibraryItems = !oldFetchRequest ? nil :
        [oldManagedObjectContext executeFetchRequest:oldFetchRequest error:&error]; 
      [oldFetchRequest release];
      if (error)
        {DebugLog(0, @"error : %@", error);}
      NSEnumerator* oldEnumerator = nil;
      LibraryItem* oldLibraryItem = nil;
      
      oldEnumerator = [oldLibraryItems objectEnumerator];
      oldLibraryItem = nil;
      [LatexitEquation pushManagedObjectContext:newManagedObjectContext];
      @try{
        NSUInteger progression = 0;
        [migratingProgressIndicator setIndeterminate:NO];
        [migratingProgressIndicator setMinValue:0];
        [migratingProgressIndicator setMaxValue:[oldLibraryItems count]];
        [migratingProgressIndicator setDoubleValue:0.];
        [migratingProgressIndicator display];
        while((oldLibraryItem = [oldEnumerator nextObject]))
        {
          NSAutoreleasePool* ap2 = [[NSAutoreleasePool alloc] init];
          LibraryEquation* oldLibraryEquation = [oldLibraryItem dynamicCastToClass:[LibraryEquation class]];
          [oldLibraryEquation setCustomKVOInhibited:YES];
          id oldLibraryItemDescription = [oldLibraryItem plistDescription];
          [[oldLibraryEquation equation] dispose];
          [oldLibraryItem dispose];//disables KVO
          LibraryItem* newLibraryItem = !oldLibraryItemDescription ? nil :
            [LibraryItem libraryItemWithDescription:oldLibraryItemDescription];
          [newLibraryItem dispose];
          [migratingProgressIndicator setDoubleValue:1.*(progression++)];
          if (!(progression%25))
            [migratingProgressIndicator display];
          [ap2 drain];
        }//end for each oldLibraryItem
        error = nil;
        [newManagedObjectContext save:&error];
        if (!error)
          migrationOK = YES;
        else
          {DebugLog(0, @"error : %@", error);}
      }//end for each libraryItem
      @catch(NSException* e){
        DebugLog(0, @"exception : %@", e);
      }
      [LatexitEquation popManagedObjectContext];
      [ap1 drain];
    }//end if (oldManagedObjectContext && newManagedObjectContext)
    [oldManagedObjectContext release];
    oldManagedObjectContext = nil;
    [oldPersistentStoreCoordinator release];
    oldPersistentStoreCoordinator = nil;
    [oldManagedObjectModel release];
    oldManagedObjectModel = nil;
    [newManagedObjectContext release];
    newManagedObjectContext = nil;
    [newPersistentStoreCoordinator release];
    newPersistentStoreCoordinator = nil;

    if (!migrationOK)
    {
      NSError* error = nil;
      [[NSFileManager defaultManager] bridge_removeItemAtPath:newPath error:&error];
      if (error)
        {DebugLog(0, @"error : %@", error);}
    }//end if (!migrationOK)
    else if (migrationOK)
    {
      NSError* error = nil;
      NSFileManager* fileManager = [NSFileManager defaultManager];
      BOOL removedOldStore = [fileManager bridge_removeItemAtPath:oldPath error:&error];
      if (error)
        {DebugLog(0, @"error : %@", error);}
      if (!removedOldStore || error)
      {
        error = nil;
        [[NSFileManager defaultManager] bridge_removeItemAtPath:newPath error:&error];
        if (error)
          {DebugLog(0, @"error : %@", error);}
      }//end if (!removedOldStore || error)
      else//if (removedOldStore && !error)
      {
        BOOL movedNewStore = [fileManager bridge_moveItemAtPath:newPath toPath:oldPath error:&error];
        if (error)
          {DebugLog(0, @"error : %@", error);}
        if (!movedNewStore)
        {
          error = nil;
          [[NSFileManager defaultManager] bridge_removeItemAtPath:newPath error:&error];
          if (error)
            {DebugLog(0, @"error : %@", error);}
        }//end if (!movedNewStore)
      }//end if (removedOldStore)
    }//end if (migrationOK)
  }//end @try
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
  }
  @finally //if the library could not be created, make it (empty) now
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
  NSWindowController* migratingWindowController =
    [[[NSWindowController alloc] initWithWindow:migratingWindow] autorelease];
  [migratingWindow center];
  [migratingWindow setTitle:NSLocalizedString(@"Migrating library to new format", @"Migrating library to new format")];
  NSRect contentView = [[migratingWindow contentView] frame];
  NSProgressIndicator* progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSInsetRect(contentView, 8, 8)];
  [[migratingWindow contentView] addSubview:progressIndicator];
  [progressIndicator setMinValue:0.];
  [progressIndicator setUsesThreadedAnimation:YES];
  [progressIndicator startAnimation:self];
  [progressIndicator release];
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

@end
