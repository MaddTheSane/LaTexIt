//  HistoryManager.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/03/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This file is the history manager, data source of every historyView.
//It is a singleton, holding a single copy of the history items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

//Note that access to historyItem will be @synchronized

#import "HistoryManager.h"

#import "AppController.h"
#import "Compressor.h"
#import "HistoryItem.h"
#import "NSApplicationExtended.h"
#import "NSArrayExtended.h"
#import "NSColorExtended.h"
#import "NSIndexSetExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"

#ifdef PANTHER
#import <LinkBack-panther/LinkBack.h>
#else
#import <LinkBack/LinkBack.h>
#endif

NSString* HistoryDidChangeNotification = @"HistoryDidChangeNotification";
NSString* HistoryItemsPboardType = @"HistoryItemsPboardType";

@interface HistoryManager (PrivateAPI)
-(void) applicationWillTerminate:(NSNotification*)aNotification; //saves history when quitting
-(void) _saveHistory;
-(void) _loadHistory;
-(void) _loadCachedHistoryImages:(NSArray*)historyItemsCopy; //loads the historyItems cached images in the background
-(void) _automaticBackgroundSaving:(id)unusedArg;//automatically and regularly saves the history on disk
-(void) _historyDidChange:(NSNotification*)notification;
-(void) _historyItemDidChange:(NSNotification*)notification;
-(BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard;
-(BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard;
@end

@implementation HistoryManager

static HistoryManager* sharedManagerInstance = nil; //the (private) singleton

+(HistoryManager*) sharedManager //access the unique instance of HistoryManager
{
  @synchronized(self)
  {
    if (!sharedManagerInstance)
      sharedManagerInstance = [[self  alloc] init];
  }
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
    if (![super init])
      return nil;
    mainThread = [NSThread currentThread];
    sharedManagerInstance = self;
    undoManager = [[NSUndoManager alloc] init];
    historyItems = [[NSMutableArray alloc] init];
    [[AppController appController] startMessageProgress:NSLocalizedString(@"Loading History", @"Loading History")];
    [self _loadHistory];
    [[AppController appController] stopMessageProgress];
    //registers applicationDidFinishLaunching and applicationWillTerminate notification to automatically save the history items
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(applicationDidFinishLaunching:)
                                             name:NSApplicationDidFinishLaunchingNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(applicationWillTerminate:)
                                             name:NSApplicationWillTerminateNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(_historyDidChange:)
                                             name:HistoryDidChangeNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(_historyItemDidChange:)
                                             name:HistoryItemDidChangeNotification object:nil];
  }
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [undoManager release];
  [historyItems release];
  [super dealloc];
}

-(NSUndoManager*) undoManager
{
  return undoManager;
}

-(BOOL) historyShouldBeSaved
{
  BOOL status = NO;
  @synchronized(historyItems)
  {
    status = historyShouldBeSaved;
  }
  return status;
}

-(void) setHistoryShouldBeSaved:(BOOL)state
{
  @synchronized(historyItems)
  {
    historyShouldBeSaved = state;
  }
}

//Management methods, undo-aware

-(void) addItem:(HistoryItem*)item
{
  @synchronized(historyItems)
  {
    [historyItems insertObject:item atIndex:0];
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:HistoryDidChangeNotification object:nil];
}

-(void) clearAll
{
  [undoManager removeAllActionsWithTarget:self];
  @synchronized(historyItems)
  {
    [historyItems removeAllObjects];
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:HistoryDidChangeNotification object:nil];
}

-(NSArray*) itemsAtIndexes:(NSIndexSet*)indexSet tableView:(NSTableView*)tableView
{
  NSMutableArray* array = [NSMutableArray arrayWithCapacity:[indexSet count]];
  @synchronized(historyItems)
  {
    unsigned int index = [indexSet firstIndex];
    while(index != NSNotFound)
    {
      [array addObject:[historyItems objectAtIndex:index]];
      index = [indexSet indexGreaterThanIndex:index];
    }
  }//end @synchronized(historyItems)
  return array;
}

