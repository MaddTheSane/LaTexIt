//  LibraryFile.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.

//The LibraryFile is a libraryItem (that can appear in the library outlineview)
//But it represents a "file", that is to say a document state
//This state is stored as an historyItem, that is already perfect for that

#import "LibraryFile.h"

#import "HistoryItem.h"
#import "LatexitEquation.h"
#import "LibraryEquation.h"
#import "NSManagedObjectContextExtended.h"

@implementation LibraryFile

-(void) encodeWithCoder:(NSCoder*)coder
{
}
//end encodeWithCoder:

-(id) initWithCoder:(NSCoder*)coder
{
  id oldSelf = [super init];
  NSManagedObjectContext* managedObjectContext = [LatexitEquation currentManagedObjectContext];
  self = [[LibraryEquation alloc] initWithEntity:[LibraryEquation entity] insertIntoManagedObjectContext:managedObjectContext];
  [oldSelf autorelease];
  oldSelf = nil;
  if (!self)
    return nil;
  HistoryItem* historyItem = [coder decodeObjectForKey:@"value"];
  LatexitEquation* latexitEquation = [[historyItem equation] retain];
  [historyItem setEquation:nil];
  [managedObjectContext safeInsertObject:latexitEquation];
  [latexitEquation release];
  [(LibraryEquation*)self setEquation:latexitEquation];
  if (![(LibraryEquation*)self title])
    [(LibraryEquation*)self setBestTitle];
  [managedObjectContext safeDeleteObject:historyItem];
  return self;
}
//end initWithCoder:

@end
