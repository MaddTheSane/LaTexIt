//  LibraryManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//This file is the library manager, data source of every libraryTableView.
//It is a singleton, holding a single copy of the library items, that will be shared by all documents.
//It provides management (insertion/deletion) with undoing, save/load, drag'n drop

//Note that the library will be @synchronized

#import "LibraryManager.h"

#import "AppController.h"
#import "Compressor.h"
#import "HistoryItem.h"
#import "HistoryManager.h"
#import "LibraryFile.h"
#import "LibraryFolder.h"
#import "LibraryTableView.h"
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

NSString* LibraryDidChangeNotification = @"LibraryDidChangeNotification";
NSString* LibraryItemsPboardType = @"LibraryItemsPboardType";

@interface LibraryManager (PrivateAPI)
-(void) applicationWillTerminate:(NSNotification*)aNotification; //saves library when quitting

-(void) _reinsertItems:(NSArray*)items atParents:(NSArray*)parents atIndexes:(NSArray*)indexes; //to perform undo
-(void) _performDropOperation:(id <NSDraggingInfo>)info onItem:(LibraryItem*)parentItem atIndex:(int)childIndex
                  outlineView:(NSOutlineView*)outlineView;
-(void) _setTitle:(NSString*)title onItem:(LibraryItem*)item;
-(void) _setTitles:(NSArray*)titles onItems:(NSArray*)items;
-(void) _saveLibrary;
-(void) _loadLibrary;
-(void) _automaticBackgroundSaving:(id)unusedArg;//automatically and regularly saves the library on disk

-(NSArray*) _draggedItems; //utility method to access draggedItems when working with pasteboard sender
@end

@implementation LibraryManager

static LibraryManager* sharedManagerInstance = nil;
static NSImage*        libraryFileIcon       = nil;

+(void) initialize
{
  if (!libraryFileIcon)
  {
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* resourcePath = [mainBundle resourcePath];
    NSString* fileName = [resourcePath stringByAppendingPathComponent:@"latexit-lib.png"];
    libraryFileIcon = [[NSImage alloc] initWithContentsOfFile:fileName];
  }
}

+(LibraryManager*) sharedManager //access the unique instance of LibraryManager
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

-(id) init
{
  if (self && (self != sharedManagerInstance)) //do not recreate an instance
  {
    if (![super init])
      return nil;
    mainThread = [NSThread currentThread];
    sharedManagerInstance = self;
    undoManager = [[NSUndoManager alloc] init];
    library = [[LibraryFolder alloc] init];
    [[AppController appController] startMessageProgress:NSLocalizedString(@"Loading Library", @"Loading Library")];
    [self _loadLibrary];
    [[AppController appController] stopMessageProgress];
    [NSThread detachNewThreadSelector:@selector(_automaticBackgroundSaving:) toTarget:self withObject:nil];
    //registers applicationWillTerminate notification to automatically save the library
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:)
                                                 name:NSApplicationWillTerminateNotification object:nil];
  }
  return self;
}

-(void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [undoManager release];
  [library release];
  [super dealloc];
}

-(NSUndoManager*) undoManager
{
  return undoManager;
}

//triggers saving when app is quitting
-(void) applicationWillTerminate:(NSNotification*)aNotification
{
  [self _saveLibrary];
}

//marks if library needs being saved
-(void) setLibraryShouldBeSaved:(BOOL)status
{
  @synchronized(library) 
  {
    libraryShouldBeSaved = status;
  }
}

-(NSArray*) allItems
{
  NSMutableArray* items = [NSMutableArray arrayWithCapacity:100];
  @synchronized(library)
  {
    NSMutableArray* remainingItems = [NSMutableArray arrayWithArray:[library children]];
    while([remainingItems count])
    {
      LibraryItem* item = [remainingItems objectAtIndex:0];
      [remainingItems removeObjectAtIndex:0];
      [items addObject:item];
      [remainingItems addObjectsFromArray:[item children]];
    }
  }
  return items;
}

-(NSArray*) allValues
{
  NSMutableArray* values = [NSMutableArray arrayWithCapacity:100];
  @synchronized(library)
  {
    NSMutableArray* items = [NSMutableArray arrayWithArray:[library children]];
    while([items count])
    {
      LibraryItem* item = [items objectAtIndex:0];
      [items removeObjectAtIndex:0];
      if ([item isKindOfClass:[LibraryFile class]])
        [values addObject:[(LibraryFile*)item value]];
      [items addObjectsFromArray:[item children]];
    }
  }
  return values;
}

//automatically and regularly saves the library on disk
-(void) _automaticBackgroundSaving:(id)unusedArg
{
  NSAutoreleasePool* threadAutoreleasePool = [[NSAutoreleasePool alloc] init];
  [NSThread setThreadPriority:0];//this thread has a very low priority
  while(YES)
  {
    NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
    [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:5*60]];//wakes up every five minutes
    [self _saveLibrary];
    [ap release];
  }
  [threadAutoreleasePool release];
}

