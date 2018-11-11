//
//  LibraryController.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/05/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "LibraryController.h"

#import "AppController.h"
#import "LaTeXProcessor.h"
#import "LatexitEquation.h"
#import "LibraryEquation.h"
#import "LibraryGroupItem.h"
#import "LibraryManager.h"
#import "LibraryView.h"
#import "LibraryWindowController.h"
#import "NSArrayExtended.h"
#import "NSColorExtended.h"
#import "NSFileManagerExtended.h"
#import "NSManagedObjectContextExtended.h"
#import "NSMutableArrayExtended.h"
#import "NSObjectExtended.h"
#import "NSObjectTreeNode.h"
#import "NSStringExtended.h"
#import "NSWorkspaceExtended.h"
#import "PreferencesController.h"

#import "Utils.h"

#import "RegexKitLite.h"

@interface LibraryController (PrivateAPI)
@property (readonly, copy) NSFetchRequest *rootFetchRequest;
-(BOOL) outlineView:(NSOutlineView*)outlineView isSelfMoveDrop:(id<NSDraggingInfo>)info;
@end

@implementation LibraryController (PrivateAPI)

-(NSFetchRequest*) rootFetchRequest
{
  if (!self->rootFetchRequest)
  {
    @synchronized(self)
    {
      if (!self->rootFetchRequest)
      {
        NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
        fetchRequest.entity = [LibraryItem entity];
        fetchRequest.predicate = [NSPredicate predicateWithFormat:@"parent == nil"];
        fetchRequest.sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"sortIndex" ascending:YES]];
        self->rootFetchRequest = fetchRequest;
      }//end if (!self->rootFetchRequest)
    }//end @synchronized(self)
  }//end if (!self->rootFetchRequest)
  return self->rootFetchRequest;
}
//end rootFetchRequest

-(BOOL) outlineView:(NSOutlineView*)outlineView isSelfMoveDrop:(id<NSDraggingInfo>)info
{
  BOOL result = NO;
  if (outlineView == [info draggingSource])
  {
    NSPasteboard* pboard = [info draggingPasteboard];
    NSArray* wrappedItems = ![pboard availableTypeFromArray:@[LibraryItemsWrappedPboardType]] ? nil :
      [pboard propertyListForType:LibraryItemsWrappedPboardType];  
    result = (wrappedItems != nil);
  }//end if (outlineView == [info draggingSource])
  return result;
}
//end outlineView:isSelfMoveDrop:

@end

@implementation LibraryController

-(NSManagedObjectContext*) managedObjectContext
{
  return [[LibraryManager sharedManager] managedObjectContext];
}
//end managedObjectContext

-(NSUndoManager*) undoManager
{
  return [self managedObjectContext].undoManager;
}
//end undoManager

-(NSArray*) rootItems
{
  NSArray* result = nil;
  NSError* error = nil;
  result = [[self managedObjectContext] executeFetchRequest:[self rootFetchRequest] error:&error];
  if (error) {DebugLog(0, @"error : %@", error);}
  return result;
}
//end rootItems

-(void) fixChildrenSortIndexesForParent:(LibraryGroupItem*)parent recursively:(BOOL)recursively
{
  [[LibraryManager sharedManager] fixChildrenSortIndexesForParent:parent recursively:recursively];
}
//end fixChildrenSortIndexesForParent:

-(void) removeItem:(id)item
{
  NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
  [managedObjectContext safeDeleteObject:item];
}
//end removeItem:

-(void) removeItems:(NSArray*)items
{
  NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
  [managedObjectContext safeDeleteObjects:items];
}
//end removeItems:

#pragma mark NSOutlineViewDataSource

-(NSInteger) outlineView:(NSOutlineView*)outlineView numberOfChildrenOfItem:(id)item
{
  NSInteger result = 0;
  if (item)
    result = [item children].count;
  else
    result = [[self managedObjectContext] myCountForFetchRequest:[self rootFetchRequest] error:nil];
  return result;
}
//end outlineView:numberOfChildrenOfItem:

-(id) outlineView:(NSOutlineView*)outlineView objectValueForTableColumn:(NSTableColumn*)tableColumn byItem:(id)item
{
  id result = nil;
  if (tableColumn == outlineView.outlineTableColumn)
    result = [item title];
  return result;
}
//end outlineView:objectValueForTableColumn:byItem:

-(id) outlineView:(NSOutlineView*)outlineView child:(NSInteger)index ofItem:(id)item
{
  id result = nil;
  NSArray* childrenOrdered = !item ? [self rootItems] : [item childrenOrdered];
  result = childrenOrdered[index];
  return result;
}
//end outlineView:child:ofItem:

-(BOOL) outlineView:(NSOutlineView*)outlineView isItemExpandable:(id)item
{
  BOOL result = [item isKindOfClass:[LibraryGroupItem class]];
  return result;
}
//end outlineView:isItemExpandable:

#pragma mark drag'n drop

//write the pasteboard when dragging begins
-(BOOL) outlineView:(NSOutlineView*)outlineView writeItems:(NSArray*)items toPasteboard:(NSPasteboard*)pasteBoard
{
  self->currentlyDraggedItems = nil;
  [pasteBoard declareTypes:@[] owner:nil];
  
  PreferencesController* preferencesController = [PreferencesController sharedController];
  BOOL isChangePasteboardOnTheFly = ([pasteBoard dataForType:NSFilesPromisePboardType] != nil);
  if (!isChangePasteboardOnTheFly)
    [pasteBoard declareTypes:@[] owner:nil];
  
  NSArray* minimumItemsCover = [NSObject minimumNodeCoverFromItemsInArray:items parentSelector:@selector(parent)];
  NSUInteger count = minimumItemsCover.count;
  NSMutableArray* libraryItems     = [NSMutableArray arrayWithCapacity:count];
  NSMutableArray* libraryEquations = [NSMutableArray arrayWithCapacity:count];
  NSMutableArray* latexitEquations = [NSMutableArray arrayWithCapacity:count];
  NSEnumerator* enumerator = [minimumItemsCover objectEnumerator];
  LibraryItem* libraryItem = nil;
  while((libraryItem = [enumerator nextObject]))
  {
    [libraryItems addObject:libraryItem];
    LibraryEquation* libraryEquation = ![libraryItem isKindOfClass:[LibraryEquation class]] ? nil : (LibraryEquation*)libraryItem;
    if (libraryEquation)
      [libraryEquations addObject:libraryEquation];
    LatexitEquation* latexitEquation = !libraryEquation ? nil : libraryEquation.equation;
    if (latexitEquation)
      [latexitEquations addObject:latexitEquation];
  }//end for each item

  if (libraryItems.count)
  {
    self->currentlyDraggedItems = (pasteBoard == [NSPasteboard pasteboardWithName:NSDragPboard]) ? libraryItems : nil;
    NSMutableArray* wrappedLibraryItems = [NSMutableArray arrayWithCapacity:libraryItems.count];
    NSEnumerator* enumerator = [libraryItems objectEnumerator];
    LibraryItem* libraryItem = nil;
    while((libraryItem = [enumerator nextObject]))
      [wrappedLibraryItems addObject:[libraryItem.objectID URIRepresentation].absoluteString];
    [pasteBoard addTypes:@[LibraryItemsWrappedPboardType] owner:self];
    [pasteBoard setPropertyList:wrappedLibraryItems forType:LibraryItemsWrappedPboardType];

    [pasteBoard addTypes:@[LibraryItemsArchivedPboardType] owner:self];
    [pasteBoard setData:[NSKeyedArchiver archivedDataWithRootObject:libraryItems] forType:LibraryItemsArchivedPboardType];
  }

  if (latexitEquations.count)
  {
    [pasteBoard addTypes:@[LatexitEquationsPboardType] owner:self];
    [pasteBoard setData:[NSKeyedArchiver archivedDataWithRootObject:latexitEquations] forType:LatexitEquationsPboardType];

    //bonus : we can also feed other pasteboards with one of the selected items
    //The pasteboard (PDF, PostScript, TIFF... will depend on the user's preferences
    LatexitEquation* lastLatexitEquation = latexitEquations.lastObject;
    export_format_t exportFormat = preferencesController.exportFormatCurrentSession;
    [lastLatexitEquation writeToPasteboard:pasteBoard exportFormat:exportFormat isLinkBackRefresh:NO lazyDataProvider:lastLatexitEquation options:nil];
  }//end if ([latexitEquations count])

  if (count && !isChangePasteboardOnTheFly)
  {
    //promise file occur when drag'n dropping to the finder. The files will be created in tableview:namesOfPromisedFiles:...
    [pasteBoard addTypes:@[NSFilesPromisePboardType] owner:self];
    [pasteBoard setPropertyList:@[@"pdf", @"eps", @"tiff", @"jpeg", @"png", @"svg", @"html"] forType:NSFilesPromisePboardType];
  }

  //NSStringPBoardType may contain some info for LibraryFiles the label of the equations : useful for users that only want to \ref this equation
  if (libraryEquations.count && preferencesController.encapsulationsEnabled)
  {
    NSString*        encapsulation = preferencesController.encapsulationSelected;
    NSMutableString* labels        = [NSMutableString string];
    NSEnumerator*    enumerator    = [libraryEquations objectEnumerator];
    LibraryEquation* libraryEquation = nil;
    while((libraryEquation = [enumerator nextObject]))
    {
      LatexitEquation* latexitEquation = libraryEquation.equation;
      NSString* title  = libraryEquation.title;
      NSString* source = latexitEquation.sourceText.string;
      NSMutableString* replacedText = [NSMutableString stringWithString:!encapsulation ? @"" : encapsulation];
      if (title)
        [replacedText replaceOccurrencesOfString:@"@" withString:title options:NSLiteralSearch range:NSMakeRange(0, replacedText.length)];
      if (source)
        [replacedText replaceOccurrencesOfString:@"#" withString:source options:NSLiteralSearch range:NSMakeRange(0, replacedText.length)];
      [labels appendString:replacedText];
    }//end for each libraryEquationItem
    export_format_t exportFormat = preferencesController.exportFormatCurrentSession;
    if (exportFormat != EXPORT_FORMAT_MATHML)
    {
      [pasteBoard addTypes:@[NSStringPboardType] owner:nil];
      [pasteBoard setString:labels forType:NSStringPboardType];
    }//end if (exportFormat != EXPORT_FORMAT_MATHML)
  }//end if ([libraryEquationsItems count])

  return YES;
}
//end outlineView:writeItems:toPasteboard:

