//  LibraryItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 2/05/05.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.

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
#import "NSObjectExtended.h"
#import "NSWorkspaceExtended.h"
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

-(id) initWithEntity:(NSEntityDescription*)entity insertIntoManagedObjectContext:(NSManagedObjectContext*)context
{
  if (!((self = [super initWithEntity:entity insertIntoManagedObjectContext:context])))
    return nil;
  self->cachedSortIndex = NSNotFound;
  return self;
}
//end initWithEntity:

-(id) initWithParent:(LibraryItem*)aParent insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext
{
  if (!((self = [super initWithEntity:[[self class] entity] insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  [self setParent:aParent];
  return self;
}
//end initWithParent:insertIntoManagedObjectContext:

-(void) dispose
{
}
//end dispose

-(id) copyWithZone:(NSZone*)zone
{
  id clone = [[[self class] allocWithZone:zone] initWithParent:[self parent] insertIntoManagedObjectContext:[self managedObjectContext]];
  [clone setTitle:[self title]];
  [clone setSortIndex:[self sortIndex]];
  [clone setComment:[self comment]];
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

-(NSUInteger) sortIndex
{
  NSUInteger result = 0;
  if (self->cachedSortIndex != NSNotFound)
    result = self->cachedSortIndex;
  else//if (self->cachedSortIndex == NSNotFound)
  {
    [self willAccessValueForKey:@"sortIndex"];
    result = [[self primitiveValueForKey:@"sortIndex"] unsignedIntegerValue];
    [self didAccessValueForKey:@"sortIndex"];
    self->cachedSortIndex = result;
  }//end if (self->cachedSortIndex == NSNotFound)
  return result;
}
//end sortIndex

-(void) setSortIndex:(NSUInteger)value
{
  if (value != [self sortIndex])
  {
    [self willChangeValueForKey:@"sortIndex"];
    [self setPrimitiveValue:[NSNumber numberWithUnsignedInteger:value] forKey:@"sortIndex"];
    [self didChangeValueForKey:@"sortIndex"];
    self->cachedSortIndex = value;
  }//end if (value != [self sortIndex])
}
//end setSortIndex:

-(NSString*) comment
{
  NSString* result = nil;
  [self willAccessValueForKey:@"comment"];
  result = [self primitiveValueForKey:@"comment"];
  [self didAccessValueForKey:@"comment"];
  return result;
}
//end comment

-(void) setComment:(NSString*)value
{
  NSString* oldComment = [self comment];
  if ((value != oldComment) && ![value isEqualToString:oldComment])
  {
    [self willChangeValueForKey:@"comment"];
    [self setPrimitiveValue:value forKey:@"comment"];
    [self didChangeValueForKey:@"comment"];
  }//end if ((value != oldComment) && ![value isEqualToString:oldComment])
}
//end setComment:

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
    result = [NSMutableArray arrayWithArray:[theParent childrenOrdered:nil]];
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

-(NSArray*) titlePath
{
  NSArray* result = nil;
  NSString* titleClone = [[[self title] copy] autorelease];
  if (!titleClone)
    result = [NSArray array];
  else if (![self parent])
    result = [NSArray arrayWithObject:titleClone];
  else
  {
    NSMutableArray* array = [NSMutableArray arrayWithArray:[[self parent] titlePath]];
    [array addObject:titleClone];
    result = [[array copy] autorelease];
  }
  return result;
}
//end titlePath

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
  [self setSortIndex:[[[coder decodeObjectForKey:@"sortIndex"] dynamicCastToClass:[NSNumber class]] unsignedIntegerValue]];
  [self setComment:[coder decodeObjectForKey:@"comment"]];  
  return self;
}
//end initWithCoder:

-(void) encodeWithCoder:(NSCoder*)coder
{
  NSString* applicationVersion = [[NSWorkspace sharedWorkspace] applicationVersion];
  [coder encodeObject:applicationVersion forKey:@"version"];
  [coder encodeObject:[self title] forKey:@"title"];
  [coder encodeObject:[NSNumber numberWithUnsignedInteger:[self sortIndex]] forKey:@"sortIndex"];
  [coder encodeObject:[self comment] forKey:@"comment"];
}
//end encodeWithCoder:

-(id) plistDescription
{
  NSString* applicationVersion = [[NSWorkspace sharedWorkspace] applicationVersion];
  NSMutableDictionary* plist = [NSMutableDictionary dictionaryWithObjectsAndKeys:
     applicationVersion, @"version",
     [self title], @"title",
     [NSNumber numberWithUnsignedInteger:[self sortIndex]], @"sortIndex",
     [self comment], @"comment",
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
  [self setSortIndex:[[description objectForKey:@"sortIndex"] unsignedIntegerValue]];
  [self setComment:[description objectForKey:@"comment"]];
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
