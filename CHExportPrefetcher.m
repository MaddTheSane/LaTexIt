//
//  CHExportPrefetcher.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 30/05/14.
//  Copyright 2005-2015 Pierre Chatelier. All rights reserved.
//

#import "CHExportPrefetcher.h"

#import "LaTeXProcessor.h"
#import "NSObjectExtended.h"
#import "PreferencesController.h"
#import "Semaphore.h"

@interface CHExportPrefetcher(PrivateAPI)
-(void) _fetchForFormat:(id)object;
@end

@implementation CHExportPrefetcher

-(id) init
{
  if (!((self = [super init])))
    return nil;
  self->cache = [[NSMutableDictionary alloc] init];
  self->fetchSemaphore = [[Semaphore alloc] initWithValue:1];
  self->isFetchingData = [[NSData alloc] init];
  return self;
}
//end init

-(void) dealloc
{
  [self invalidateAllData];
  #ifdef ARC_ENABLED
  #else
  [self->cache release];
  [self->fetchSemaphore release];
  [self->isFetchingData release];
  [super dealloc];
  #endif
}
//end dealloc

-(void) prefetchForFormat:(export_format_t)exportFormat pdfData:(NSData*)pdfData
{
  [self->fetchSemaphore P];
  @synchronized(self->cache)
  {
    [self->cache setObject:self->isFetchingData forKey:[NSNumber numberWithInt:exportFormat]];
  }//end @synchronized(self->cache)
  #ifdef ARC_ENABLED
  [NSApplication detachDrawingThread:@selector(_fetchForFormat:) toTarget:self withObject:
     [NSDictionary dictionaryWithObjectsAndKeys:
       [NSNumber numberWithInt:exportFormat], @"exportFormat",
       [pdfData copy], @"pdfData",
       nil]];
  #else
  [NSApplication detachDrawingThread:@selector(_fetchForFormat:) toTarget:self withObject:
     [NSDictionary dictionaryWithObjectsAndKeys:
       [NSNumber numberWithInt:exportFormat], @"exportFormat",
       [[pdfData copy] autorelease], @"pdfData",
       nil]];
  #endif
}
//end prefetchForFormat:

-(NSData*) fetchDataForFormat:(export_format_t)exportFormat wait:(BOOL)wait
{
  NSData* result = nil;
  NSData* data = nil;
  @synchronized(self->cache)
  {
    data = [self->cache objectForKey:[NSNumber numberWithInt:exportFormat]];
  }//end @synchronized(self->cache)
  if (data != self->isFetchingData)
    result = data;
  else//if (data == self->isFetchingData)
  {
    [self->fetchSemaphore P];
    @synchronized(self->cache)
    {
      data = [self->cache objectForKey:[NSNumber numberWithInt:exportFormat]];
    }//end @synchronized(self->cache)
    [self->fetchSemaphore V];
    result = data;
  }//end if (data == self->isFetchingData)
  return result;
}
//end fetchDataForFormat:

-(void) invalidateAllData
{
  [self->fetchSemaphore P];
  @synchronized(self->cache)
  {
    [self->cache removeAllObjects];
  }//end @synchronized(self->cache)
  [self->fetchSemaphore V];
}
//end invalidateAllData

-(void) invalidateDataForFormat:(export_format_t)exportFormat
{
  [self->fetchSemaphore P];
  @synchronized(self->cache)
  {
    [self->cache removeObjectForKey:[NSNumber numberWithInt:exportFormat]];
  }//end @synchronized(self->cache)
  [self->fetchSemaphore V];
}
//end invalidateDataForFormat:

-(void) _fetchForFormat:(id)object
{
  NSDictionary* configuration = [object dynamicCastToClass:[NSDictionary class]]; 
  NSNumber* exportFormatNumber = [[configuration objectForKey:@"exportFormat"] dynamicCastToClass:[NSNumber class]];
  NSData* pdfData = [[configuration objectForKey:@"pdfData"] dynamicCastToClass:[NSData class]];
  export_format_t exportFormat = (export_format_t)[exportFormatNumber intValue];
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSDictionary* exportOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithFloat:[preferencesController exportJpegQualityPercent]], @"jpegQuality",
                                 [NSNumber numberWithFloat:[preferencesController exportScalePercent]], @"scaleAsPercent",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportPreamble]], @"textExportPreamble",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportEnvironment]], @"textExportEnvironment",
                                 [NSNumber numberWithBool:[preferencesController exportTextExportBody]], @"textExportBody",
                                 [preferencesController exportJpegBackgroundColor], @"jpegColor",//at the end for the case it is null
                                 nil];
  NSData* data = !pdfData ? nil : [[LaTeXProcessor sharedLaTeXProcessor]
    dataForType:exportFormat pdfData:pdfData
    exportOptions:exportOptions
    compositionConfiguration:[preferencesController compositionConfigurationDocument]
    uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  @synchronized(self->cache)
  {
    if (!data)
      [self->cache removeObjectForKey:exportFormatNumber];
    else
      [self->cache setObject:data forKey:exportFormatNumber];
  }//end @synchronized(self->cache)
  [self->fetchSemaphore V];
}
//end _fetchForFormat:

@end
