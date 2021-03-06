//
//  NSManagedObjectContextExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/07/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSManagedObjectContext (Extended)

-(void) disableUndoRegistration;
-(void) enableUndoRegistration;
-(void) safeInsertObject:(NSManagedObject*)object;
-(void) safeInsertObjects:(NSArray<NSManagedObject*>*)objects;
-(void) safeDeleteObject:(NSManagedObject*)object;
-(void) safeDeleteObjects:(NSArray<NSManagedObject*>*)objects;
-(NSUInteger) countForEntity:(NSEntityDescription*)entity error:(NSError**)error predicateFormat:(NSString*)predicateFormat,...;
-(NSManagedObject*) managedObjectForURIRepresentation:(NSURL*)url;
-(NSUInteger) myCountForFetchRequest:(NSFetchRequest *)request error:(NSError **)error;

@end

@interface NSObject (NSManagedObjectContextExtendedAvoidWarning)
-(NSUInteger) countForFetchRequest:(NSFetchRequest *)request error:(NSError **)error;
@end

