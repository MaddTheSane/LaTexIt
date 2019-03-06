//
//  CHExportPrefetcher.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 30/05/14.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LaTeXiTSharedTypes.h"

@class Semaphore;

@interface CHExportPrefetcher : NSObject {
  NSMutableDictionary* cache;
  Semaphore* fetchSemaphore;
  NSData* isFetchingData;
}

-(void)    prefetchForFormat:(export_format_t)exportFormat pdfData:(NSData*)pdfData;
-(NSData*) fetchDataForFormat:(export_format_t)exportFormat wait:(BOOL)wait;
-(void)    invalidateAllData;
-(void)    invalidateDataForFormat:(export_format_t)exportFormat;

@end