//saves the library on disk
-(void) _saveLibrary
{
  @synchronized(library) //to prevent concurrent saving, and conflicts, if library is modified in another thread
  {
    if (libraryShouldBeSaved)
    {
      if ([NSThread currentThread] == mainThread)
        [[AppController appController] startMessageProgress:NSLocalizedString(@"Saving Library", @"Saving Library")];
      NSData* uncompressedData = [NSKeyedArchiver archivedDataWithRootObject:library];
      NSData* compressedData = [Compressor zipcompress:uncompressedData];
      
      //we will create library.dat file inside ~/Library/LaTeXiT/library.dat, so we must ensure that these folders exist
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
        NSString* libraryFilePath = [path stringByAppendingPathComponent:@"library.dat"];
        libraryShouldBeSaved = ![compressedData writeToFile:libraryFilePath atomically:YES];
      }//end if path ok
      if ([NSThread currentThread] == mainThread)
        [[AppController appController] stopMessageProgress];
    }//end if libraryShouldBeSaved
  }//end @synchronized(library)
}

-(BOOL) saveAs:(NSString*)path
{
  BOOL ok = NO;
  @synchronized(library) //to prevent concurrent saving, and conflicts, if library is modified in another thread
  {
    NSData* uncompressedData = [NSKeyedArchiver archivedDataWithRootObject:library];
    NSData* compressedData = [Compressor zipcompress:uncompressedData];
    ok = [compressedData writeToFile:path atomically:YES];
    if (ok)
    {
      [[NSFileManager defaultManager]
         changeFileAttributes:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:'LTXt'] forKey:NSFileHFSCreatorCode]
                                                          atPath:path];
      unsigned int options = 0;
      #ifndef PANTHER
      options = NSExclude10_4ElementsIconCreationOption;
      #endif
      [[NSWorkspace sharedWorkspace] setIcon:libraryFileIcon forFile:path options:options];
    }//end if file has been created
  }
  return ok;
}

-(void) _loadLibrary
{
  //load from ~/Library/LaTeXiT/library.dat
  NSString* libraryFilePath = [NSString string];
  NSArray* paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask , YES);
  if ([paths count])
  {
    NSString* path = [paths objectAtIndex:0];
    CFDictionaryRef bundleInfoDict = CFBundleGetInfoDictionary( CFBundleGetMainBundle() );
    if (bundleInfoDict)
    {
      NSString* applicationName = (NSString*) CFDictionaryGetValue( bundleInfoDict, CFSTR("CFBundleExecutable") );
      path = [path stringByAppendingPathComponent:applicationName];
      libraryFilePath = [path stringByAppendingPathComponent:@"library.dat"];
    }
  }
  [self loadFrom:libraryFilePath];
}

-(BOOL) loadFrom:(NSString*)path
{
  BOOL ok = YES;
  @synchronized(self)
  {
    LibraryFolder* newLibrary = nil;
    @try
    {
      NSData* compressedData   = [NSData dataWithContentsOfFile:path];
      NSData* uncompressedData = [Compressor zipuncompress:compressedData];
      if (uncompressedData)
        newLibrary = [NSKeyedUnarchiver unarchiveObjectWithData:uncompressedData];
    }
    @catch(NSException* e) //reading may fail for some reason
    {
      ok = NO;
    }

    if (!newLibrary)
      newLibrary = [[[LibraryFolder alloc] init] autorelease];

    [library release];
    library = [newLibrary retain];
  }

  [[NSNotificationCenter defaultCenter] postNotificationName:LibraryDidChangeNotification object:nil];

  return ok;
}

//NSOutlineViewDataSource protocol
-(id) outlineView:(NSOutlineView*)outlineView child:(int)index ofItem:(id)item
{
  id child = nil;
  @synchronized(library)
  {
    if (item == nil)
      child = [library childAtIndex:index];
    else
      child = [item childAtIndex:index];
  }//end @synchronized(library)
  return child;
}

-(BOOL) outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
  BOOL expandable = NO;
  if (item != nil)
    expandable = ([item numberOfChildren] > 0);
  return expandable;
}

-(int) outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
  int count = 0;
  @synchronized(library)
  {
    if (item == nil)
      count = [library numberOfChildren];
    else
      count = [item numberOfChildren];
  }//end @synchronized(library)
  return count;
}

//drag'n drop

-(NSArray*) _draggedItems; //utility method to access draggedItems when working with pasteboard sender
{
  return draggedItems;
}

