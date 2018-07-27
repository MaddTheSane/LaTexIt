//
//  HistoryItemCD.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/02/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LatexitEquation;

@interface HistoryItem : NSManagedObject <NSCoding> {
  //LatexitEquation* equation;
  BOOL kvoEnabled;
}

+(NSEntityDescription*) entity;
+(NSEntityDescription*) wrapperEntity;

-(id) initWithEquation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;
-(void) dispose;

-(BOOL) dummyPropertyToForceUIRefresh;

-(LatexitEquation*) equation;
-(void) setEquation:(LatexitEquation*)equation;

-(void) writeToPasteboard:(NSPasteboard *)pboard isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider;

//for readable export
-(id) plistDescription;
+(HistoryItem*) historyItemWithDescription:(id)description;
-(id) initWithDescription:(id)description;

@end
