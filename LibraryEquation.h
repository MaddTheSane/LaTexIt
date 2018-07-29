//
//  LibraryEquation.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LibraryItem.h"

@class LatexitEquation;
@class LibraryGroupItem;

@interface LibraryEquation : LibraryItem <NSCopying, NSCoding>
{
  BOOL customKVOEnabled;
  BOOL customKVOInhibited;
}

+(NSEntityDescription*) entity;
+(NSEntityDescription*) wrapperEntity;

-(instancetype) initWithParent:(LibraryItem*)parent equation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;

-(void) dispose;
@property BOOL customKVOEnabled;
@property BOOL customKVOInhibited;

-(void) setTitle:(NSString*)value;//redefined to set title of equation with the same value

@property (strong) LatexitEquation *equation;

-(id) plistDescription;

@end