//write the pasteboard when dragging begins
-(BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
  draggedItems = items; // Don't retain since this is just holding temporary drag information, and it is only used during a drag!
                        // We could put this in the pboard actually.
                        
  //promise file occur when drag'n dropping to the finder. The files will be created in tableview:namesOfPromisedFiles:...
  [pboard declareTypes:[NSArray arrayWithObject:LibraryItemsPboardType] owner:self];
  [pboard setPropertyList:[NSArray arrayWithObjects:@"pdf", @"eps", @"tiff", @"jpeg", @"png", nil] forType:NSFilesPromisePboardType];

  //the main data will be the items
  NSData* data = [NSKeyedArchiver archivedDataWithRootObject:items];

  //LibraryItemsPboardType contains the items
  [pboard addTypes:[NSArray arrayWithObject:LibraryItemsPboardType] owner:self];
  [pboard setData:data forType:LibraryItemsPboardType];

  //The drag may contain LibraryFile items, in this case we can put their value in the pastebaord
  //since the value of LibraryFile holds an HistoryITem, the HistoryItemsPboardType is perfect
  //we will also feed other pasteboards with the last historyItem
  NSMutableArray* libraryFileItems = [NSMutableArray arrayWithCapacity:[items count]];
  NSMutableArray* historyItems = [NSMutableArray arrayWithCapacity:[items count]];
  NSEnumerator* enumerator = [items objectEnumerator];
  LibraryItem* item = [enumerator nextObject];
  while(item)
  {
    if ([item isKindOfClass:[LibraryFile class]]) //only a LibraryFile holds a value (not a LibraryFolder)
    {
      [libraryFileItems addObject:item];
      [historyItems addObject:[(LibraryFile*)item value]];
    }
    item = [enumerator nextObject];
  }
  
  //did I found some LibraryFiles containing some values ?
  if ([historyItems count])
  {
    //if yes, feed the HistoryItemsPboardType pasteboard
    [pboard addTypes:[NSArray arrayWithObject:HistoryItemsPboardType] owner:self];
    [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:historyItems] forType:HistoryItemsPboardType];

    //bonus : we can also feed other pasteboards with one of the selected items
    //The pasteboard (PDF, PostScript, TIFF... will depend on the user's preferences
    HistoryItem* historyItem = [historyItems lastObject];
    [historyItem writeToPasteboard:pboard forDocument:[[AppController appController] dummyDocument] isLinkBackRefresh:NO lazyDataProvider:nil];
  }

  //NSStringPBoardType may contain some info for LibraryFiles the label of the equations : useful for users that only want to \ref this equation
  if ([libraryFileItems count])
  {
    NSUserDefaults* userDefaults = [NSUserDefaults standardUserDefaults];
    NSArray*      encapsulations = [userDefaults arrayForKey:EncapsulationsKey];
    unsigned int    currentIndex = [[userDefaults objectForKey:CurrentEncapsulationIndexKey] unsignedIntValue];
    NSString*  encapsulationText = (currentIndex < [encapsulations count]) ? [encapsulations objectAtIndex:currentIndex] : @"";
    NSMutableString* labels      = [NSMutableString string];
    NSEnumerator*    enumerator  = [libraryFileItems objectEnumerator];
    LibraryFile*     fileItem    = [enumerator nextObject];
    while(fileItem)
    {
      NSString* title  = [fileItem title];
      NSString* source = [[[fileItem value] sourceText] string];
      NSMutableString* replacedText = [NSMutableString stringWithString:encapsulationText];
      [replacedText replaceOccurrencesOfString:@"@" withString:title options:NSLiteralSearch range:NSMakeRange(0, [replacedText length])];
      [replacedText replaceOccurrencesOfString:@"#" withString:source options:NSLiteralSearch range:NSMakeRange(0, [replacedText length])];
      [labels appendString:replacedText];
      fileItem = [enumerator nextObject];
    }
    [pboard addTypes:[NSArray arrayWithObject:NSStringPboardType] owner:self];
    [pboard setString:labels forType:NSStringPboardType];
  }

  return YES;
}

