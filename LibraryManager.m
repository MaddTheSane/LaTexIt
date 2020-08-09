//  LibraryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.

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
#import "NSStringExtended.h"
#import "NSObjectExtended.h"
#import "NSObjectTreeNode.h"
#import "NSUndoManagerDebug.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"
#import "RegexKitLite.h"
#import "TeXItemWrapper.h"
#import "Utils.h"

#import <LinkBack/LinkBack.h>
#include <sqlite3.h>

NSString* const LibraryItemsArchivedPboardType = @"LibraryItemsArchivedPboardType";
NSString* const LibraryItemsWrappedPboardType  = @"LibraryItemsWrappedPboardType";

@interface LibraryManager ()
-(void) _migrateLatexitManagedModel:(NSString*)path;
-(NSManagedObjectContext*) managedObjectContextAtPath:(NSString*)path setVersion:(BOOL)setVersion;
-(void) applicationWillTerminate:(NSNotification*)aNotification; //saves library when quitting
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
  return NSUIntegerMax;  //denotes an object that cannot be released
}

-(oneway void) release
{
}

-(id) autorelease
{
  return self;
}

-(instancetype) init
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
    @[userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName],
                              @"library-default.latexlib"];
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
  return self->managedObjectContext.undoManager;
}
//end undoManager

//triggers saving when app is quitting
-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  [self saveLibrary];
}
//end applicationWillTerminate:

-(NSArray*) allItems
{
  NSArray* result = nil;
  NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
  fetchRequest.entity = [LibraryItem entity];
  NSError* error = nil;
  NSArray* itemsToRemove = [[self->managedObjectContext executeFetchRequest:fetchRequest error:&error] dynamicCastToClass:[NSArray class]];
  result = [[itemsToRemove copy] autorelease];
  if (error)
    {DebugLog(0, @"error : %@", error);}
  [fetchRequest release];
  return result;
}
//end allItems

-(void) removeAllItems
{
  @autoreleasepool {
  NSArray* itemsToRemove = [self allItems];
  if (itemsToRemove.count)
  {
    [itemsToRemove makeObjectsPerformSelector:@selector(dispose)];
    [self->managedObjectContext safeDeleteObjects:itemsToRemove];
    [self->managedObjectContext processPendingChanges];
  }//end if ([itemsToRemove count])
  }//end @autoreleasepool
}
//end removeAllItems

-(void) removeItems:(NSArray*)items
{
  @autoreleasepool {
  NSArray* itemsToRemove = [items copy];
  if (itemsToRemove.count)
  {
    [itemsToRemove makeObjectsPerformSelector:@selector(dispose)];
    [self->managedObjectContext safeDeleteObjects:itemsToRemove];
    [self->managedObjectContext processPendingChanges];
  }//end if ([itemsToRemove count])
    [itemsToRemove release];
  }//end @autoreleasepool
}
//end removeItems:

-(BOOL) saveAs:(NSString*)path onlySelection:(BOOL)onlySelection selection:(NSArray*)selectedItems format:(library_export_format_t)format
       options:(NSDictionary*)options
{
  BOOL ok = NO;
  NSArray* rootLibraryItemsToSave = nil;
  if (onlySelection)
    rootLibraryItemsToSave = [LibraryItem minimumNodeCoverFromItemsInArray:selectedItems parentSelector:@selector(parent)];
  else
  {
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    fetchRequest.entity = [LibraryItem entity];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"parent == nil"];
    rootLibraryItemsToSave = [NSMutableArray arrayWithArray:[[self managedObjectContext] executeFetchRequest:fetchRequest error:nil]];
    [fetchRequest release];
  }
  if (!rootLibraryItemsToSave)
    rootLibraryItemsToSave = @[];

  switch(format)
  {
    case LIBRARY_EXPORT_FORMAT_INTERNAL:
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
                int error = SQLITE_OK;
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
            NSData* data = [NSKeyedArchiver archivedDataWithRootObject:rootLibraryItemsToSave];
            [LatexitEquation pushManagedObjectContext:saveManagedObjectContext];
            NSArray* libraryItems = [NSKeyedUnarchiver unarchiveObjectWithData:data];
            [LatexitEquation popManagedObjectContext];
            NSError* error = nil;
            [saveManagedObjectContext save:&error];
            if (error)
              {DebugLog(0, @"error : %@", error);}
            [libraryItems makeObjectsPerformSelector:@selector(dispose)];
            done = YES;
          }//end if (!done)
        }//end if (ok)
      }//end case LIBRARY_EXPORT_FORMAT_INTERNAL
      break;
    case LIBRARY_EXPORT_FORMAT_PLIST:
      {
        NSString* applicationVersion = [[NSWorkspace sharedWorkspace] applicationVersion];
        NSMutableArray* descriptions = [NSMutableArray arrayWithCapacity:rootLibraryItemsToSave.count];
        NSEnumerator* enumerator = [rootLibraryItemsToSave objectEnumerator];
        LibraryItem* libraryItem = nil;
        while((libraryItem = [enumerator nextObject]))
          [descriptions addObject:[libraryItem plistDescription]];
        NSDictionary* library = !descriptions ? nil : @{
          @"library":[NSDictionary dictionaryWithObjectsAndKeys:descriptions, @"content", nil],
          @"version":applicationVersion};
        NSError* errorDescription = nil;
        NSData* dataToWrite = !library ? nil :
          [NSPropertyListSerialization dataWithPropertyList:library format:NSPropertyListXMLFormat_v1_0 options:0 error:&errorDescription];
        if (errorDescription)
          {DebugLog(0, @"errorDescription : %@", errorDescription);}
        ok = [dataToWrite writeToFile:path atomically:YES];
        if (ok)
        {
          [[NSFileManager defaultManager] setAttributes:@{NSFileHFSCreatorCode:@((OSType)'LTXt')} ofItemAtPath:path error:0];
          [[NSWorkspace sharedWorkspace] setIcon:[NSImage imageNamed:@"latexit-lib.icns"] forFile:path options:NSExclude10_4ElementsIconCreationOption];
        }//end if file has been created
      }//end case LIBRARY_EXPORT_FORMAT_PLIST
      break;
    case LIBRARY_EXPORT_FORMAT_TEX_SOURCE:
    {
      NSMutableString* dataString = [NSMutableString string];
      NSMutableArray* queue = [NSMutableArray arrayWithArray:rootLibraryItemsToSave];
      LibraryItem* libraryItem = nil;
      while((libraryItem = !queue.count ? nil : queue[0]))
      {
        [queue removeObjectAtIndex:0];
        LibraryEquation* libraryEquation = [libraryItem dynamicCastToClass:[LibraryEquation class]];
        LibraryGroupItem* libraryGroupItem = [libraryItem dynamicCastToClass:[LibraryGroupItem class]];
        if (libraryGroupItem)
          [queue addObjectsFromArray:[libraryGroupItem childrenOrdered:nil]];
        else if (libraryEquation)
        {
          BOOL exportCommentedPreambles = [[options[@"exportCommentedPreambles"] dynamicCastToClass:[NSNumber class]] boolValue];
          BOOL exportUserComments = [[options[@"exportUserComments"] dynamicCastToClass:[NSNumber class]] boolValue];
          BOOL ignoreTitleHierarchy = [[options[@"ignoreTitleHierarchy"] dynamicCastToClass:[NSNumber class]] boolValue];
          NSString* titlePath = ignoreTitleHierarchy ? libraryItem.title : [[[libraryItem titlePath] componentsJoinedByString:@"/"] trim];
          NSString* titlePathEscaped = [titlePath stringByReplacingOccurrencesOfString:@"$" withString:@"\\$"];
          LatexitEquation* equation = libraryEquation.equation;
          NSString* preamble = !exportCommentedPreambles ? nil : [equation.preamble.string trim];
          NSString* source = [equation.sourceText.string trim];
          NSString* comments = !exportUserComments ? nil : [libraryEquation.comment trim];
          BOOL hasComments = comments && ![comments isEqualToString:@""];
          latex_mode_t mode = equation.mode;
          NSArray* preambleLines = [preamble componentsSeparatedByString:@"\n"];
          NSString* preambleWithComments = !preambleLines.count ? @"" :
            [NSString stringWithFormat:@"%%%@", [preambleLines componentsJoinedByString:@"\n%"]];
          NSString* beginEnvironment =
            (mode == LATEX_MODE_DISPLAY) ? @"\\begin{equation*}" :
            (mode == LATEX_MODE_INLINE) ? @"\\begin{equation*}" :
            (mode == LATEX_MODE_TEXT) ? @"\\begin{equation*}" :
            (mode == LATEX_MODE_ALIGN) ? @"\\begin{equation*}\n\\begin{aligned}" :
            @"";
          NSString* endEnvironment =
            (mode == LATEX_MODE_DISPLAY) ? @"\\end{equation*}" :
            (mode == LATEX_MODE_INLINE) ? @"\\end{equation*}" :
            (mode == LATEX_MODE_TEXT) ? @"\\end{equation*}" :
            (mode == LATEX_MODE_ALIGN) ? @"\\end{aligned}\n\\end{equation*}" :
            @"";
          NSString* equationWithLabel =
            [NSString stringWithFormat:
               @"\\subsection*{%@}\n"
                "\\label{%@}\n"
                "%@\n"
                "%@"
                "%@\n"
                "%@\n"
                "%@\n",
               titlePath, titlePathEscaped,
               beginEnvironment,
               !exportCommentedPreambles ? @"" : [NSString stringWithFormat:@"%%preamble\n%@\n",preambleWithComments],
               source,
               endEnvironment,
               !hasComments ? @"" : [NSString stringWithFormat:@"%@", comments]
            ];
          [dataString appendFormat:@"%@%@", !dataString.length ? @"" : @"\n", equationWithLabel];
        }//end if (libraryEquation)
      }//end for each root library item
      NSData* dataToWrite = [dataString dataUsingEncoding:NSUTF8StringEncoding];
      ok = [dataToWrite writeToFile:path atomically:YES];
    }//end case LIBRARY_EXPORT_FORMAT_TEX_SOURCE
    break;
  }//end switch(format)

  NSError* error = nil;
  [self->managedObjectContext save:&error];
  if (error)
    {DebugLog(0, @"error : %@", error);}
  return ok;
}
//end saveAs:onlySelection:selection:format:

