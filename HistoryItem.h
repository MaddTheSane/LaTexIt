//
//  HistoryItemCD.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/02/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LatexitEquation;

@interface HistoryItem : NSManagedObject <NSCoding> {
  //LatexitEquation* equation;
}

+(NSEntityDescription*) entity;
+(NSEntityDescription*) wrapperEntity;

-(id) initWithEquation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;

-(BOOL) dummyPropertyToForceUIRefresh;

-(LatexitEquation*) equation;
-(void) setEquation:(LatexitEquation*)equation;

-(void) writeToPasteboard:(NSPasteboard *)pboard isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider;

@end