//validates a dropping destination in the library view
-(NSDragOperation) outlineView:(NSOutlineView*)outlineView validateDrop:(id <NSDraggingInfo>)info
               proposedItem:(id)item proposedChildIndex:(int)childIndex
{
  BOOL proposedParentIsValid = YES;
  @synchronized(library)
  {
    //This method validates whether or not the proposal is a valid one. Returns NO if the drop should not be allowed.
    LibraryItem* proposedParent = item;
    
    //if the dragged occured from a LibraryTableView, the destination can only be the same libraryTableView, that is to say the current one
    id draggingSource = [info draggingSource];
    if ([draggingSource isKindOfClass:[LibraryTableView class]] && (draggingSource != outlineView))
      proposedParentIsValid = NO;
    
    BOOL isOnDropTypeProposal = (childIndex==NSOutlineViewDropOnItemIndex);
      
    //Refuse if the dropping occurs "on" the *view* itself, unless we have no data in the view.
    if (isOnDropTypeProposal && !proposedParent)
      proposedParentIsValid = NO;

    if (isOnDropTypeProposal && !proposedParent && ([library numberOfChildren]!=0))
      proposedParentIsValid = NO;
      
    //Refuse if we are trying to drop on a LibraryFile
    if ([proposedParent isKindOfClass:[LibraryFile class]] && isOnDropTypeProposal)
      proposedParentIsValid = NO;
      
    //Check to make sure we don't allow a node to be inserted into one of its descendants!
    if (proposedParentIsValid && ([info draggingSource] == outlineView) &&
        [[info draggingPasteboard] availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsPboardType]])
    {
        NSArray* dragged      = [[[info draggingSource] dataSource] _draggedItems];
        proposedParentIsValid = ![proposedParent isDescendantOfItemInArray:dragged];
    }
    
    //we don't want an item to be dropped at the same place (same parent, same child index)
    if (proposedParentIsValid && !isOnDropTypeProposal && ([info draggingSource] == outlineView))
    {
      NSArray* dragged = [[[info draggingSource] dataSource] _draggedItems];
      LibraryItem* firstItem = [dragged objectAtIndex:0];
      LibraryItem* firstItemParent = [firstItem parent];
      if ((firstItemParent == proposedParent) || (!proposedParent && (firstItemParent == library)))
      {
        int actualChildIndex  = proposedParent ? [proposedParent indexOfChild:firstItem] : [library indexOfChild:firstItem];
        if ((actualChildIndex == childIndex) || (actualChildIndex+1 == childIndex))
          proposedParentIsValid = NO;
      }
    }
    
    //Sets the item and child index in case we computed a retargeted one.
    [outlineView setDropItem:proposedParent dropChildIndex:childIndex];
  }//end @synchronized(library)
  return proposedParentIsValid ? NSDragOperationGeneric : NSDragOperationNone;
}

//accepts drop
-(BOOL) outlineView:(NSOutlineView*)outlineView acceptDrop:(id <NSDraggingInfo>)info
               item:(id)targetItem childIndex:(int)childIndex
{
  // Determine the parent to insert into and the child index to insert at.
  LibraryItem* parent = targetItem;
  childIndex = (childIndex == NSOutlineViewDropOnItemIndex) ? 0 : childIndex;
  
  [self _performDropOperation:info onItem:parent atIndex:childIndex outlineView:outlineView];
  
  return YES;
}