//validates a dropping destination in the library view
-(NSDragOperation) outlineView:(NSOutlineView*)outlineView validateDrop:(id<NSDraggingInfo>)info
                  proposedItem:(id)proposedParentItem proposedChildIndex:(NSInteger)proposedChildIndex
{
  NSDragOperation result = NSDragOperationNone;

  NSPasteboard* pasteboard = [info draggingPasteboard];
  BOOL isSelfMoveDrop = [self outlineView:outlineView isSelfMoveDrop:info];
  BOOL isLaTeXiTEquationsDrop = ([pasteboard availableTypeFromArray:@[LatexitEquationsPboardType]] != nil);
  BOOL isPDFDrop = ([pasteboard availableTypeFromArray:@[NSPasteboardTypePDF, (id)kUTTypePDF]] != nil);
  BOOL isFileDrop = ([pasteboard availableTypeFromArray:@[NSFilenamesPboardType]] != nil);
  BOOL isColorDrop = ([pasteboard availableTypeFromArray:@[NSPasteboardTypeColor]] != nil);
  if (isSelfMoveDrop)
  {
    BOOL targetIsValid = (proposedChildIndex != NSOutlineViewDropOnItemIndex) ||
                         [proposedParentItem isKindOfClass:[LibraryGroupItem class]];
    NSEnumerator* enumerator = [self->currentlyDraggedItems objectEnumerator];
    LibraryItem*  draggedLibraryItem = nil;
    while(targetIsValid && ((draggedLibraryItem = [enumerator nextObject])))
    {
      if ([draggedLibraryItem isKindOfClass:[LibraryGroupItem class]])
      {
        if ([proposedParentItem isDescendantOfNode:draggedLibraryItem strictly:NO parentSelector:@selector(parent)])// can't drop a group on one of its descendants
          targetIsValid = NO;
      }//end if (![treeNode isLeaf])
    }//end for each indexPath
    result = targetIsValid ? NSDragOperationMove : NSDragOperationNone;
  }
  else if (isLaTeXiTEquationsDrop)
  {
    LibraryItem* libraryItem = proposedParentItem;
    if ((proposedChildIndex != NSOutlineViewDropOnItemIndex) || [libraryItem isKindOfClass:[LibraryGroupItem class]])
      result = NSDragOperationCopy;
  }
  else if (isPDFDrop)
  {
    LibraryItem* libraryItem = proposedParentItem;
    if ((proposedChildIndex != NSOutlineViewDropOnItemIndex) || [libraryItem isKindOfClass:[LibraryGroupItem class]])
      result = NSDragOperationCopy;
  }//end if (isPDFDrop)
  else if (isFileDrop)
  {
    LibraryItem* libraryItem = proposedParentItem;
    NSArray* filenames = [pasteboard propertyListForType:NSFilenamesPboardType];
    NSString* filename = (filenames.count == 1) ? filenames.lastObject : nil;
    NSString* extension = filename.pathExtension;
    BOOL isLibraryFile = extension && (([extension caseInsensitiveCompare:@"latexlib"] == NSOrderedSame) ||
                                       ([extension caseInsensitiveCompare:@"latexhist"] == NSOrderedSame) ||
                                       ([extension caseInsensitiveCompare:@"plist"] == NSOrderedSame));
    if (isLibraryFile)
    {
      [outlineView setDropItem:nil dropChildIndex:NSOutlineViewDropOnItemIndex];
      result = NSDragOperationCopy;
    }
    else if (!proposedParentItem || (proposedChildIndex != NSOutlineViewDropOnItemIndex) || [libraryItem isKindOfClass:[LibraryGroupItem class]])
      result = NSDragOperationCopy;
  }//end if (isFileDrop)
  else if (isColorDrop)
  {
    LibraryItem* libraryItem = proposedParentItem;
    if ([libraryItem isKindOfClass:[LibraryEquation class]] && (proposedChildIndex == NSOutlineViewDropOnItemIndex))
      result = NSDragOperationCopy;
  }//end if (isColorDrop)
  return result;
}
//end outlineView:validateDrop:proposedItem:proposedChildIndex:

//accepts drop
-(BOOL) outlineView:(NSOutlineView*)outlineView acceptDrop:(id<NSDraggingInfo>)info item:(id)proposedParentItem childIndex:(NSInteger)proposedChildIndex
{
  BOOL result = NO;
  NSPasteboard* pasteboard = [info draggingPasteboard];
  BOOL isSelfMoveDrop = [self outlineView:outlineView isSelfMoveDrop:info];
  BOOL isLaTeXiTEquationsDrop = ([pasteboard availableTypeFromArray:@[LatexitEquationsPboardType]] != nil);
  BOOL isPDFDrop = ([pasteboard availableTypeFromArray:@[NSPasteboardTypePDF, (id)kUTTypePDF]] != nil);
  BOOL isFileDrop = ([pasteboard availableTypeFromArray:@[NSFilenamesPboardType]] != nil);
  BOOL isColorDrop = ([pasteboard availableTypeFromArray:@[NSPasteboardTypeColor]] != nil);
  if (isSelfMoveDrop)
    result = [(LibraryView*)outlineView pasteContentOfPasteboard:[info draggingPasteboard] onItem:proposedParentItem childIndex:proposedChildIndex];
  else if (isLaTeXiTEquationsDrop)
    result = [(LibraryView*)outlineView pasteContentOfPasteboard:[info draggingPasteboard] onItem:proposedParentItem childIndex:proposedChildIndex];
  else if (isPDFDrop)
    result = [(LibraryView*)outlineView pasteContentOfPasteboard:[info draggingPasteboard] onItem:proposedParentItem childIndex:proposedChildIndex];
  else if (isFileDrop)
  {
    NSArray* filenames = [pasteboard propertyListForType:NSFilenamesPboardType];
    NSString* filename = (filenames.count == 1) ? filenames.lastObject : nil;
    NSString* extension = filename.pathExtension;
    BOOL isLibraryFile = extension && (([extension caseInsensitiveCompare:@"latexlib"]  == NSOrderedSame) ||
                                       ([extension caseInsensitiveCompare:@"latexhist"]  == NSOrderedSame) ||
                                       ([extension caseInsensitiveCompare:@"plist"]  == NSOrderedSame));
    if (isLibraryFile)
    {
      [[AppController appController] application:NSApp openFile:filename];
      result = YES;
    }
    else //create folders and equations from folders of PDF files
    {
      NSFileManager* fileManager = [NSFileManager defaultManager];
      BOOL isDirectory = NO;
      NSManagedObjectContext* managedObjectContext = [self managedObjectContext];
      NSMutableDictionary* dictionaryOfFoldersByPath = [[NSMutableDictionary alloc] initWithCapacity:filenames.count];
      NSMutableArray* candidateFilesQueue = [filenames mutableCopy];
      NSMutableArray* newLibraryRootItems = [[NSMutableArray alloc] initWithCapacity:filenames.count];
      NSMutableArray* teXItems = [NSMutableArray array];
      unsigned int i = 0;
      for(i = 0 ; i<candidateFilesQueue.count ; ++i)
      {
        NSString* filename = candidateFilesQueue[i];
        NSString* filenameUTI = [fileManager UTIFromPath:filename];
        if ([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory)//explore folders
        {
          LibraryGroupItem* parent = dictionaryOfFoldersByPath[filename.stringByDeletingLastPathComponent];
          LibraryGroupItem* libraryGroupItem  = [[LibraryGroupItem alloc] initWithParent:nil insertIntoManagedObjectContext:managedObjectContext];
          libraryGroupItem.title = filename.lastPathComponent;
          libraryGroupItem.sortIndex = [parent children].count;
          libraryGroupItem.parent = parent;
          if (!parent && libraryGroupItem)
            [newLibraryRootItems addObject:libraryGroupItem];
          dictionaryOfFoldersByPath[filename] = libraryGroupItem;
          NSDirectoryEnumerator* directoryEnumerator = [fileManager enumeratorAtPath:filename];
          NSString* subFile = nil;
          while((subFile = [directoryEnumerator nextObject]))
          {
            subFile = [filename stringByAppendingPathComponent:subFile];
            NSString* subFileUti = [fileManager UTIFromPath:subFile];
            if ([LatexitEquation latexitEquationPossibleWithUTI:subFileUti] ||
                ([fileManager fileExistsAtPath:subFile isDirectory:&isDirectory] && isDirectory))
              [candidateFilesQueue addObject:subFile];
          }
        }//end if ([fileManager fileExistsAtPath:filename isDirectory:&isDirectory] && isDirectory)//explore folders
        else if ([LatexitEquation latexitEquationPossibleWithUTI:filenameUTI])
        {
          NSData* data = [NSData dataWithContentsOfFile:filename options:NSUncachedRead error:nil];
          NSArray* latexitEquations = [LatexitEquation latexitEquationsWithData:data sourceUTI:filenameUTI useDefaults:YES];
          NSEnumerator* latexitEquationsEnumerator = [latexitEquations objectEnumerator];
          LatexitEquation* latexitEquation = nil;
          while((latexitEquation = [latexitEquationsEnumerator nextObject]))
          {
            LibraryGroupItem* parent = dictionaryOfFoldersByPath[filename.stringByDeletingLastPathComponent];
            if (!parent && [proposedParentItem isKindOfClass:[LibraryGroupItem class]])
              parent = proposedParentItem;
            LibraryEquation* libraryEquation = !latexitEquation ? nil :
              [[LibraryEquation alloc] initWithParent:nil insertIntoManagedObjectContext:managedObjectContext];
            libraryEquation.equation = latexitEquation;
            libraryEquation.sortIndex = [parent children].count;
            libraryEquation.parent = parent;
            [libraryEquation setBestTitle];
            if (!parent && libraryEquation)
              [newLibraryRootItems addObject:libraryEquation];
          }//end for each latexitEquation
        }//end if ([[filename pathExtension] caseInsensitiveCompare:@"pdf"] == NSOrderedSame)
        else//if other file
        {
          NSArray* newTeXItems = [[LibraryManager sharedManager] createTeXItemsFromFile:filename proposedParentItem:proposedParentItem proposedChildIndex:proposedChildIndex];
          if (newTeXItems)
            [teXItems addObjectsFromArray:newTeXItems];
        }//end if other file
      }//end for each filename
     
      if (teXItems.count > 0)
      {
        LibraryWindowController* libraryWindowController =
          [outlineView.window.windowController dynamicCastToClass:[LibraryWindowController class]];
        NSDictionary* options = @{@"teXItems": teXItems};
        [libraryWindowController performSelector:@selector(importTeXItemsWithOptions:) withObject:options afterDelay:0];
      }//end if ([teXItems count] > 0)
      

      //fix sortIndexes of root nodes
      NSMutableArray* brothers = [NSMutableArray arrayWithArray:
        !proposedParentItem ? [self rootItems] : [proposedParentItem childrenOrdered]];
      [brothers removeObjectsInArray:newLibraryRootItems];
      [brothers insertObjectsFromArray:newLibraryRootItems atIndex:(proposedChildIndex == NSOutlineViewDropOnItemIndex) ?
        brothers.count : (unsigned)proposedChildIndex];
      NSUInteger nbBrothers = brothers.count;
      while(nbBrothers--)
        [brothers[nbBrothers] setSortIndex:nbBrothers];

      result = YES;
    }//end if pdfFiles
  }//end if (isFileDrop)
  else if (isColorDrop)
  {
    NSColor* color = [NSColor colorWithData:[pasteboard dataForType:NSPasteboardTypeColor]];
    if ([proposedParentItem isKindOfClass:[LibraryEquation class]])
    {
      ((LibraryEquation*)proposedParentItem).equation.backgroundColor = color;
      [[self undoManager] setActionName:NSLocalizedString(@"Change Library item background color", @"Change Library item background color")];
    }//if ([proposedParentItem isKindOfClass:[LibraryEquation class]])
    result = YES;
  }//end if (isColorDrop)
  [[self managedObjectContext] processPendingChanges];
  [outlineView reloadData];
  [outlineView sizeLastColumnToFit];
  self->currentlyDraggedItems = nil;
  return result;
}
//end outlineView:acceptDrop:item:childIndex:

//Creates the files of the files promised in the pasteboard
-(NSArray*) outlineView:(NSOutlineView*)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL*)dropDestination
        forDraggedItems:(NSArray*)items
{
  NSMutableArray* names = [NSMutableArray arrayWithCapacity:1];

  //this function is a little long, to address two problems :
  //1) the files created should have the name contained in the library items title, but in case of conflict, we must find a new
  //   name by adding a number
  //2) when dropping a LibraryGroupItem, we must create a folder and fill it (recursively, of course)

  //first, to address problems of 2), we must ensure that no item has an ancestor in the array of selected items
  items = [NSObject minimumNodeCoverFromItemsInArray:items parentSelector:@selector(parent)];

  PreferencesController* preferencesController = [PreferencesController sharedController];

  NSString* dropPath = dropDestination.path;
  NSFileManager* fileManager = [NSFileManager defaultManager];
  export_format_t exportFormat = preferencesController.exportFormatCurrentSession;
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
    case EXPORT_FORMAT_MATHML:
      extension = @"html";
      break;
    case EXPORT_FORMAT_SVG:
      extension = @"svg";
      break;
    case EXPORT_FORMAT_TEXT:
      extension = @"tex";
      break;
  }
  
  NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithFloat:[preferencesController exportJpegQualityPercent]], @"jpegQuality",
                                 [NSNumber numberWithFloat:[preferencesController exportScalePercent]], @"scaleAsPercent",
                                 [NSNumber numberWithBool:[preferencesController exportIncludeBackgroundColor]], @"exportIncludeBackgroundColor",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportPreamble]], @"textExportPreamble",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportEnvironment]], @"textExportEnvironment",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportBody]], @"textExportBody",
                                 [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                 nil];
  
  NSString* fileName = nil;
  NSString* filePath = nil;
  NSEnumerator* enumerator = [items objectEnumerator];
  LibraryItem* libraryItem = nil;
  while ((libraryItem = [enumerator nextObject]))
  {
    if ([libraryItem isKindOfClass:[LibraryGroupItem class]]) //if we create a folder...
    {
      LibraryGroupItem* libraryGroupItem = (LibraryGroupItem*)libraryItem;
      fileName = libraryItem.title;
      filePath = [dropPath stringByAppendingPathComponent:fileName];
      if (![fileManager fileExistsAtPath:filePath]) //does a folder of that name already exist ?
      {
        BOOL ok = [fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:0];
        if (ok)
        {
          //Recursive call to fill the folder
          [self outlineView:outlineView namesOfPromisedFilesDroppedAtDestination:[NSURL fileURLWithPath:filePath]
            forDraggedItems:[libraryGroupItem children].allObjects];
          [names addObject:fileName];
        }
      }//end if ok to create folder with title name
      else //if a folder of that name already exist, we must compute a new "free" name
      {
        unsigned long i = 1; //we will add a number
        do
        {
          fileName = [NSString stringWithFormat:@"%@-%lu", libraryItem.title, (unsigned long)i++];
          filePath = [dropPath stringByAppendingPathComponent:fileName];
        } while (i && [fileManager fileExistsAtPath:filePath]);
        
        //I may have found a free name; create the folder in this case
        if (![fileManager fileExistsAtPath:filePath])
        {
          BOOL ok = [fileManager createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:0];
          if (ok)
          {
            //Recursive call to fill the folder
            [self outlineView:outlineView namesOfPromisedFilesDroppedAtDestination:[NSURL fileURLWithPath:filePath]
              forDraggedItems:[libraryGroupItem children].allObjects];
            [names addObject:fileName];
          }
        }
      }//end if folder of given title already exists
    }//end if libraryItem is a folder
    else if ([libraryItem isKindOfClass:[LibraryEquation class]]) //do we create a file ?
    {
      LibraryEquation* libraryEquation = (LibraryEquation*)libraryItem;
      unsigned long i = 1; //if the name is not free, we will have to compute a new one
      NSString* filePrefix = libraryEquation.title;
      fileName = [NSString stringWithFormat:@"%@.%@", filePrefix, extension];
      filePath = [dropPath stringByAppendingPathComponent:fileName];
      if (![fileManager fileExistsAtPath:filePath]) //is the name free ?
      {
        LatexitEquation* latexitEquation = libraryEquation.equation;
        NSData* pdfData = latexitEquation.pdfData;
        NSData* data = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData
                         exportOptions:exportOptions
                         compositionConfiguration:preferencesController.compositionConfigurationDocument
                         uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];

        [fileManager createFileAtPath:filePath contents:data attributes:nil];
        [fileManager setAttributes:@{NSFileHFSCreatorCode: @((OSType)'LTXt')}
                             ofItemAtPath:filePath error:0];
        NSColor* jpegBackgroundColor = (exportFormat == EXPORT_FORMAT_JPEG) ? exportOptions[@"jpegColor"] : nil;
        NSColor* autoBackgroundColor = latexitEquation.backgroundColor;
        NSColor* iconBackgroundColor =
          (jpegBackgroundColor != nil) ? jpegBackgroundColor :
          (autoBackgroundColor != nil) ? autoBackgroundColor :
          nil;
        if ((exportFormat != EXPORT_FORMAT_PNG) &&
            (exportFormat != EXPORT_FORMAT_TIFF) &&
            (exportFormat != EXPORT_FORMAT_JPEG))
          [[NSWorkspace sharedWorkspace] setIcon:[[LaTeXProcessor sharedLaTeXProcessor] makeIconForData:pdfData backgroundColor:iconBackgroundColor]
                                         forFile:filePath options:NSExclude10_4ElementsIconCreationOption];
        [names addObject:fileName];
      }
      else //the name is not free, we must compute a new one by adding a number
      {
        do
        {
          fileName = [NSString stringWithFormat:@"%@-%lu.%@", filePrefix, (unsigned long)i++, extension];
          filePath = [dropPath stringByAppendingPathComponent:fileName];
        } while (i && [fileManager fileExistsAtPath:filePath]);
        
        //We may have found a name; in this case, create the file
        if (![fileManager fileExistsAtPath:filePath])
        {
          LatexitEquation* latexitEquation = libraryEquation.equation;
          NSData* pdfData = latexitEquation.pdfData;
          NSData* data = [[LaTeXProcessor sharedLaTeXProcessor] dataForType:exportFormat pdfData:pdfData
                           exportOptions:exportOptions
                           compositionConfiguration:preferencesController.compositionConfigurationDocument
                           uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];

          [fileManager createFileAtPath:filePath contents:data attributes:nil];
          [fileManager setAttributes:@{NSFileHFSCreatorCode: @((OSType)'LTXt')}
                               ofItemAtPath:filePath error:0];
          NSColor* jpegBackgroundColor = (exportFormat == EXPORT_FORMAT_JPEG) ? exportOptions[@"jpegColor"] : nil;
          NSColor* autoBackgroundColor = latexitEquation.backgroundColor;
          NSColor* iconBackgroundColor =
            (jpegBackgroundColor != nil) ? jpegBackgroundColor :
            (autoBackgroundColor != nil) ? autoBackgroundColor :
            nil;
          if ((exportFormat != EXPORT_FORMAT_PNG) &&
              (exportFormat != EXPORT_FORMAT_TIFF) &&
              (exportFormat != EXPORT_FORMAT_JPEG))
            [[NSWorkspace sharedWorkspace] setIcon:[[LaTeXProcessor sharedLaTeXProcessor] makeIconForData:pdfData backgroundColor:iconBackgroundColor]
                                           forFile:filePath options:NSExclude10_4ElementsIconCreationOption];
          [names addObject:fileName];
        }
      }//end if item of that title already exists
    }//end if libraryItem is LibraryFile
  }//end while item
  return names;
}
//end outlineView:namesOfPromisedFilesDroppedAtDestination:forDraggedItems:

@end
