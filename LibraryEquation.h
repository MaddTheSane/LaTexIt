//
//  LibraryEquation.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/09.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LibraryItem.h"

@class LatexitEquation;
@class LibraryGroupItem;

@interface LibraryEquation : LibraryItem <NSCopying, NSCoding, NSSecureCoding>
{
  BOOL customKVOEnabled;
  BOOL customKVOInhibited;
}

+(NSEntityDescription*) entity;
+(NSEntityDescription*) wrapperEntity;

-(id) initWithParent:(LibraryItem*)parent equation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;

-(void) dispose;
-(BOOL) customKVOEnabled;
-(void) setCustomKVOEnabled:(BOOL)value;
-(BOOL) customKVOInhibited;
-(void) setCustomKVOInhibited:(BOOL)value;

-(void) setTitle:(NSString*)value;//redefined to set title of equation with the same value

-(LatexitEquation*) equation;
-(void) setEquation:(LatexitEquation*)equation;

-(id) plistDescription;

@end