//Creates the files of the files promised in the pasteboard
-(NSArray*) outlineView:(NSOutlineView*)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination
        forDraggedItems:(NSArray *)items
{
  NSMutableArray* names = [NSMutableArray arrayWithCapacity:1];

  //this function is a little long, to address two problems :
  //1) the files created should have the name contained in the library items title, but in case of conflict, we must find a new
  //   name by adding a number
  //2) when dropping a LibraryFolder, we must create a folder and fill it (recursively, of course)

  //first, to address problems of 2), we must ensure that no item has an ancestor in the array of selected items
  items = [LibraryItem minimumNodeCoverFromItemsInArray:items];

  NSString* dropPath = [dropDestination path];
  NSFileManager* fileManager = [NSFileManager defaultManager];
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
  NSEnumerator* enumerator = [items objectEnumerator];
  LibraryItem* libraryItem = [enumerator nextObject];
  while (libraryItem)
  {
    if ([libraryItem isKindOfClass:[LibraryFolder class]]) //if we create a folder...
    {
      LibraryFolder* libraryFolder = (LibraryFolder*) libraryItem;
      fileName = [libraryItem title];
      filePath = [dropPath stringByAppendingPathComponent:fileName];
      if (![fileManager fileExistsAtPath:filePath]) //does a folder of that name already exist ?
      {
        BOOL ok = [fileManager createDirectoryAtPath:filePath attributes:nil];
        if (ok)
        {
          //Recursive call to fill the folder
          [self outlineView:outlineView namesOfPromisedFilesDroppedAtDestination:[NSURL fileURLWithPath:filePath]
            forDraggedItems:[libraryFolder children]];
          [names addObject:fileName];
        }
      }//end if ok to create folder with title name
      else //if a folder of that name already exist, we must compute a new "free" name
      {
        unsigned long i = 1; //we will add a number
        do
        {
          fileName = [NSString stringWithFormat:@"%@-%u", [libraryItem title], i++];
          filePath = [dropPath stringByAppendingPathComponent:fileName];
        } while (i && [fileManager fileExistsAtPath:filePath]);
        
        //I may have found a free name; create the folder in this case
        if (![fileManager fileExistsAtPath:filePath])
        {
          BOOL ok = [fileManager createDirectoryAtPath:filePath attributes:nil];
          if (ok)
          {
            //Recursive call to fill the folder
            [self outlineView:outlineView namesOfPromisedFilesDroppedAtDestination:[NSURL fileURLWithPath:filePath]
              forDraggedItems:[libraryFolder children]];
            [names addObject:fileName];
          }
        }
      }//end if folder of given title already exists
    }//end if libraryItem is a folder
    else if ([libraryItem isKindOfClass:[LibraryFile class]]) //do we create a file ?
    {
      LibraryFile* libraryFile = (LibraryFile*) libraryItem;
      unsigned long i = 1; //if the name is not free, we will have to compute a new one
      NSString* filePrefix = [libraryItem title];
      fileName = [NSString stringWithFormat:@"%@.%@", filePrefix, extension];
      filePath = [dropPath stringByAppendingPathComponent:fileName];
      if (![fileManager fileExistsAtPath:filePath]) //is the name free ?
      {
        HistoryItem* historyItem = [libraryFile value];
        NSData* pdfData = [historyItem pdfData];
        NSData* data = [[AppController appController] dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality];

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
      else //the name is not free, we must compute a new one by adding a number
      {
        do
        {
          fileName = [NSString stringWithFormat:@"%@-%u.%@", filePrefix, i++, extension];
          filePath = [dropPath stringByAppendingPathComponent:fileName];
        } while (i && [fileManager fileExistsAtPath:filePath]);
        
        //We may have found a name; in this case, create the file
        if (![fileManager fileExistsAtPath:filePath])
        {
          HistoryItem* historyItem = [libraryFile value];
          NSData* pdfData = [historyItem pdfData];
          NSData* data = [[AppController appController] dataForType:exportFormat pdfData:pdfData jpegColor:color jpegQuality:quality];

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
      }//end if item of that title already exists
    }//end if libraryItem is LibraryFile
    
    libraryItem = [enumerator nextObject]; //ok, next item, now
  }//end while item
  return names;
}

//undo-aware drop operation
-(void) _performDropOperation:(id <NSDraggingInfo>)info onItem:(LibraryItem*)parentItem atIndex:(int)childIndex
                  outlineView:(NSOutlineView*)outlineView
{
  @synchronized(library)
  {
    NSPasteboard* pboard = [info draggingPasteboard];
    if (parentItem == nil)
      parentItem = library;

    NSMutableArray* itemsToSelect = nil;
    if ([pboard availableTypeFromArray:[NSArray arrayWithObject:LibraryItemsPboardType]])
    {
      LibraryManager* dragDataSource = [[info draggingSource] dataSource];
      itemsToSelect = [NSMutableArray arrayWithArray:[dragDataSource _draggedItems]];
      NSArray* tmpDraggedItems = [LibraryItem minimumNodeCoverFromItemsInArray:itemsToSelect];
      
      //reorder tmpDraggedItems
      NSMutableArray* orderedTmpDraggedItems = [NSMutableArray arrayWithCapacity:[tmpDraggedItems count]];
      NSMutableIndexSet* indexSetForReordering   = [NSMutableIndexSet indexSet];
      NSEnumerator *tmpDraggedItemsEnumerator = [tmpDraggedItems objectEnumerator];
      LibraryItem *tmpDraggedItem = [tmpDraggedItemsEnumerator nextObject];
      while (tmpDraggedItem)
      {
        [indexSetForReordering addIndex:[outlineView rowForItem:tmpDraggedItem]];
        tmpDraggedItem = [tmpDraggedItemsEnumerator nextObject];
      }
      unsigned int index = [indexSetForReordering firstIndex];
      while(index != NSNotFound)
      {
        [orderedTmpDraggedItems addObject:[outlineView itemAtRow:index]];
        index = [indexSetForReordering indexGreaterThanIndex:index];
      }

      //compute parents indexes of children
      NSMutableArray* parents = [NSMutableArray arrayWithCapacity:[orderedTmpDraggedItems count]];
      NSMutableArray* indexesOfChildren = [NSMutableArray arrayWithCapacity:[orderedTmpDraggedItems count]];
      tmpDraggedItemsEnumerator = [orderedTmpDraggedItems objectEnumerator];
      tmpDraggedItem = [tmpDraggedItemsEnumerator nextObject];
      while (tmpDraggedItem)
      {
        LibraryItem *tmpDraggedParent = [tmpDraggedItem parent];
        [parents addObject:tmpDraggedParent];
        [indexesOfChildren addObject:[NSNumber numberWithInt:[tmpDraggedParent indexOfChild:tmpDraggedItem]]];
        tmpDraggedItem = [tmpDraggedItemsEnumerator nextObject];
      }
        
      //perform removal
      tmpDraggedItemsEnumerator = [orderedTmpDraggedItems objectEnumerator];
      tmpDraggedItem = [tmpDraggedItemsEnumerator nextObject];
      while (tmpDraggedItem)
      {
        LibraryItem *tmpDraggedParent = [tmpDraggedItem parent];
        if ((parentItem == tmpDraggedParent) && ([parentItem indexOfChild:tmpDraggedItem] < childIndex))
          --childIndex;
        [tmpDraggedParent removeChild:tmpDraggedItem];
        tmpDraggedItem = [tmpDraggedItemsEnumerator nextObject];
      }
      [[undoManager prepareWithInvocationTarget:self] _reinsertItems:orderedTmpDraggedItems atParents:parents
                                                           atIndexes:indexesOfChildren];

      //then, insertion
      [parentItem insertChildren:orderedTmpDraggedItems atIndex:childIndex];
      //saves titles
      NSMutableArray* oldTitles = [NSMutableArray arrayWithCapacity:[orderedTmpDraggedItems count]];
      NSEnumerator* orderedTmpDraggedItemsEnumerator = [orderedTmpDraggedItems objectEnumerator];
      LibraryItem* item = [orderedTmpDraggedItemsEnumerator nextObject];
      while(item)
      {
        [oldTitles addObject:[item title]];
        item = [orderedTmpDraggedItemsEnumerator nextObject];
      }
      //update titles
      [orderedTmpDraggedItems makeObjectsPerformSelector:@selector(updateTitle)];
      [[undoManager prepareWithInvocationTarget:self] _setTitles:oldTitles onItems:orderedTmpDraggedItems];
      [[undoManager prepareWithInvocationTarget:self] removeItems:orderedTmpDraggedItems];
      if (![undoManager isUndoing])
        [undoManager setActionName:NSLocalizedString(@"Move Library items", @"Move Library items")];
    }
    else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:HistoryItemsPboardType]])
    {
      NSData* data = [pboard dataForType:HistoryItemsPboardType];
      NSArray* array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
      NSEnumerator* enumerator  = [array objectEnumerator];
      HistoryItem* historyItem  = [enumerator nextObject];
      while (historyItem)
      {
        LibraryFile* libraryFile = [[[LibraryFile alloc] init] autorelease];
        [libraryFile setValue:historyItem setAutomaticTitle:YES];
        itemsToSelect = [NSArray arrayWithObject:libraryFile];
        [parentItem insertChild:libraryFile atIndex:childIndex++];
        NSString* oldTitle = [libraryFile title];
        [libraryFile updateTitle];
        [[undoManager prepareWithInvocationTarget:self] _setTitle:oldTitle onItem:libraryFile];
        [[undoManager prepareWithInvocationTarget:self] removeItems:[NSArray arrayWithObject:libraryFile]];
        historyItem = [enumerator nextObject];
      }
      if (![undoManager isUndoing])
        [undoManager setActionName:NSLocalizedString(@"Add Library items", @"Add Library items")];
    }

    [[NSNotificationCenter defaultCenter] postNotificationName:LibraryDidChangeNotification object:nil];
    
    //updates selection
    NSEnumerator* enumerator = [itemsToSelect objectEnumerator];
    LibraryItem* itemToExpand = [enumerator nextObject];
    while(itemToExpand)
    {
      LibraryItem* parentToExpand = [itemToExpand parent];
      [outlineView expandItem:parentToExpand];
      itemToExpand = [enumerator nextObject];
    }

    if (itemsToSelect && [itemsToSelect count])
    {
      NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:itemsToSelect, @"select",
                                                                      [itemsToSelect lastObject], @"scroll", nil];
      [[NSNotificationCenter defaultCenter] postNotificationName:LibraryDidChangeNotification
                                                          object:nil
                                                        userInfo:dict];
    }
  }//end @synchronized(library)  
  libraryShouldBeSaved = YES;
}

