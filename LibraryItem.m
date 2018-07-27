//  LibraryItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.

//A LibraryItem is similar to an XMLNode, in the way that it has parent (weak link to prevent cycling)
//and children (strong link)
//It is an abstract class, its derivations aim at presenting information in the Library outlineview of the library drawer
//Each libraryItem has a name and an icon

//This class is heavily inspired by the TreeData and TreeNode classes of the DragDropOutlineView provided
//by apple in the developer documentation

#import "LibraryItem.h"

#import "LaTeXProcessor.h"
#import "LatexitEquation.h"
#import "LibraryEquation.h"
#import "LibraryGroupItem.h"
#import "LibraryManager.h"
#import "NSManagedObjectContextExtended.h"
#import "NSMutableArrayExtended.h"
#import "Utils.h"

static NSEntityDescription* cachedEntity = nil;

@implementation LibraryItem

+(NSEntityDescription*) entity
{
  if (!cachedEntity)
  {
    @synchronized(self)
    {
      if (!cachedEntity)
        cachedEntity = [[[[[LaTeXProcessor sharedLaTeXProcessor] managedObjectModel] entitiesByName] objectForKey:NSStringFromClass([self class])] retain];
    }//end @synchronized(self)
  }//end if (!cachedEntity)
  return cachedEntity;
}
//end entity

-(id) initWithParent:(LibraryItem*)aParent insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  [self setParent:aParent];
  return self;
}
//end initWithParent:insertIntoManagedObjectContext:

-(void) dispose {}

-(id) copyWithZone:(NSZone*)zone
{
  id clone = [[[self class] allocWithZone:zone] initWithParent:[self parent] insertIntoManagedObjectContext:[self managedObjectContext]];
  [clone setTitle:[self title]];
  [clone setSortIndex:[self sortIndex]];
  return clone;
}
//end copyWithZone:

-(BOOL) dummyPropertyToForceUIRefresh
{
  return YES;
}
//end dummyPropertyToForceUIRefresh

-(NSString*) title
{
  NSString* result = nil;
  [self willAccessValueForKey:@"title"];
  result = [self primitiveValueForKey:@"title"];
  [self didAccessValueForKey:@"title"];
  return result;
}
//end title

-(void) setTitle:(NSString*)value
{
  NSString* oldTitle = [self title];
  if ((value != oldTitle) && ![value isEqualToString:oldTitle])
  {
    [self willChangeValueForKey:@"title"];
    [self setPrimitiveValue:value forKey:@"title"];
    [self didChangeValueForKey:@"title"];
  }//end if ((value != oldTitle) && ![value isEqualToString:oldTitle])
}
//end setTitle:

-(unsigned int) sortIndex
{
  unsigned int result = 0;
  [self willAccessValueForKey:@"sortIndex"];
  result = [[self primitiveValueForKey:@"sortIndex"] unsignedIntValue];
  [self didAccessValueForKey:@"sortIndex"];
  return result;
}
//end sortIndex

-(void) setSortIndex:(unsigned int)value
{
  if (value != [self sortIndex])
  {
    [self willChangeValueForKey:@"sortIndex"];
    [self setPrimitiveValue:[NSNumber numberWithUnsignedInt:value] forKey:@"sortIndex"];
    [self didChangeValueForKey:@"sortIndex"];
  }//end if (value != [self sortIndex])
}
//end setSortIndex:

-(LibraryItem*) parent
{
  LibraryItem* result = nil;
  [self willAccessValueForKey:@"parent"];
  result = [self primitiveValueForKey:@"parent"];
  [self didAccessValueForKey:@"parent"];
  return result;
}
//end parent

-(void) setParent:(LibraryItem*)value
{
  [self willChangeValueForKey:@"parent"];
  [[value managedObjectContext] safeInsertObject:self];
  [self setPrimitiveValue:value forKey:@"parent"];
  [self didChangeValueForKey:@"parent"];
}
//end setParent:

-(NSArray*) brothersIncludingMe:(BOOL)includingMe
{
  NSMutableArray* result = nil;
  LibraryGroupItem* theParent = (LibraryGroupItem*)[self parent];
  if (theParent)
    result = [NSMutableArray arrayWithArray:[theParent childrenOrdered]];
  else//if (!theParent)
  {
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[LibraryItem entity]];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"parent == nil"]];
    result = [NSMutableArray arrayWithArray:[[self managedObjectContext] executeFetchRequest:fetchRequest error:nil]];
    [fetchRequest release];
  }//end if (!theParent)
  if (!includingMe)
    [result removeObject:self];
  return result;
}
//end brothersIncludingMe:

-(void) setBestTitle//computes best title in current context
{
  NSString* itemTitle = [self title];
  NSArray* brothers = [self brothersIncludingMe:NO];
  NSMutableArray* brothersTitles = [[NSMutableArray alloc] initWithCapacity:[brothers count]];
  NSEnumerator* enumerator = [brothers objectEnumerator];
  LibraryItem* brother = nil;
  while((brother = [enumerator nextObject]))
  {
    NSString* brotherTitle = [brother title];
    if (brotherTitle)
      [brothersTitles addObject:brotherTitle];
  }//end for each brother
  NSString* libraryItemTitle = makeStringDifferent(itemTitle, brothersTitles, 0);
  [self setTitle:libraryItemTitle];//sets current and equation
  [brothersTitles release];
}
//end setBestTitle

-(id) initWithCoder:(NSCoder*)coder
{
  NSManagedObjectContext* managedObjectContext = [LatexitEquation currentManagedObjectContext];
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  [self setTitle:[coder decodeObjectForKey:@"title"]];
  [self setSortIndex:[coder decodeIntForKey:@"sortIndex"]];
  return self;
}
//end initWithCoder:

-(void) encodeWithCoder:(NSCoder*)coder
{
  [coder encodeObject:@"2.4.1" forKey:@"version"];
  [coder encodeObject:[self title] forKey:@"title"];
  [coder encodeInt:[self sortIndex] forKey:@"sortIndex"];
}
//end encodeWithCoder:

-(id) plistDescription
{
  NSMutableDictionary* plist = [NSMutableDictionary dictionaryWithObjectsAndKeys:
     @"2.4.1", @"version",
     [self title], @"title",
     [NSNumber numberWithUnsignedInt:[self sortIndex]], @"sortIndex",
     nil];
  return plist;
}
//end plistDescription

-(id) initWithDescription:(id)description
{
  NSManagedObjectContext* managedObjectContext = [LatexitEquation currentManagedObjectContext];
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  if (![description isKindOfClass:[NSDictionary class]])
  {
    [self release];
    return nil;
  }
  [self setTitle:[description objectForKey:@"title"]];
  [self setSortIndex:[[description objectForKey:@"sortIndex"] unsignedIntValue]];
  return self;
}
//end initWithDescription:

+(LibraryItem*) libraryItemWithDescription:(id)description
{
  LibraryItem* result = nil;
  BOOL ok = [description isKindOfClass:[NSDictionary class]];
  NSString* version = !ok ? nil : [description objectForKey:@"version"];
  BOOL isOldLibraryItem = (ok && ([version compare:@"2.0.0" options:NSNumericSearch] == NSOrderedAscending));
  BOOL isGroupItem = ok && ((!isOldLibraryItem && [description objectForKey:@"children"]) || (isOldLibraryItem && [description objectForKey:@"content"]));
  BOOL isEquation  = ok && ((isOldLibraryItem && !isGroupItem) || (!isOldLibraryItem && [description objectForKey:@"equation"]));
  Class instanceClass = !ok ? 0 :
    isGroupItem ? [LibraryGroupItem class] :
    isEquation ? [LibraryEquation class] :
    [LibraryItem class];
  result = !instanceClass ? nil : [[instanceClass alloc] initWithDescription:description];
  return [result autorelease];
}
//end libraryItemWithDescription:

@end