-(void) removeItemsAtIndexes:(NSIndexSet*)indexSet tableView:(NSTableView*)tableView
{
  unsigned int index = [indexSet lastIndex];
  if (index != NSNotFound)
  {
    id nextItemToSelect = nil;
    NSMutableArray* removedItems = nil;
    @synchronized(historyItems)
    {
      //We will remember deleted items to allow undoing
      nextItemToSelect = ((index+1) < [historyItems count]) ? [historyItems objectAtIndex:index+1] : nil;
      removedItems = [NSMutableArray arrayWithCapacity:[indexSet count]];
      while(index != NSNotFound)
      {
        [removedItems addObject:[historyItems objectAtIndex:index]];
        [historyItems removeObjectAtIndex:index];
        index = [indexSet indexLessThanIndex:index];
      }

      [[undoManager prepareWithInvocationTarget:self] insertItems:[removedItems reversed] atIndexes:[indexSet array]
                                                        tableView:tableView];
      if (![undoManager isUndoing])
      {
        if ([indexSet count] > 1)
          [undoManager setActionName:NSLocalizedString(@"Delete History items", @"Delete History items")];
        else
          [undoManager setActionName:NSLocalizedString(@"Delete History item", @"Delete History item")];
      }
      [[NSNotificationCenter defaultCenter] postNotificationName:HistoryDidChangeNotification object:nil];

      //user friendly : we update the selection in the tableview
      [tableView deselectAll:self];
      if (!nextItemToSelect && [historyItems count])
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[historyItems count]-1] byExtendingSelection:NO];          
      else if (nextItemToSelect)
        [tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:[historyItems indexOfObject:nextItemToSelect]]
               byExtendingSelection:NO];
    }//end @synchronized(historyItems)
  }//end if index != NSNotFound
}

-(void) insertItems:(NSArray*)items atIndexes:(NSArray*)indexes tableView:(NSTableView*)tableView
{
  NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];

  const unsigned int count = MIN([items count], [indexes count]);
  unsigned int i = 0;
  @synchronized(historyItems)
  {
    for(i = 0 ; i < count ; ++i)
    {
      HistoryItem* item = [items objectAtIndex:i];
      unsigned int index = [[indexes objectAtIndex:i] unsignedIntValue];
      [indexSet addIndex:index];
      [historyItems insertObject:item atIndex:index];
    }
  }//end @synchronized(historyItems)
  
  [[NSNotificationCenter defaultCenter] postNotificationName:HistoryDidChangeNotification object:nil];
  [[undoManager prepareWithInvocationTarget:self] removeItemsAtIndexes:indexSet tableView:tableView];

  //user friendly : we update the selection in the tableview
  [tableView selectRowIndexes:indexSet byExtendingSelection:NO];
}

-(HistoryItem*) itemAtIndex:(unsigned int)index tableView:(NSTableView*)tableView
{
  HistoryItem* item = nil;
  @synchronized(historyItems)
  {
    if (index < [historyItems count])
      item = [historyItems objectAtIndex:index];
  }
  return item;
}

//getting the history items
-(NSArray*) historyItems
{
  return historyItems;
}

//automatically and regularly saves the history on disk
-(void) _automaticBackgroundSaving:(id)unusedArg
{
  NSAutoreleasePool* threadAutoreleasePool = [[NSAutoreleasePool alloc] init];
  [NSThread setThreadPriority:0];//this thread has a very low priority
  while(YES)
  {
    NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:5*60]];//wakes up every five minutes
    [self _saveHistory];
    [ap release];
  }
  [threadAutoreleasePool release];
}

//saves the history on disk
-(void) _saveHistory
{
  @synchronized(historyItems) //to prevent concurrent saving, and conflicts, if historyItems is modified in another thread
  {
    if (historyShouldBeSaved)
    {
      if ([NSThread currentThread] == mainThread)
        [[AppController appController] startMessageProgress:NSLocalizedString(@"Saving History", @"Saving History")];
      NSData* uncompressedData = [NSKeyedArchiver archivedDataWithRootObject:historyItems];
      NSData* compressedData = [Compressor zipcompress:uncompressedData];
      
      //we will create history.dat file inside ~/Library/LaTeXiT/history.dat, so we must ensure that these folders exist
      NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask , YES);
      if ([paths count])
      {
        NSString* path = [paths objectAtIndex:0];
        path = [path stringByAppendingPathComponent:[NSApp applicationName]];
        
        //we (try to) create the folders step by step. If they already exist, does nothing
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSArray* pathComponents = [path pathComponents];
        NSString* subPath = [NSString string];
        const unsigned int count = [pathComponents count];
        unsigned int i = 0;
        for(i = 0 ; i<count ; ++i)
        {
          subPath = [subPath stringByAppendingPathComponent:[pathComponents objectAtIndex:i]];
          [fileManager createDirectoryAtPath:subPath attributes:nil];
        }
        
        //Then save the data
        NSString* historyFilePath = [path stringByAppendingPathComponent:@"history.dat"];
        historyShouldBeSaved = ![compressedData writeToFile:historyFilePath atomically:YES];
      }//end if path ok
      if ([NSThread currentThread] == mainThread)
        [[AppController appController] stopMessageProgress];
    }//end if historyShouldBeSaved
  }//end @synchronized(historyItems)
}