-(void) _setTitle:(NSString*)title onItem:(LibraryItem*)item
{
  NSString* oldTitle = [item title];
  [item setTitle:title];
  [[undoManager prepareWithInvocationTarget:self] _setTitle:oldTitle onItem:item];
}

-(void) _setTitles:(NSArray*)titles onItems:(NSArray*)items
{
  //saves titles
  NSMutableArray* oldTitles = [NSMutableArray arrayWithCapacity:[items count]];
  NSEnumerator* enumerator = [items objectEnumerator];
  NSEnumerator* titleEnumerator = [titles objectEnumerator];
  LibraryItem* item = [enumerator nextObject];
  while(item)
  {
    [oldTitles addObject:[item title]];
    [item setTitle:[titleEnumerator nextObject]];
    item = [enumerator nextObject];
  }
  //update titles
  [[undoManager prepareWithInvocationTarget:self] _setTitles:oldTitles onItems:items];
}

//outline view delegate methods

-(BOOL) outlineView:(NSOutlineView*)outlineView shouldCollapseItem:(id)item
{
  [item setExpanded:NO];
  [self setLibraryShouldBeSaved:YES];
  return YES;
}

-(BOOL) outlineView:(NSOutlineView*)outlineView shouldExpandItem:(id)item
{
  [item setExpanded:YES];
  [self setLibraryShouldBeSaved:YES];
  return YES;
}