-(BOOL) loadFrom:(NSString*)path option:(library_import_option_t)option parent:(LibraryItem*)parent
{
  BOOL ok = NO;

  NSUndoManager* undoManager = self->managedObjectContext.undoManager;
  [undoManager removeAllActions];
  [undoManager disableUndoRegistration];
  NSMutableArray* itemsToRemove = [NSMutableArray array];
  if (option == LIBRARY_IMPORT_OVERWRITE)
  {
    BOOL delayDeletion = ([path.pathExtension isEqualToString:@"tex"]);
    if (!delayDeletion)
      [self removeAllItems];
  }//end if (option == LIBRARY_IMPORT_OVERWRITE)

  if (option == LIBRARY_IMPORT_OPEN)
  {
    NSManagedObjectContext* newManagedObjectContext = [self managedObjectContextAtPath:path setVersion:NO];
    ok = (newManagedObjectContext != nil);
    if (ok)
    {
      [self->managedObjectContext release];
      self->managedObjectContext = newManagedObjectContext;
      [PreferencesController sharedController].libraryPath = path;
    }//end if (ok)
  }//end if (options == LIBRARY_IMPORT_OPEN)
  else//if ((option == LIBRARY_IMPORT_MERGE) || (option == LIBRARY_IMPORT_OVERWRITE))
  {
    if ([path.pathExtension isEqualToString:@"latexlib"] || [path.pathExtension isEqualToString:@"dat"])
    {
      NSManagedObjectContext* sourceManagedObjectContext = [self managedObjectContextAtPath:path setVersion:NO];
      if (!sourceManagedObjectContext)//maybe it is old format ?
      {
        BOOL migrationError = NO;
        NSError* error = nil;
        NSData* fileData = [NSData dataWithContentsOfFile:path options:NSUncachedRead error:&error];
        if (error)
          {DebugLog(0, @"error : %@", error);}
        NSPropertyListFormat format = 0;
        NSError* errorDescription = nil;
        id plist =
          [NSPropertyListSerialization propertyListWithData:fileData options:NSPropertyListImmutable format:&format error:&errorDescription];
        if (errorDescription)
          {DebugLog(0, @"errorDescription : %@", errorDescription);}
        NSData* compressedData = nil;
        if (!plist)
          compressedData = fileData;
        else if ([plist isKindOfClass:[NSDictionary class]])
          compressedData = plist[@"data"];
        NSData* uncompressedData = [Compressor zipuncompress:compressedData];
        if (!uncompressedData) uncompressedData = [Compressor zipuncompressDeprecated:compressedData];
        if (uncompressedData)
        {
          NSUInteger nbRootLibraryItemsBeforeAdding = [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
          [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
          NSArray* libraryItemsAdded = nil;
          @try{
            [NSKeyedUnarchiver setClass:[LibraryEquation class] forClassName:@"LibraryFile"];
            [NSKeyedUnarchiver setClass:[LibraryGroupItem class] forClassName:@"LibraryFolder"];
            libraryItemsAdded = @[[NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData]];
            [self->managedObjectContext processPendingChanges];
          }
          @catch(NSException* e){
            migrationError = YES;
            DebugLog(0, @"exception : %@", e);
          }
          [LatexitEquation popManagedObjectContext];
          NSUInteger sortIndex = 0;
          NSEnumerator* parentEnumerator = [libraryItemsAdded objectEnumerator];
          LibraryGroupItem* parentLibraryItem = nil;
          while((parentLibraryItem = [parentEnumerator nextObject]))
          {
            //remove dummy top-level group items from legacy data
            if ([parentLibraryItem isKindOfClass:[LibraryGroupItem class]] && !parentLibraryItem.parent)
            {
              [itemsToRemove addObject:parentLibraryItem];
              NSArray* childrenOrdered = [NSArray arrayWithArray:[(LibraryGroupItem*)parentLibraryItem childrenOrdered:nil]];
              NSEnumerator* childEnumerator = [childrenOrdered objectEnumerator];
              LibraryItem* child = nil;
              while((child = [childEnumerator nextObject]))
              {
                [child setParent:nil];
                child.sortIndex = nbRootLibraryItemsBeforeAdding+(sortIndex++);
              }
            }
            else
              parentLibraryItem.sortIndex = nbRootLibraryItemsBeforeAdding+(sortIndex++);
          }
          migrationError |= (error != nil);
          ok = !migrationError;
        }//end if (uncompressedData)
      }//end if (!sourceManagedObjectContext)//maybe it is old format ?
      else
      {
        NSError* error = nil;
        NSUInteger nbRootLibraryItemsBeforeAdding = [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
        if (error)
        {
          ok = NO;
          DebugLog(0, @"error : %@", error);
        }//end if (error)
        NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
        fetchRequest.entity = [LibraryItem entity];
        fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"sortIndex" ascending:YES]];
        error = nil;
        NSArray* libraryItemsToAdd = [sourceManagedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
          ok = NO;
          DebugLog(0, @"error : %@", error);
        }//end if (error)
        [fetchRequest release];
        NSData* libraryItemsToAddAsData = [NSKeyedArchiver archivedDataWithRootObject:libraryItemsToAdd];
        [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
        NSArray* libraryItemsAdded = [NSKeyedUnarchiver unarchiveObjectWithData:libraryItemsToAddAsData];
        [LatexitEquation popManagedObjectContext];
        NSUInteger count = libraryItemsAdded.count;
        for(NSUInteger i = 0 ; i<count ; ++i)
          [libraryItemsAdded[i] setSortIndex:nbRootLibraryItemsBeforeAdding+i];
        
        NSEnumerator* enumerator = [libraryItemsToAdd objectEnumerator];
        LibraryItem* libraryItem = nil;
        while((libraryItem = [enumerator nextObject]))
        {
          if ([libraryItem isKindOfClass:[LibraryEquation class]])
          {
            [((LibraryEquation*)libraryItem).equation dispose];
            [libraryItem dispose];
          }//end if ([libraryItem isKindOfClass:[LibraryEquation class]])
        }//end for each libraryItem

        ok = YES;
      }//end if (ok)
    }//end if ([[path pathExtension] isEqualToString:@"latexlib"] || [[path pathExtension] isEqualToString:@"dat"])
    else if ([path.pathExtension isEqualToString:@"latexhist"] )
    {
      NSManagedObjectContext* sourceManagedObjectContext = [self managedObjectContextAtPath:path setVersion:NO];
      NSError* error = nil;
      NSUInteger nbRootLibraryItemsBeforeAdding =
        [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
      if (error)
      {
        ok = NO;
        DebugLog(0, @"error : %@", error);
      }//end if (error)
      NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
      fetchRequest.entity = [HistoryItem entity];
      error = nil;
      NSArray* historyItemsToAdd = [sourceManagedObjectContext executeFetchRequest:fetchRequest error:&error];
      if (error)
      {
        ok = NO;
        DebugLog(0, @"error : %@", error);
      }//end if (error)
      [fetchRequest release];
      NSData* historyItemsToAddAsData = [NSKeyedArchiver archivedDataWithRootObject:historyItemsToAdd];
      [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
      NSArray* historyItemsAdded = [NSKeyedUnarchiver unarchiveObjectWithData:historyItemsToAddAsData];
      [LatexitEquation popManagedObjectContext];
      NSUInteger i = 0;
      NSUInteger count = [historyItemsAdded count];
      for(i = 0 ; i<count ; ++i)
      {
        HistoryItem* historyItem = historyItemsAdded[i];
        LibraryEquation* libraryEquation =
          [[LibraryEquation alloc] initWithParent:nil equation:[historyItem equation]
             insertIntoManagedObjectContext:historyItem.managedObjectContext];
        [libraryEquation setBestTitle];
        [libraryEquation release];
        [historyItem.managedObjectContext safeDeleteObject:historyItem];
        libraryEquation.sortIndex = nbRootLibraryItemsBeforeAdding+i;
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
    else if ([path.pathExtension isEqualToString:@"plist"])
    {
      NSData* data = [NSData dataWithContentsOfFile:path options:NSUncachedRead error:nil];
      NSError* errorDescription = nil;
      NSPropertyListFormat format = 0;
      id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:&format
        error:&errorDescription];
      if (errorDescription)
        {DebugLog(0, @"error : %@", errorDescription);}
      else if ([plist isKindOfClass:[NSDictionary class]])
      {
        NSString* version = plist[@"version"];
        BOOL isOldLibrary = ([version compare:@"2.0.0" options:NSNumericSearch] == NSOrderedAscending);
        id content = isOldLibrary ? nil : plist[@"library"];
        content = ![content isKindOfClass:[NSDictionary class]] ? nil : content[@"content"];
        if (isOldLibrary && !content)
          content = plist[@"content"];
        BOOL wasHistory = NO;
        if (!content)
        {
          content = plist[@"history"][@"content"];
          wasHistory = (content != nil);
        }
        if ([content isKindOfClass:[NSArray class]])
        {
          NSError* error = nil;
          NSUInteger nbRootLibraryItemsBeforeAdding = [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
          [LatexitEquation pushManagedObjectContext:self->managedObjectContext];
          NSMutableArray* libraryItemsAdded = [NSMutableArray arrayWithCapacity:[content count]];
          NSEnumerator* enumerator = [content objectEnumerator];
          id description = nil;
          NSUInteger sortIndex = 0;
          while((description = [enumerator nextObject]))
          {
            LibraryItem* libraryItem = [LibraryItem libraryItemWithDescription:description];
            if (libraryItem)
            {
              [libraryItemsAdded addObject:libraryItem];
              if (isOldLibrary)
                libraryItem.sortIndex = sortIndex++;
            }
            if (wasHistory)
              [libraryItem setBestTitle];
          }//end for each libraryItemDescription
          [LatexitEquation popManagedObjectContext];
          NSUInteger i = 0;
          NSUInteger count = [libraryItemsAdded count];
          for(i = 0 ; i<count ; ++i)
            [[libraryItemsAdded objectAtIndex:i] setSortIndex:nbRootLibraryItemsBeforeAdding+i];
          ok = YES;
        }//end if ([content isKindOfClass:[NSArray class]])
      }//end if ([plist isKindOfClass:[NSDictionary class]])
    }
    else if ([path.pathExtension isEqualToString:@"tex"])
    {
      NSFetchRequest* fetchRequest = [[[NSFetchRequest alloc] init] autorelease];
      fetchRequest.entity = [LibraryItem entity];
      fetchRequest.predicate = [NSPredicate predicateWithFormat:@"parent == nil"];
      fetchRequest.sortDescriptors = @[[[[NSSortDescriptor alloc] initWithKey:@"sortIndex" ascending:YES] autorelease]];
      NSError* error = nil;
      id fetchResult = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
      NSArray* rootItems = [fetchResult dynamicCastToClass:[NSArray class]];
      if (error)
        {DebugLog(0, @"error : %@", error);}
      NSUInteger rootItemsCount = rootItems.count;
      NSArray* teXItems = [self createTeXItemsFromFile:path proposedParentItem:nil proposedChildIndex:rootItemsCount];
      LibraryWindowController* libraryWindowController = [[AppController appController] libraryWindowController];
      NSDictionary* options =
        [[[NSDictionary alloc] initWithObjectsAndKeys:
          teXItems, @"teXItems",
          @(option), @"importOption",
          nil] autorelease];
      [libraryWindowController performSelector:@selector(importTeXItemsWithOptions:) withObject:options afterDelay:0];
      ok = YES;
    }//end if ([[path pathExtension] isEqualToString:@"tex"])
    else if ([path.pathExtension isEqualToString:@"library"]) //from LEE
    {
      NSString* xmlDescriptionPath = [path stringByAppendingPathComponent:@"library.dict"];
      NSPropertyListFormat format = NSPropertyListXMLFormat_v1_0;
      NSError* errorDescription = nil;
      id plist = [NSPropertyListSerialization propertyListWithData:[NSData dataWithContentsOfFile:xmlDescriptionPath options:NSUncachedRead error:nil]
                                                  options:NSPropertyListImmutable format:&format error:&errorDescription];
      if (errorDescription)
        {DebugLog(0, @"error : %@", errorDescription);}
      else if ([plist isKindOfClass:[NSDictionary class]])
      {
        NSMutableArray* latexitEquations = [NSMutableArray arrayWithCapacity:[plist count]];
        NSEnumerator* enumerator = [(NSDictionary*)plist keyEnumerator];
        id key = nil;
        while((key = [enumerator nextObject]))
        {
          id item = ((NSDictionary*)plist)[key];
          if ([item isKindOfClass:[NSDictionary class]])
          {
            NSString* pdfFile = [path stringByAppendingPathComponent:((NSDictionary*)item)[@"filename"]];
            NSData* someData = !pdfFile ? nil : [NSData dataWithContentsOfFile:pdfFile options:NSUncachedRead error:nil];
            LatexitEquation* latexitEquation = !someData ? nil : [LatexitEquation latexitEquationWithPDFData:someData useDefaults:YES];
            if (latexitEquation)
              [latexitEquations addObject:latexitEquation];
          }//end if ([item isKindOfClass:[NSDictionary class]])
        }//end for each key
        if (latexitEquations.count)
        {
          NSError* error = nil;
          NSUInteger nbRootLibraryItemsBeforeAdding = [self->managedObjectContext countForEntity:[LibraryItem entity] error:&error predicateFormat:@"parent == nil"];
          NSUInteger count = [latexitEquations count];
          NSUInteger i = 0;
          for(i = 0 ; i<count ; ++i)
          {
            LatexitEquation* latexitEquation = latexitEquations[i];
            LibraryEquation* libraryEquation =
              [[LibraryEquation alloc] initWithParent:nil equation:latexitEquation insertIntoManagedObjectContext:self->managedObjectContext];
            libraryEquation.sortIndex = nbRootLibraryItemsBeforeAdding+i;
            NSString* title = libraryEquation.title;
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
    fetchRequest.entity = [LibraryItem entity];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"parent == nil"];
    fetchRequest.sortDescriptors = @[[[[NSSortDescriptor alloc] initWithKey:@"sortIndex" ascending:YES] autorelease]];
    NSError* error = nil;
    NSArray* rootItemsOrdered = [self->managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (error)
      {DebugLog(0, @"error : %@", error);}
    [fetchRequest release];

    NSUInteger i = 0;
    NSUInteger n = [rootItemsOrdered count];
    for(i = 0 ; i<n ; ++i)
    {
      LibraryItem* libraryItem = rootItemsOrdered[i];
      libraryItem.sortIndex = i;
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
  fetchRequest.entity = [LibraryEquation entity];
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
    NSURL* storeURL = !path ? nil : [NSURL fileURLWithPath:path];
    NSError* error = nil;
    NSMutableDictionary* options = [NSMutableDictionary dictionary];
    if (DebugLogLevel >= 1)
      [options setObject:@(YES) forKey:NSSQLiteManualVacuumOption];

    [options setValue:@YES forKey:NSMigratePersistentStoresAutomaticallyOption];
    [options setValue:@{@"journal_mode":@"DELETE"} forKey:NSSQLitePragmasOption];
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
  NSString* version = [[persistentStoreCoordinator metadataForPersistentStore:persistentStore] valueForKey:@"version"];
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
  [persistentStoreCoordinator release];
  return [result autorelease];
}
//end managedObjectContextAtPath:setVersion:

-(void) saveLibrary
{
  @try{
    NSError* error = nil;
    BOOL saved = [self->managedObjectContext save:&error];
    if (!saved || error)
      {DebugLog(0, @"error : %@, NSDetailedErrors : %@", error, [error userInfo]);}
  }//end @try
  @catch(NSException* e){
    DebugLog(0, @"exception : %@", e);
  }//end @catch
}
//end saveLibrary

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

    NSString* newFilePath  = [PreferencesController sharedController].libraryPath;
    if (!newFilePath)
      newFilePath = [self defaultLibraryPath];
    NSString* oldFilePath = nil;
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        @[userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName], @"library.latexlib"];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        @[userLibraryApplicationSupportPath, [[NSWorkspace sharedWorkspace] applicationName], @"library.dat"];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        @[userLibraryPath, [[NSWorkspace sharedWorkspace] applicationName], @"library.latexlib"];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }
    if (!oldFilePath)
    {
      NSArray* pathComponents =
        @[userLibraryPath, [[NSWorkspace sharedWorkspace] applicationName], @"library.dat"];
      NSString* filePath = [NSString pathWithComponents:pathComponents];
      if ([fileManager isReadableFileAtPath:filePath])
        oldFilePath = filePath;
    }

    BOOL shouldMigrateLibraryToCoreData = ![fileManager isReadableFileAtPath:newFilePath] && oldFilePath;
    
    NSString* libraryPath = [PreferencesController sharedController].libraryPath;
    BOOL isDirectory = NO;
    BOOL exists = libraryPath && [fileManager fileExistsAtPath:libraryPath isDirectory:&isDirectory] && !isDirectory &&
                  [fileManager isReadableFileAtPath:libraryPath];

    if (!exists)
    {
      libraryPath = [self defaultLibraryPath];
      if (![fileManager isReadableFileAtPath:libraryPath])
        [fileManager createDirectoryAtPath:[libraryPath stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:0];
    }//end if (!exists)
    
    self->managedObjectContext = [[self managedObjectContextAtPath:libraryPath setVersion:NO] retain];
    NSPersistentStoreCoordinator* persistentStoreCoordinator = self->managedObjectContext.persistentStoreCoordinator;
    NSArray* persistentStores = persistentStoreCoordinator.persistentStores;
    id oldVersionObject =
      [persistentStoreCoordinator metadataForPersistentStore:persistentStores.lastObject][@"version"];
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
        [[NSFileManager defaultManager] removeItemAtPath:oldFilePath error:0];
    }
    else if (shouldMigrateLibraryToAlign)
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
        {DebugLog(0, @"error : %@", error);}
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
      [fetchRequest release];
      error = nil;
      [self->managedObjectContext save:&error];
      if (error)
        {DebugLog(0, @"error : %@", error);}
    }//end if (shouldMigrateLibraryToAlign)
    
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
  BOOL isManagedObjectModelPrevious270 = NO;

  NSArray* oldDataModelNames = @[@"Latexit-2.4.0"];
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
    NSURL* oldManagedObjectModelURL = !oldManagedObjectModelPath ? nil : [NSURL fileURLWithPath:oldManagedObjectModelPath];
    oldManagedObjectModel =
      [[NSManagedObjectModel alloc] initWithContentsOfURL:oldManagedObjectModelURL];
    oldPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:oldManagedObjectModel];
    oldPath = [[path copy] autorelease];
    NSURL* oldStoreURL = !oldPath ? nil : [NSURL fileURLWithPath:oldPath];
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
      {DebugLog(0, @"error : %@", error);}
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
      NSAutoreleasePool* ap1 = [[NSAutoreleasePool alloc] init];
      NSEntityDescription* oldLibraryItemEntityDescription = !oldManagedObjectContext ? nil :
        [NSEntityDescription entityForName:NSStringFromClass([LibraryItem class])
                    inManagedObjectContext:oldManagedObjectContext];
      NSFetchRequest* oldFetchRequest = !oldLibraryItemEntityDescription ? nil : [[NSFetchRequest alloc] init];
      oldFetchRequest.entity = oldLibraryItemEntityDescription;
      oldFetchRequest.predicate = [NSPredicate predicateWithFormat:@"parent=%@", nil];
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
        migratingProgressIndicator.minValue = 0;
        migratingProgressIndicator.maxValue = oldLibraryItems.count;
        migratingProgressIndicator.doubleValue = 0.;
        [migratingProgressIndicator display];
        while((oldLibraryItem = [oldEnumerator nextObject]))
        {
          NSAutoreleasePool* ap2 = [[NSAutoreleasePool alloc] init];
          LibraryEquation* oldLibraryEquation = [oldLibraryItem dynamicCastToClass:[LibraryEquation class]];
          [oldLibraryEquation setCustomKVOInhibited:YES];
          id oldLibraryItemDescription = [oldLibraryItem plistDescription];
          [oldLibraryEquation.equation dispose];
          [oldLibraryItem dispose];//disables KVO
          LibraryItem* newLibraryItem = !oldLibraryItemDescription ? nil :
            [LibraryItem libraryItemWithDescription:oldLibraryItemDescription];
          [newLibraryItem dispose];
          migratingProgressIndicator.doubleValue = 1.*(progression++);
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
      [[NSFileManager defaultManager] removeItemAtPath:newPath error:&error];
      if (error)
        {DebugLog(0, @"error : %@", error);}
    }//end if (!migrationOK)
    else if (migrationOK)
    {
      NSError* error = nil;
      NSFileManager* fileManager = [NSFileManager defaultManager];
      BOOL removedOldStore = [fileManager removeItemAtPath:oldPath error:&error];
      if (error)
        {DebugLog(0, @"error : %@", error);}
      if (!removedOldStore || error)
      {
        error = nil;
        [[NSFileManager defaultManager] removeItemAtPath:newPath error:&error];
        if (error)
          {DebugLog(0, @"error : %@", error);}
      }//end if (!removedOldStore || error)
      else//if (removedOldStore && !error)
      {
        BOOL movedNewStore = [fileManager moveItemAtPath:newPath toPath:oldPath error:&error];
        if (error)
          {DebugLog(0, @"error : %@", error);}
        if (!movedNewStore)
        {
          error = nil;
          [[NSFileManager defaultManager] removeItemAtPath:newPath error:&error];
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
  NSRect contentView = migratingWindow.contentView.frame;
  NSProgressIndicator* progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSInsetRect(contentView, 8, 8)];
  [migratingWindow.contentView addSubview:progressIndicator];
  progressIndicator.minValue = 0.;
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

-(NSArray*) createTeXItemsFromFile:(NSString*)filename proposedParentItem:(id)proposedParentItem proposedChildIndex:(NSInteger)proposedChildIndex
{
  NSArray* result = nil;
  NSMutableArray* texItems = [NSMutableArray array];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSString* fileUti = [fileManager UTIFromPath:filename];
  BOOL conformsToTex = UTTypeConformsTo((__bridge CFStringRef)fileUti, CFSTR("public.tex")) || UTTypeConformsTo((__bridge CFStringRef)fileUti, kUTTypePlainText);
  if (conformsToTex)
  {
    NSError* error = nil;
    NSStringEncoding encoding = NSUTF8StringEncoding;
    NSString* fileContent = [[NSString alloc] initWithContentsOfFile:filename usedEncoding:&encoding error:&error];
    NSArray* components = [fileContent captureComponentsMatchedByRegex:@"^(.*?)\\s*\\\\begin\\{document\\}(.*)\\\\end\\{document\\}" options:RKLDotAll|RKLMultiline|RKLCaseless range:[fileContent range] error:&error];
    if (error)
      DebugLog(0, @"error = <%@>", error);
    NSString* preamble = (components.count<2) ? nil : [components[1] dynamicCastToClass:[NSString class]];
    NSString* body = (components.count<3) ? nil : [components[2] dynamicCastToClass:[NSString class]];
    [fileContent release];
    if (body.length)
    {
      NSString* displayRegex = @"\\$\\$(.+?)\\$\\$|\\\\[(.+?)\\\\]|\\$\\\\displaystyle(.+?)\\$";
      NSString* inlineRegex = @"[^\\$]\\$(.+?)\\$[^\\$]";
      NSString* alignRegex = @"\\\\begin\\{align\\}(.+?)\\\\end\\{align\\}|\\\\begin\\{align\\*\\}(.+?)\\\\end\\{align\\*\\}";
      NSString* eqnarrayRegex = @"\\\\begin\\{eqnarray\\}(.+?)\\\\end\\{eqnarray\\}|\\\\begin\\{eqnarray\\*\\}(.+?)\\\\end\\{eqnarray\\*\\}";
      NSArray* equationsRegexes = @[displayRegex, inlineRegex, alignRegex, eqnarrayRegex];
      NSString* equationsRegex = [equationsRegexes componentsJoinedByString:@"|"];
      NSRange fullRange = [body range];
      NSRange searchRange = fullRange;
      NSRange matchRange = [body rangeOfRegex:equationsRegex options:RKLMultiline|RKLDotAll inRange:searchRange capture:0 error:&error];
      if (error)
        DebugLog(0, @"error <%@>", error);
      NSMutableArray* matches = [NSMutableArray array];
      while(matchRange.location != NSNotFound)
      {
        NSString* match = [body substringWithRange:matchRange];
        [matches addObject:match];
        searchRange.location = matchRange.location+matchRange.length;
        searchRange.length = fullRange.location+fullRange.length-searchRange.location;
        matchRange = [body rangeOfRegex:equationsRegex options:RKLMultiline|RKLDotAll inRange:searchRange capture:0 error:&error];
      }//end while there is a match
      NSEnumerator* enumerator = [matches objectEnumerator];
      NSString* match = nil;
      while ((match = [enumerator nextObject]))
      {
        NSArray* displayCapture = [match captureComponentsMatchedByRegex:displayRegex options:RKLMultiline|RKLDotAll range:[match range] error:&error];
        if (error)
          DebugLog(0, @"error <%@>", error);
        NSString* displayMatch = (displayCapture.count<=1) ? nil :
        [[displayCapture subarrayWithRange:NSMakeRange(1, displayCapture.count-1)] firstObjectNotIdenticalTo:@""];
        NSArray* inlineCapture = [match captureComponentsMatchedByRegex:inlineRegex options:RKLMultiline|RKLDotAll range:[match range] error:&error];
        if (error)
          DebugLog(0, @"error <%@>", error);
        NSString* inlineMatch = (inlineCapture.count<=1) ? nil :
        [[inlineCapture subarrayWithRange:NSMakeRange(1, inlineCapture.count-1)] firstObjectNotIdenticalTo:@""];
        NSArray* alignCapture = [match captureComponentsMatchedByRegex:alignRegex options:RKLMultiline|RKLDotAll range:[match range] error:&error];
        if (error)
          DebugLog(0, @"error <%@>", error);
        NSString* alignMatch = (alignCapture.count<=1) ? nil :
        [[alignCapture subarrayWithRange:NSMakeRange(1, alignCapture.count-1)] firstObjectNotIdenticalTo:@""];
        NSArray* eqnArrayCapture = [match captureComponentsMatchedByRegex:eqnarrayRegex options:RKLMultiline|RKLDotAll range:[match range] error:&error];
        if (error)
          DebugLog(0, @"error <%@>", error);
        NSString* eqnArrayMatch = (eqnArrayCapture.count<=1) ? nil :
        [[eqnArrayCapture subarrayWithRange:NSMakeRange(1, eqnArrayCapture.count-1)] firstObjectNotIdenticalTo:@""];
        
        latex_mode_t latexMode = LATEX_MODE_AUTO;
        
        NSString* sourceText = nil;
        if (displayMatch && ![displayMatch isEqualToString:@""])
        {
          sourceText = displayMatch;
          latexMode = LATEX_MODE_DISPLAY;
        }//end if (displayMatch && ![displayMatch isEqualToString:@""])
        else if (inlineMatch && ![inlineMatch isEqualToString:@""])
        {
          sourceText = inlineMatch;
          latexMode = LATEX_MODE_INLINE;
        }//end if (inlineMatch && ![inlineMatch isEqualToString:@""])
        else if (alignMatch && ![alignMatch isEqualToString:@""])
        {
          sourceText = alignMatch;
          latexMode = LATEX_MODE_ALIGN;
        }//end if (alignMatch && ![alignMatch isEqualToString:@""])
        else if (eqnArrayMatch && ![eqnArrayMatch isEqualToString:@""])
        {
          sourceText = eqnArrayMatch;
          latexMode = LATEX_MODE_EQNARRAY;
        }//end if (eqnArrayMatch && ![eqnArrayMatch isEqualToString:@""])
        
        NSDictionary* texItem = !preamble || !sourceText ? nil :
        [[[NSDictionary alloc] initWithObjectsAndKeys:
          filename, @"filename",
          preamble, @"preamble",
          sourceText, @"sourceText",
          @(latexMode), @"mode",
          !proposedParentItem ? [NSNull null] : proposedParentItem, @"proposedParentItem",
          @(proposedChildIndex), @"proposedChildIndex",
          nil] autorelease];
        if (texItem)
          [texItems addObject:texItem];
      }//end for each match
    }//end if ([body length])
  }//end if (conformsToTex)
  result = [[texItems copy] autorelease];
  return result;
}
//end createTeXItemsFromFile:proposedParentItem:proposedChildIndex:

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
