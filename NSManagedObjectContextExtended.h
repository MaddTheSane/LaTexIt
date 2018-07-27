//
//  NSManagedObjectContextExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/07/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSManagedObjectContext (Extended)

-(void) disableUndoRegistration;
-(void) enableUndoRegistration;
-(void) safeInsertObject:(NSManagedObject*)object;
-(void) safeInsertObjects:(NSArray*)objects;
-(void) safeDeleteObject:(NSManagedObject*)object;
-(void) safeDeleteObjects:(NSArray*)objects;
-(unsigned int) countForEntity:(NSEntityDescription*)entity error:(NSError**)error predicateFormat:(NSString*)predicateFormat,...;
-(NSManagedObject*) managedObjectForURIRepresentation:(NSURL*)url;
-(unsigned int) myCountForFetchRequest:(NSFetchRequest *)request error:(NSError **)error;

@end

@interface NSObject (NSManagedObjectContextExtendedAvoidWarning)
-(unsigned int) countForFetchRequest:(NSFetchRequest *)request error:(NSError **)error;
@end

