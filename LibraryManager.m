//  LibraryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//This file is the library manager, data source of every libraryTableView.
//It is a singleton, holding a single copy of the library items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

//Note that the library will be @synchronized

#import "LibraryManager.h"

#import "AppController.h"
#import "Compressor.h"
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
#import "NSObjectTreeNode.h"
#import "NSUndoManagerDebug.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>

NSString* LibraryItemsArchivedPboardType = @"LibraryItemsArchivedPboardType";
NSString* LibraryItemsWrappedPboardType  = @"LibraryItemsWrappedPboardType";

@interface LibraryManager (PrivateAPI)
-(NSManagedObjectContext*) managedObjectContextAtPath:(NSString*)path;
-(void) applicationWillTerminate:(NSNotification*)aNotification; //saves library when quitting
-(void) saveLibrary;
-(void) createLibraryMigratingIfNeeded;
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
        ok = (![fileManager fileExistsAtPath:path isDirectory:&isDirectory] || (!isDirectory && [fileManager removeFileAtPath:path handler:nil]));
        if (ok)
        {
          NSManagedObjectContext* saveManagedObjectContext = [self managedObjectContextAtPath:path];
          NSData* data = [NSKeyedArchiver archivedDataWithRootObject:rootLibraryItemsToSave];
          [LatexitEquation pushManagedObjectContext:saveManagedObjectContext];
          [NSKeyedUnarchiver unarchiveObjectWithData:data];
          [LatexitEquation popManagedObjectContext];
          NSError* error = nil;
          [saveManagedObjectContext save:&error];
          if (error)
            {DebugLog(0, @"error : %@", error);}
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
          @"2.0.1", @"version",
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
  }//end if (option == LIBRARY_IMPORT_OVERWRITE)

  if (option == LIBRARY_IMPORT_OPEN)
  {
    NSManagedObjectContext* newManagedObjectContext = [self managedObjectContextAtPath:path];
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
      NSManagedObjectContext* sourceManagedObjectContext = [self managedObjectContextAtPath:path];
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
        ok = YES;
      }//end if (ok)
    }//end if ([[path pathExtension] isEqualToString:@"latexlib"])
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
          }
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

  NSEnumerator* enumerator = [itemsToRemove objectEnumerator];
  NSManagedObject* object = nil;
  while((object = [enumerator nextObject]))
    [self->managedObjectContext safeDeleteObject:object];
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
  [result setUndoManager:(!result ? nil : [[[NSUndoManagerDebug alloc] init] autorelease])];
  [result setPersistentStoreCoordinator:persistentStoreCoordinator];
  [persistentStoreCoordinator release];
  [result setRetainsRegisteredObjects:YES];
  return [result autorelease];
}
//end managedObjectContextAtPath:

-(void) createLibraryMigratingIfNeeded
{
  NSWindowController*  migratingWindowController = nil;
  NSModalSession       modalSession              = 0;
  NSProgressIndicator* progressIndicator         = nil;

  NSFileManager* fileManager = [NSFileManager defaultManager];

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

    BOOL shouldMigrateLibrary = ![fileManager isReadableFileAtPath:newFilePath] && oldFilePath;
    BOOL shouldDisplayMigrationProgression = shouldMigrateLibrary && [[NSApp class] isEqual:[NSApplication class]];
    if (shouldDisplayMigrationProgression)
    {
      NSWindow* migratingWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 36) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:YES];
      migratingWindowController = [[[NSWindowController alloc] initWithWindow:migratingWindow] autorelease];
      [migratingWindow center];
      [migratingWindow setTitle:NSLocalizedString(@"Migrating library to new format", @"Migrating library to new format")];
      NSRect contentView = [[migratingWindow contentView] frame];
      progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSInsetRect(contentView, 8, 8)];
      [[migratingWindow contentView] addSubview:progressIndicator];
      [progressIndicator setMinValue:0.];
      [progressIndicator setUsesThreadedAnimation:YES];
      [progressIndicator startAnimation:self];
      [progressIndicator setIndeterminate:YES];
      [progressIndicator release];
      [migratingWindowController showWindow:migratingWindow];
      modalSession = [NSApp beginModalSessionForWindow:migratingWindow];
    }//end if ([[NSApp class] isEqual:[NSApplication class]])

    NSString* libraryPath = [[PreferencesController sharedController] libraryPath];
    BOOL isDirectory = NO;
    BOOL exists = libraryPath && [fileManager fileExistsAtPath:libraryPath isDirectory:&isDirectory] && !isDirectory &&
                  [fileManager isReadableFileAtPath:libraryPath];
    if (!exists)
    {
      libraryPath = [self defaultLibraryPath];
      if (![fileManager isReadableFileAtPath:libraryPath])
        [fileManager createDirectoryPath:[libraryPath stringByDeletingLastPathComponent] attributes:nil];
    }
    
    self->managedObjectContext = [[self managedObjectContextAtPath:libraryPath] retain];

    if (shouldMigrateLibrary)
    {
      BOOL ok = [self loadFrom:oldFilePath option:LIBRARY_IMPORT_OVERWRITE parent:nil];
      if (ok)
        [[NSFileManager defaultManager] removeFileAtPath:oldFilePath handler:0];
    }
  }
  @catch(NSException* e) //reading may fail for some reason
  {
    DebugLog(0, @"exception : %@", e);
  }
  @finally //if the history could not be created, make it (empty) now
  {
  }
  
  [self fixChildrenSortIndexesForParent:nil recursively:YES];

  if (modalSession) [NSApp endModalSession:modalSession];
  [[migratingWindowController window] close]; 
}
//end createLibraryMigratingIfNeeded

@end
