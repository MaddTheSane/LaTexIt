//
//  CHExportPrefetcher.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 30/05/14.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "CHExportPrefetcher.h"

#import "LaTeXProcessor.h"
#import "NSObjectExtended.h"
#import "PreferencesController.h"
#import "Semaphore.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@interface CHExportPrefetcher(PrivateAPI)
-(void) _fetchForFormat:(id)object;
@end

@implementation CHExportPrefetcher

-(instancetype) init
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
}
//end dealloc

-(void) prefetchForFormat:(export_format_t)exportFormat pdfData:(NSData*)pdfData
{
  [self->fetchSemaphore P];
  @synchronized(self->cache)
  {
    [self->cache setObject:self->isFetchingData forKey:[NSNumber numberWithInteger:exportFormat]];
  }//end @synchronized(self->cache)
  #ifdef ARC_ENABLED
  [NSApplication detachDrawingThread:@selector(_fetchForFormat:) toTarget:self withObject:
     [NSDictionary dictionaryWithObjectsAndKeys:
       [NSNumber numberWithInteger:exportFormat], @"exportFormat",
       [pdfData copy], @"pdfData",
       [NSMutableDictionary dictionary], @"alertInformationWrapper",
       nil]];
  #else
  [NSApplication detachDrawingThread:@selector(_fetchForFormat:) toTarget:self withObject:
     [NSDictionary dictionaryWithObjectsAndKeys:
       [NSNumber numberWithInteger:exportFormat], @"exportFormat",
       [[pdfData copy] autorelease], @"pdfData",
       [NSMutableDictionary dictionary], @"alertInformationWrapper",
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
    data = [self->cache objectForKey:[NSNumber numberWithInteger:exportFormat]];
  }//end @synchronized(self->cache)
  if (data != self->isFetchingData)
    result = data;
  else if (wait)
  {
    [self->fetchSemaphore P];
    @synchronized(self->cache)
    {
      data = [self->cache objectForKey:[NSNumber numberWithInteger:exportFormat]];
    }//end @synchronized(self->cache)
    [self->fetchSemaphore V];
    result = data;
  }//end if (wait)
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
    [self->cache removeObjectForKey:[NSNumber numberWithInteger:exportFormat]];
  }//end @synchronized(self->cache)
  [self->fetchSemaphore V];
}
//end invalidateDataForFormat:

-(void) _fetchForFormat:(id)object
{
  NSDictionary* configuration = [object dynamicCastToClass:[NSDictionary class]]; 
  NSNumber* exportFormatNumber = [[configuration objectForKey:@"exportFormat"] dynamicCastToClass:[NSNumber class]];
  NSData* pdfData = [[configuration objectForKey:@"pdfData"] dynamicCastToClass:[NSData class]];
  export_format_t exportFormat = (export_format_t)[exportFormatNumber integerValue];
  PreferencesController* preferencesController = [PreferencesController sharedController];
  NSMutableDictionary* alertInformationWrapper =
    [configuration[@"alertInformationWrapper"] dynamicCastToClass:[NSMutableDictionary class]];
  NSMutableDictionary* exportOptions =
    [NSMutableDictionary dictionaryWithObjectsAndKeys:
       @(preferencesController.exportJpegQualityPercent), @"jpegQuality",
       @(preferencesController.exportScalePercent), @"scaleAsPercent",
       @(preferencesController.exportIncludeBackgroundColor),@"exportIncludeBackgroundColor",
       @(preferencesController.exportTextExportPreamble), @"textExportPreamble",
       @(preferencesController.exportTextExportEnvironment), @"textExportEnvironment",
       @(preferencesController.exportTextExportBody), @"textExportBody",
       nil];
  if (preferencesController.exportJpegBackgroundColor)
    exportOptions[@"jpegColor"] = preferencesController.exportJpegBackgroundColor;
  if (preferencesController.exportJpegBackgroundColor)
    exportOptions[@"alertInformationWrapper"] = alertInformationWrapper;

  NSData* data = !pdfData ? nil : [[LaTeXProcessor sharedLaTeXProcessor]
    dataForType:exportFormat pdfData:pdfData
    exportOptions:exportOptions
    compositionConfiguration:preferencesController.compositionConfigurationDocument
    uniqueIdentifier:[NSString stringWithFormat:@"%p", self]];
  @synchronized(self->cache)
  {
    if (!data)
      [self->cache removeObjectForKey:exportFormatNumber];
    else
      self->cache[exportFormatNumber] = data;
  }//end @synchronized(self->cache)
  [self->fetchSemaphore V];
  NSDictionary* alertInformation =
    [alertInformationWrapper[@"alertInformation"] dynamicCastToClass:[NSDictionary class]];
  if (alertInformation)
    [[LaTeXProcessor sharedLaTeXProcessor] performSelectorOnMainThread:@selector(displayAlertError:)
                                                            withObject:alertInformation
                                                         waitUntilDone:YES];
}
//end _fetchForFormat:

@end
