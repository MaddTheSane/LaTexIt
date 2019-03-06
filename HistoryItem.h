//
//  HistoryItemCD.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/02/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
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

-(instancetype) initWithEquation:(LatexitEquation*)equation insertIntoManagedObjectContext:(NSManagedObjectContext*)managedObjectContext;

-(void) dispose;
@property BOOL customKVOEnabled;
@property BOOL customKVOInhibited;

@property (readonly) BOOL dummyPropertyToForceUIRefresh;

@property (copy) LatexitEquation *equation;
@property (copy) NSDate *date;

-(void) writeToPasteboard:(NSPasteboard *)pboard exportFormat:(export_format_t)exportFormat isLinkBackRefresh:(BOOL)isLinkBackRefresh lazyDataProvider:(id)lazyDataProvider;

//for readable export
@property (readonly, strong) id plistDescription;
+(instancetype) historyItemWithDescription:(id)description;
-(instancetype) initWithDescription:(id)description;

@end