-(void) outlineViewSelectionDidChange:(NSNotification*)notification
{
  NSOutlineView* outlineView = [notification object];
  [outlineView scrollRowToVisible:[[outlineView selectedRowIndexes] firstIndex]];

  MyDocument* document = (MyDocument*)[AppController currentDocument];
  if (document && ([outlineView selectedRow] >= 0))
  {
    LibraryItem* libraryItem = [outlineView itemAtRow:[outlineView selectedRow]];
    if ([libraryItem isKindOfClass:[LibraryFile class]])
      [document applyHistoryItem:[(LibraryFile*)libraryItem value]];
    else if ([libraryItem isKindOfClass:[LibraryFolder class]])
      [document applyHistoryItem:nil];
  }
}

-(id)outlineView:(NSOutlineView*)outlineView
     objectValueForTableColumn:(NSTableColumn*)tableColumn byItem:(id)item
{
  return [item title];
}

-(void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
  [[undoManager prepareWithInvocationTarget:self] outlineView:outlineView setObjectValue:[item title] 
                                               forTableColumn:tableColumn byItem:item];
  if (![undoManager isUndoing])
    [undoManager setActionName:NSLocalizedString(@"Change Library item name", @"Change Library item name")];
  [item setTitle:object];
  [outlineView reloadItem:item];
  libraryShouldBeSaved = YES;
}

-(void) outlineView:(NSOutlineView*)outlineView willDisplayCell:(id)cell
     forTableColumn:(NSTableColumn*)tableColumn item:(id)item
{
  LibraryTableView* libraryTableView = (LibraryTableView*)outlineView;
  library_row_t libraryRowType = [libraryTableView libraryRowType];
  if (libraryRowType == LIBRARY_ROW_IMAGE_AND_TEXT)
    [cell setImage:[item icon]];
  else if (libraryRowType == LIBRARY_ROW_IMAGE_LARGE)
  {
    if ([item isKindOfClass:[LibraryFile class]])
      [cell setImage:[[(LibraryFile*)item value] pdfImage]];
    else if ([item isKindOfClass:[LibraryFolder class]])
      [cell setImage:[(LibraryFolder*)item bigIcon]];
    else
      [cell setImage:[item icon]];
  }
}

//Some management (adding folders, files, removing...), undo-aware
-(void) refreshFileItem:(LibraryFile*)fileItem withValue:(HistoryItem*)value
{
  @synchronized(library)
  {
    [fileItem setValue:value setAutomaticTitle:NO];
    libraryShouldBeSaved = YES;
  }
}

-(LibraryItem*) newFolder:(NSOutlineView*)outlineView
{
  LibraryFolder* newFolder = nil;
  @synchronized(library)
  {
    LibraryItem* parent = nil;

    int selectedRow = [outlineView selectedRow];
    if (selectedRow >= 0)
    {
      LibraryItem* item = [outlineView itemAtRow:selectedRow];
      parent = [item parent];
    }
    if (parent == nil)
      parent = library;
    
    newFolder = [[LibraryFolder alloc] init];
    [parent insertChild:newFolder];
    [newFolder updateTitle];

    [[undoManager prepareWithInvocationTarget:self] removeItems:[NSArray arrayWithObject:newFolder]];
    if (![undoManager isUndoing])
      [undoManager setActionName:NSLocalizedString(@"Add Library folder", @"Add Library folder")];
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSArray arrayWithObject:parent], @"expand",
                            [NSArray arrayWithObject:newFolder], @"scroll", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:LibraryDidChangeNotification
                                                        object:nil
                                                      userInfo:dict];
    libraryShouldBeSaved = YES;
  }//end @synchronized(library)
  return [newFolder autorelease];
}

-(LibraryItem*) newFile:(HistoryItem*)historyItem outlineView:(NSOutlineView*)outlineView
{
  LibraryFile* newLibraryFile = nil;
  @synchronized(library)
  {
    LibraryItem* parent = nil;

    int selectedRow = [outlineView selectedRow];
    if (selectedRow >= 0)
    {
      LibraryItem* item = [outlineView itemAtRow:selectedRow];
      parent = [item isKindOfClass:[LibraryFile class]] ? [item parent] : item;
    }
    if (parent == nil)
      parent = library;
    
    newLibraryFile = [[LibraryFile alloc] init];
    [newLibraryFile setValue:historyItem setAutomaticTitle:YES];
    [parent insertChild:newLibraryFile];
    [newLibraryFile updateTitle];

    [[undoManager prepareWithInvocationTarget:self] removeItems:[NSArray arrayWithObject:newLibraryFile]];
    if (![undoManager isUndoing])
      [undoManager setActionName:NSLocalizedString(@"Add Library item", @"Add Library item")];

    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
      [NSArray arrayWithObject:parent], @"expand",
      [NSArray arrayWithObject:newLibraryFile], @"scroll", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:LibraryDidChangeNotification
                                                        object:nil
                                                      userInfo:dict];
    libraryShouldBeSaved = YES;
  }//end @synchronized(library)
  return [newLibraryFile autorelease];
}

