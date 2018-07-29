//
//  NSManagedObjectExtended.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/07/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "NSManagedObjectContextExtended.h"

#import "Utils.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation NSManagedObjectContext (Extended)

-(void) disableUndoRegistration
{
  [self processPendingChanges];
  [self.undoManager disableUndoRegistration];
}
//end disableUndoRegistration

-(void) enableUndoRegistration
{
  [self processPendingChanges];
  [self.undoManager enableUndoRegistration];
}
//end enableUndoRegistration

-(void) safeInsertObject:(NSManagedObject*)object
{
  if (object && (object.managedObjectContext != self))
    [self insertObject:object];
}
//end safeInsertObject:

-(void) safeInsertObjects:(NSArray*)objects
{
  for(NSManagedObject* object in objects)
    [self safeInsertObject:object];
}
//end safeInsertObjects:

-(void) safeDeleteObject:(NSManagedObject*)object
{
  if (object.managedObjectContext == self)
    [self deleteObject:object];
}
//end safeDeleteObject:

-(void) safeDeleteObjects:(NSArray*)objects
{
  for(NSManagedObject* object in objects)
    [self safeDeleteObject:object];
}
//end safeDeleteObjects:

-(NSUInteger) countForEntity:(NSEntityDescription*)entity error:(NSError**)error predicateFormat:(NSString*)predicateFormat,...
{
  NSUInteger result = 0;
  NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
  fetchRequest.entity = entity;
  if (predicateFormat)
  {
    va_list va;
    va_start(va, predicateFormat);
    NSPredicate* predicate = [NSPredicate predicateWithFormat:predicateFormat arguments:va];
    va_end(va);
    fetchRequest.predicate = predicate;
  }

  result = [super countForFetchRequest:fetchRequest error:error];
  return result;
}
//end countForEntity:predicate:error:

-(NSUInteger) myCountForFetchRequest:(NSFetchRequest *)request error:(NSError **)error
{
  NSUInteger result = 0;
  result = [self countForFetchRequest:request error:error];
  return result;
}
//end myCountForFetchRequest:error:

-(NSManagedObject*) managedObjectForURIRepresentation:(NSURL*)url
{
  NSManagedObject* result = nil;
  NSManagedObjectID* managedObjectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:url];
  result = [self objectWithID:managedObjectID];
  return result;
}
//end managedObjectForURIRepresentation:

@end