-(void) _loadHistory
{
  //note that there is no @synchronization here, since no other threads will exist before _loadHistory is complete
  @try
  {
    [historyItems removeAllObjects];

    //load from ~/Library/LaTeXiT/history.dat
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask , YES);
    if ([paths count])
    {
      NSString* path = [paths objectAtIndex:0];
      path = [path stringByAppendingPathComponent:[NSApp applicationName]];

      NSString* filename = [path stringByAppendingPathComponent:@"history.dat"];
      NSData* compressedData = [NSData dataWithContentsOfFile:filename];
      NSData* uncompressedData = [Compressor zipuncompress:compressedData];
      if (uncompressedData)
      {
        [historyItems release];
        historyItems = nil;
        historyItems = [[NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData] retain];
      }
    }
  }
  @catch(NSException* e) //reading may fail for some reason
  {
  }
  @finally //if the history could not be created, make it (empty) now
  {
    if (!historyItems)
      historyItems = [[NSMutableArray alloc] init];
    [NSThread detachNewThreadSelector:@selector(_automaticBackgroundSaving:) toTarget:self withObject:nil];
  }
  [[NSNotificationCenter defaultCenter] postNotificationName:HistoryDidChangeNotification object:nil];

  NSArray* historyItemsCopy = [historyItems copy];//WARNING ! THE THREAD WILL BE RESPONSIBLE OF RELEASING THAT OBJECT
  [NSThread detachNewThreadSelector:@selector(_loadCachedHistoryImages:) toTarget:self withObject:historyItemsCopy];
}

//loads, in the background, the historyItems cached images
-(void) _loadCachedHistoryImages:(NSArray*)historyItemsCopy
{
  NSAutoreleasePool* threadAutoreleasePool = [[NSAutoreleasePool alloc] init];
  [NSThread setThreadPriority:0];//the current thread has a LOW priority, and won't use too much processor time
  NSEnumerator* enumerator = [historyItemsCopy objectEnumerator];
  HistoryItem* item = [enumerator nextObject];
  while(item)
  {
    if([item retainCount] > 1)
      [item bitmapImage];//computes the bitmapCachedImage. there is an @synchronized inside to prevent conflicts
    item = [enumerator nextObject];
  }
  [historyItemsCopy release];
  [threadAutoreleasePool release];
}

//When the application quits, the notification is caught to perform saving
-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  [self _saveHistory];
}

//NSTableViewDataSource protocol
-(int) numberOfRowsInTableView:(NSTableView *)aTableView
{
  int count = 0;
  @synchronized(historyItems)
  {
    count = [historyItems count];
  }
  return count;
}

-(id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
  id item = nil;
  @synchronized(historyItems)
  {
    item = [historyItems objectAtIndex:rowIndex];
  }
  return [item image];
}

//NSTableView delegate

-(void) tableViewSelectionDidChange:(NSNotification*)notification
{
}

-(void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn
             row:(int)rowIndex
{
  HistoryItem* historyItem = nil;
  @synchronized(historyItem)
  {
    historyItem = [historyItems objectAtIndex:rowIndex];
  }
  [aCell setBackgroundColor:[historyItem backgroundColor]];
  [aCell setRepresentedObject:historyItem];
}

//drag'n drop

//this one is deprecated in OS 10.4, calls the next one
-(BOOL)tableView:(NSTableView *)tableView writeRows:(NSArray *)rows toPasteboard:(NSPasteboard *)pboard
{
  NSMutableIndexSet* indexSet = [NSMutableIndexSet indexSet];
  NSEnumerator* enumerator = [rows objectEnumerator];
  NSNumber* row = [enumerator nextObject];
  while(row)
  {
    [indexSet addIndex:[row unsignedIntValue]];
    row = [enumerator nextObject];
  }
  return [self tableView:tableView writeRowsWithIndexes:indexSet toPasteboard:pboard];
}

//this one is for OS 10.4
-(BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
  @synchronized(historyItems)
  {
    if ([rowIndexes count])
    {
      //promise file occur when drag'n dropping to the finder. The files will be created in tableview:namesOfPromisedFiles:...
      [pboard declareTypes:[NSArray arrayWithObject:NSFilesPromisePboardType] owner:self];
      [pboard setPropertyList:[NSArray arrayWithObjects:@"pdf", @"eps", @"tiff", @"jpeg", @"png", nil] forType:NSFilesPromisePboardType];

      //stores the array of selected history items in the HistoryItemsPboardType
      NSMutableArray* selectedItems = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
      unsigned int index = [rowIndexes firstIndex];
      while(index != NSNotFound)
      {
        [selectedItems addObject:[historyItems objectAtIndex:index]];
        index = [rowIndexes indexGreaterThanIndex:index];
      }
      [pboard addTypes:[NSArray arrayWithObject:HistoryItemsPboardType] owner:self];
      [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:selectedItems] forType:HistoryItemsPboardType];
      
      //Get the last selected item
      int lastSelectedRow = [aTableView selectedRow];
      if ((lastSelectedRow < 0) || (![rowIndexes containsIndex:lastSelectedRow]))
        lastSelectedRow = [rowIndexes lastIndex];
      HistoryItem* historyItem = [historyItems objectAtIndex:lastSelectedRow];
      
      //bonus : we can also feed other pasteboards with one of the selected items
      //The pasteboard (PDF, PostScript, TIFF... will depend on the user's preferences
      [historyItem writeToPasteboard:pboard forDocument:[[AppController appController] dummyDocument]
                   isLinkBackRefresh:NO lazyDataProvider:nil];
    }//end if ([rowIndexes count])
  }//end @synchronized(historyItems)

  return YES;
}

