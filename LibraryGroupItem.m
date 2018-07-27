//  LibraryGroupItem.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 1/05/05.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.

//The LibraryGroupItem is a libraryItem (that can appear in the library outlineview)
//But it represents a "folder", that is to say a parent for other library items
//It contains nothing more than a LibraryItem, which is already similar to an XMLNode

#import "LibraryGroupItem.h"

#import "LaTeXProcessor.h"
#import "LibraryManager.h"

#import "Utils.h"

@interface LibraryGroupItem (PrivateAPI)
-(NSArray*) childrenSortDescriptors;
@end

@implementation LibraryGroupItem

static NSEntityDescription* cachedEntity = nil;

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
  if (!((self = [super initWithParent:aParent insertIntoManagedObjectContext:managedObjectContext])))
    return nil;
  return self;
}
//end initWithEquation:insertIntoManagedObjectContext:

-(void) dealloc
{
  [self->childrenSortDescriptors release];
  [super dealloc];
}
//end dealloc

-(id) copyWithZone:(NSZone*)zone
{
  id clone = [super copyWithZone:zone];
  [clone setExpanded:[self isExpanded]];
  NSSet* theChildren = [self children];
  NSMutableSet* clonedChildren = [[NSMutableSet alloc] initWithCapacity:[theChildren count]];
  NSEnumerator* enumerator = [theChildren objectEnumerator];
  LibraryItem* child = nil;
  while((child = [enumerator nextObject]))
  {
    LibraryItem* clonedChild = [child copyWithZone:zone];
    if (clonedChild)
      [clonedChildren addObject:clonedChild];
    [clonedChild release];
  }
  [self setValue:clonedChildren forKey:@"children"];
  [clonedChildren release]; 
  return clone;
}
//end copyWithZone:

-(BOOL) isExpanded
{
  BOOL result = NO;
  [self willAccessValueForKey:@"expanded"];
  result = [[self primitiveValueForKey:@"expanded"] boolValue];
  [self didAccessValueForKey:@"expanded"];
  return result;
}
//end isExpanded

-(void) setExpanded:(BOOL)value
{
  [self willChangeValueForKey:@"expanded"];
  [self setPrimitiveValue:[NSNumber numberWithBool:value] forKey:@"expanded"];
  [self didChangeValueForKey:@"expanded"];
}
//end setExpanded:

-(NSSet*) children
{
  NSSet* result = nil; //on Tiger, calling the primitiveKey does not work
  NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
  [fetchRequest setEntity:[LibraryItem entity]];
  [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"parent == %@", self]];
  NSError* error = nil;
  result = [NSSet setWithArray:[[self managedObjectContext] executeFetchRequest:fetchRequest error:&error]];
  if (error)
    {DebugLog(0, @"error = %@", error);}
  [fetchRequest release];
  return result;
/*  [self willAccessValueForKey:@"children"];
  result = [self primitiveValueForKey:@"children"];
  [self didAccessValueForKey:@"children"];*/
  return result;
}
//end children

-(NSArray*) childrenSortDescriptors
{
  if (!self->childrenSortDescriptors)
  {
    @synchronized(self)
    {
      if (!self->childrenSortDescriptors)
        self->childrenSortDescriptors = [[NSArray alloc] initWithObjects:
          [[[NSSortDescriptor alloc] initWithKey:@"sortIndex" ascending:YES] autorelease], nil];
    }//end @synchronized(self)
  }//end if (!self->childrenSortDescriptor)
  return self->childrenSortDescriptors;
}
//end childrenSortDescriptors

-(NSArray*) childrenOrdered
{
  NSMutableArray* result = nil;
  NSSet* theChildren = [self children];
  result = !theChildren ? [NSMutableArray array] : [NSMutableArray arrayWithArray:[theChildren allObjects]];
  [result sortUsingDescriptors:[self childrenSortDescriptors]];
  return result;
}
//end childrenOrdered:

-(void) fixChildrenSortIndexesRecursively:(BOOL)recursively
{
  NSArray* theChildren = [self childrenOrdered];
  unsigned int n = [theChildren count];
  unsigned int i = 0;
  for(i = 0 ; i<n ; ++i)
  {
    LibraryItem* libraryItem = [theChildren objectAtIndex:i];
    [libraryItem setSortIndex:i];
    if (recursively && [libraryItem isKindOfClass:[LibraryGroupItem class]])
      [(LibraryGroupItem*)libraryItem fixChildrenSortIndexesRecursively:recursively];
  }//end for each child
}
//end fixChildrenSortIndexesRecursively:

-(void) encodeWithCoder:(NSCoder*)coder
{
  [super encodeWithCoder:coder];
  [coder encodeBool:[self isExpanded] forKey:@"expanded"];
  [coder encodeObject:[self children] forKey:@"children"];
}
//end encodeWithCoder:

-(id) initWithCoder:(NSCoder*)coder
{
  if (!((self = [super initWithCoder:coder])))
    return nil;
  if ([coder containsValueForKey:@"isExpanded"])//legacy
    [self setExpanded:[coder decodeBoolForKey:@"isExpanded"]];  
  else
    [self setExpanded:[coder decodeBoolForKey:@"expanded"]];
  NSArray* theChildren = [coder decodeObjectForKey:@"children"];
  [theChildren makeObjectsPerformSelector:@selector(setParent:) withObject:self];
  return self;
}
//end initWithCoder:

-(void) dispose
{
  [[self children] makeObjectsPerformSelector:@selector(dispose)];
}
//end dispose

//for readable export
-(id) plistDescription
{
  NSArray* theChildren = [self childrenOrdered];
  NSMutableArray* childrenPlistDescription = [[NSMutableArray alloc] initWithCapacity:[theChildren count]];
  NSEnumerator* enumerator = [theChildren objectEnumerator];
  LibraryItem* child = nil;
  while((child = [enumerator nextObject]))
    [childrenPlistDescription addObject:[child plistDescription]];
  NSMutableDictionary* plist = [super plistDescription];
    [plist addEntriesFromDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
       [NSNumber numberWithBool:[self isExpanded]], @"expanded",
       childrenPlistDescription, @"children",
       nil]];
  [childrenPlistDescription release];
  return plist;
}
//end plistDescription

-(id) initWithDescription:(id)description
{
  if (!((self = [super initWithDescription:description])))
    return nil;
  NSString* version = [description objectForKey:@"version"];
  BOOL isOldLibraryItem = ([version compare:@"2.0.0" options:NSNumericSearch] == NSOrderedAscending);
  [self setExpanded:[[description objectForKey:@"expanded"] boolValue]];
  NSArray* childrenDescriptions = isOldLibraryItem ? [description objectForKey:@"content"] : [description objectForKey:@"children"];
  NSMutableArray* theChildren = [NSMutableArray arrayWithCapacity:[childrenDescriptions count]];
  unsigned int count = [childrenDescriptions count];
  unsigned int i = 0;
  unsigned int index = 0;
  for(i = 0 ; i<count ; ++i)
  {
    id childDescription = [childrenDescriptions objectAtIndex:i];
    LibraryItem* child = [LibraryItem libraryItemWithDescription:childDescription];
    if (child)
    {
      [theChildren addObject:child];
      if (isOldLibraryItem)
        [child setSortIndex:index++];
    }//end if (child)
  }//end for each childDescription
  [theChildren makeObjectsPerformSelector:@selector(setParent:) withObject:self];
  return self;
}
//end initWithDescription:

@end
