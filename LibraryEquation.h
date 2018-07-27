//
//  LibraryEquation.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 16/03/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LibraryItem.h"

@class LatexitEquation;
@class LibraryGroupItem;

@interface LibraryEquation : LibraryItem <NSCopying, NSCoding>
{
}

+(NSEntityDescription*) entity;
+(NSEntityDescription*) wrapperEntity;

-(id) initWithParent:(LibraryItem*)parent equation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;

-(void) setTitle:(NSString*)value;//redefined to set title of equation with the same value

-(LatexitEquation*) equation;
-(void) setEquation:(LatexitEquation*)equation;

-(id) plistDescription;

@end
