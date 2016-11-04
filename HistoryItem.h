//
//  HistoryItemCD.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/02/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class LatexitEquation;

@interface HistoryItem : NSManagedObject <NSCoding> {
  //LatexitEquation* equation;
  BOOL customKVOEnabled;
  BOOL customKVOInhibited;
  BOOL isModelPrior250;
}

+(NSEntityDescription*) entity;
+(NSEntityDescription*) wrapperEntity;

-(id) initWithEquation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;

-(void) dispose;
@property BOOL customKVOEnabled;
@property BOOL customKVOInhibited;

-(BOOL) dummyPropertyToForceUIRefresh;

-(LatexitEquation*) equation;
-(void) setEquation:(LatexitEquation*)equation;
-(NSDate*) date;
-(void) setDate:(NSDate*)value;

-(void) writeToPasteboard:(NSPasteboard *)pboard exportFormat:(export_format_t)exportFormat isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider;

//for readable export
-(id) plistDescription;
+(HistoryItem*) historyItemWithDescription:(id)description;
-(id) initWithDescription:(id)description;

@end
