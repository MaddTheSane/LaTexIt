//
//  LibraryEquation.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/09.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
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
@property (nonatomic) BOOL customKVOEnabled;
@property (nonatomic) BOOL customKVOInhibited;

-(void) setTitle:(NSString*)value;//redefined to set title of equation with the same value

@property (nonatomic, assign) LatexitEquation *equation;

-(id) plistDescription;

@end