//triggered when dropping to the finder. It will create the files and return the filenames
-(NSArray*) tableView:(NSTableView*)tableView namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination
                                                             forDraggedRowsWithIndexes:(NSIndexSet *)indexSet
{
  NSMutableArray* names = [NSMutableArray arrayWithCapacity:1];
  
  NSString* dropPath = [dropDestination path];
  NSFileManager* fileManager = [NSFileManager defaultManager];
  
  //the problem will be to avoid overwritting files when they already exist
  NSString* filePrefix = @"latex-image";
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
  
  NSColor* color = [NSColor colorWithData:[userDefaults objectForKey:DragExportJpegColorKey]];
  float  quality = [userDefaults floatForKey:DragExportJpegQualityKey];

  NSString* fileName = nil;
  NSString* filePath = nil;
  
  //To avoid overwritting, and not bother the user with a dialog box, a number will be added to the filename.
  //this number is <i>. It will begin at 1 and will be increased as long as we do not find a "free" file name.
  unsigned long i = 1;

  @synchronized(historyItems)
  {
    unsigned int index = [indexSet firstIndex]; //we will have to do that for each item of the pasteboard
    while (index != NSNotFound) 
    {
      do
      {
        fileName = [NSString stringWithFormat:@"%@-%u.%@", filePrefix, i++, extension];
        filePath = [dropPath stringByAppendingPathComponent:fileName];
      } while (i && [fileManager fileExistsAtPath:filePath]);
      
      //now, we may have found a proper filename to save our data
      if (![fileManager fileExistsAtPath:filePath])
      {
        HistoryItem* historyItem = [historyItems objectAtIndex:index];
        NSData* pdfData = [historyItem pdfData];
        NSData* data = [[AppController appController] dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality
                                                   scaleAsPercent:[userDefaults floatForKey:DragExportScaleAsPercentKey]];

        [fileManager createFileAtPath:filePath contents:data attributes:nil];
        [fileManager changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt'] forKey:NSFileHFSCreatorCode]
                                   atPath:filePath];
        unsigned int options = 0;
        #ifndef PANTHER
        options = NSExclude10_4ElementsIconCreationOption;
        #endif
        NSColor* backgroundColor = (exportFormat == EXPORT_FORMAT_JPEG) ? color : nil;
        [[NSWorkspace sharedWorkspace] setIcon:[[AppController appController] makeIconForData:[historyItem pdfData] backgroundColor:backgroundColor]
                                       forFile:filePath options:options];
        [names addObject:fileName];
      }
      index = [indexSet indexGreaterThanIndex:index]; //now, let's do the same for the next item
    }
  }//end @synchronized(historyItems)
  return names;
}

//we can drop a color on a history item cell, to change its background color
-(NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info
                proposedRow:(int)row proposedDropOperation:(NSTableViewDropOperation)operation
{
  NSPasteboard* pboard = [info draggingPasteboard];
  //we only accept drops on items, not above them.
  BOOL ok = pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]] &&
            [pboard propertyListForType:NSColorPboardType] &&
            (operation == NSTableViewDropOn);
  return ok ? NSDragOperationGeneric : NSDragOperationNone;
}

//accepts dropping a color on an element
-(BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(int)row
                                        dropOperation:(NSTableViewDropOperation)operation
{
  NSPasteboard* pboard = [info draggingPasteboard];
  BOOL ok = pboard &&
            [pboard availableTypeFromArray:[NSArray arrayWithObject:NSColorPboardType]] &&
            [pboard propertyListForType:NSColorPboardType] &&
            (operation == NSTableViewDropOn);
  if (ok)
  {
    NSColor* color = [NSColor colorWithData:[pboard dataForType:NSColorPboardType]];
    HistoryItem* historyItem = [historyItems objectAtIndex:row];
    [historyItem setBackgroundColor:color];
  }
  return ok;
}

//should be triggered for each change in history
-(void) _historyDidChange:(NSNotification*)notification
{
  @synchronized(historyItems)
  {
    historyShouldBeSaved = YES;
  }
}

//should be triggered for each changing historyItem
-(void) _historyItemDidChange:(NSNotification*)notification
{
  @synchronized(historyItems)
  {
    historyShouldBeSaved = YES;
  }
}

@end
