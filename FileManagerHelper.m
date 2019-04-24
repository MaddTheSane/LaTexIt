//
//  FileManagerHelper.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/2019.
//
//

#import "FileManagerHelper.h"

#import "NSFileManagerExtended.h"
#import "NSObjectExtended.h"
#import "Semaphore.h"
#import "Utils.h"

@interface FileManagerHelper (PrivateAPI)
-(void) wakeUpDestructionThread;
-(void) wakeUpDestructionThread:(NSNumber*)delay;
@end

@implementation FileManagerHelper

+(id) defaultManager
{
  static FileManagerHelper* instance = nil;
  if (!instance)
  {
    @synchronized([self class])
    {
      if (!instance)
        instance = [[FileManagerHelper alloc] init];
    }//end @synchronized([self class])
  }//end if (!instance)
  return instance;
}
//end defaultManager

-(id) init
{
  if (!((self = [super init])))
    return nil;
  self->destructionQueue = [[NSMutableArray alloc] init];
  self->semaphore = [[Semaphore alloc] init];
  self->threadsShouldRun = YES;
  return self;
}
//end init

-(void) dealloc
{
  self->threadsShouldRun = NO;
  [self wakeUpDestructionThread];
  while(self->destructionThread && ![self->destructionThread isFinished])
    [NSThread sleepForTimeInterval:.1];
  [self->destructionThread release];
  [self->semaphore release];
  [self->destructionQueue release];
  [super dealloc];
}
//end dealloc

-(void) wakeUpDestructionThread
{
  [self->semaphore V];
}
//end wakeUpDestructionThread

-(void) wakeUpDestructionThread:(NSNumber*)delay
{
  [self performSelector:@selector(wakeUpDestructionThread) withObject:nil afterDelay:[delay doubleValue]];
}
//end wakeUpDestructionThread

-(void) addSelfDestructingFile:(NSString*)path timeInterval:(double)timeInterval
{
  [self addSelfDestructingFile:path dueDate:[[NSDate date] dateByAddingTimeInterval:timeInterval]];
}
//end addSelfDestructingFile:

-(void) addSelfDestructingFile:(NSString*)path dueDate:(NSDate*)dueDate
{
  NSDictionary* item = !path || !dueDate ? nil :
    [NSDictionary dictionaryWithObjectsAndKeys:path, @"path", dueDate, @"dueDate", nil];
  [self addSelfDestructingItem:item wakeUp:YES];
}
//end addSelfDestructingFile:dueDate:

-(void) addSelfDestructingItem:(NSDictionary*)item wakeUp:(BOOL)wakeUp
{
  if (item)
  {
    @synchronized(self->destructionQueue)
    {
      if (item)
        [self->destructionQueue addObject:item];
      [self->destructionQueue sortUsingDescriptors:[NSArray arrayWithObjects:
        [[[NSSortDescriptor alloc] initWithKey:@"dueDate" ascending:YES] autorelease], nil]];
    }//end @synchronized(self->destructionQueue)
    [self startDestructionThreadIfNeeded];
    if (wakeUp)
      [self wakeUpDestructionThread];
  }//end if (item)
}
//end addSelfDestructingItem:

-(void) startDestructionThreadIfNeeded
{
  @synchronized(self)
  {
    if (!self->destructionThread)
    {
      self->destructionThread = [[NSThread alloc] initWithTarget:self selector:@selector(destructingThreadFunction:) object:nil];
      [self->destructionThread start];
    }//end if (!self->destructionThread)
  }//end @synchronized(self)
}
//end startDestructionThreadIfNeeded

-(void) destructingThreadFunction:(id)context
{
  BOOL stop = NO;
  while(!stop)
  {
    NSAutoreleasePool* ap = [[NSAutoreleasePool alloc] init];
    [self->semaphore P];
    stop |= !self->threadsShouldRun;
    if (!stop)
    {
      id firstItem = nil;
      @synchronized(self->destructionQueue)
      {
        if ([self->destructionQueue count] > 0)
        {
          firstItem = [[self->destructionQueue objectAtIndex:0] retain];
          [self->destructionQueue removeObjectAtIndex:0];
        }//end if ([self->destructionQueue count] > 0)
      }//end @synchronized(self->destructionQueue)
      if (firstItem)
      {
        NSDate* destructionDate = [[firstItem dynamicCastToClass:[NSDictionary class]] objectForKey:@"dueDate"];
        NSString* path = [[firstItem dynamicCastToClass:[NSDictionary class]] objectForKey:@"path"];
        NSTimeInterval remainingTime = [destructionDate timeIntervalSinceNow];
        if (remainingTime <= 0)
        {
          NSFileManager* fileManager = [NSFileManager defaultManager];
          [fileManager unregisterTemporaryPath:path];
          NSError* error = nil;
          [fileManager removeItemAtPath:path error:&error];
          if (error)
            DebugLog(0, @"removeItemAtPath:%@ : error :%@", path, error);
          [self->semaphore V];//will check next item
        }//end if (remainingTime <= 0)
        else//if (remainingTime > 0)
        {
          [self addSelfDestructingItem:firstItem wakeUp:NO];
          [self performSelectorOnMainThread:@selector(wakeUpDestructionThread:) withObject:[NSNumber numberWithDouble:remainingTime] waitUntilDone:NO];
        }//end if (remainingTime > 0)
        [firstItem release];
      }//end if (firstItem)
    }//end if (!stop)
    stop |= !self->threadsShouldRun;
    [ap release];
  }//end while(!stop)
}
//end destructingThreadFunction:


@end