-(LibraryItem*) addItem:(LibraryItem*)libraryItem outlineView:(NSOutlineView*)outlineView//adds a new item at the end
{
  @synchronized(library)
  {
    LibraryItem* parent = nil;

    int selectedRow = [outlineView selectedRow];
    if (selectedRow >= 0)
    {
      LibraryItem* item = [outlineView itemAtRow:selectedRow];
      parent = [item isKindOfClass:[LibraryFile class]] ? [item parent] : item;
    }
    if (parent == nil)
      parent = library;
      
    //add item
    [parent insertChild:libraryItem];
    [libraryItem updateTitle];
    
    [[undoManager prepareWithInvocationTarget:self] removeItems:[NSArray arrayWithObject:libraryItem]];
    if (![undoManager isUndoing])
      [undoManager setActionName:NSLocalizedString(@"Add Library item", @"Add Library item")];
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:
                            [NSArray arrayWithObject:parent], @"expand",
                            [NSArray arrayWithObject:libraryItem], @"scroll", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:LibraryDidChangeNotification
                                                        object:nil
                                                      userInfo:dict];
    libraryShouldBeSaved = YES;
  }
  return libraryItem;
}

-(void) removeItems:(NSArray*)items
{
  @synchronized(library)
  {
    //stores parent and indexes of items to remove
    NSMutableArray* parents   = [NSMutableArray arrayWithCapacity:[items count]];
    NSMutableArray* indexes   = [NSMutableArray arrayWithCapacity:[items count]];
    NSEnumerator* enumerator  = [items objectEnumerator];
    LibraryItem* itemToRemove = [enumerator nextObject];
    while(itemToRemove)
    {
      LibraryItem* parent = [itemToRemove parent];
      [parents addObject:parent];
      [indexes addObject:[NSNumber numberWithInt:[parent indexOfChild:itemToRemove]]];
      itemToRemove = [enumerator nextObject];
    }

    //remove items
    enumerator = [items objectEnumerator];
    itemToRemove = [enumerator nextObject];
    while(itemToRemove)
    {
      LibraryItem* parent = [itemToRemove parent];
      [parent removeChild:itemToRemove];
      itemToRemove = [enumerator nextObject];
    }

    [[undoManager prepareWithInvocationTarget:self] _reinsertItems:items atParents:parents atIndexes:indexes];
    if (![undoManager isUndoing])
    {
      if ([items count] > 1)
        [undoManager setActionName:NSLocalizedString(@"Delete Library items", @"Delete Library items")];
      else
        [undoManager setActionName:NSLocalizedString(@"Delete Library item", @"Delete Library item")];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:LibraryDidChangeNotification object:nil];
    
    libraryShouldBeSaved = YES;
  }//end @synchronized(library)
}

//useful for undoing
-(void) _reinsertItems:(NSArray*)items atParents:(NSArray*)parents atIndexes:(NSArray*)indexes
{
  @synchronized(library)
  {
    const unsigned int count = MIN(MIN([items count], [parents count]), [indexes count]);
    NSMutableArray* oldParents = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray* oldIndexes = [NSMutableArray arrayWithCapacity:count];
    unsigned int i = 0;
    for(i = 0 ; i < count ; ++i)
    {
      LibraryItem* item   = [items   objectAtIndex:i];
      LibraryItem* parent = [parents objectAtIndex:i];
      unsigned int index  = [[indexes objectAtIndex:i] intValue];
      LibraryItem* oldParent = [item parent];
      if (oldParent)
      {
        [oldParents addObject:oldParent];
        [oldIndexes addObject:[NSNumber numberWithInt:[oldParent indexOfChild:item]]];
      }
      [item removeFromParent];
      [parent insertChild:item atIndex:index];
    }
    
    if ([oldParents count])
      [[undoManager prepareWithInvocationTarget:self] _reinsertItems:items atParents:oldParents atIndexes:oldIndexes];
    else
      [[undoManager prepareWithInvocationTarget:self] removeItems:items];

    NSMutableArray* itemsToExpand = [NSMutableArray arrayWithCapacity:[items count]];
    NSEnumerator* enumerator = [items objectEnumerator];
    LibraryItem* itemToExpand = [enumerator nextObject];
    while(itemToExpand)
    {
      LibraryItem* parentToExpand = [itemToExpand parent];
      [itemsToExpand addObject:parentToExpand];
      itemToExpand = [enumerator nextObject];
    }
    
    NSDictionary* dict = [NSDictionary dictionaryWithObjectsAndKeys:itemsToExpand, @"expand", items, @"select", nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:LibraryDidChangeNotification object:nil userInfo:dict];
    
    libraryShouldBeSaved = YES;
  }//end @synchronized(library)
}

@end
