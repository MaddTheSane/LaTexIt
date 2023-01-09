//
//  FileManagerHelper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/2019.
//
//

#import <Foundation/Foundation.h>

@class Semaphore;

@interface FileManagerHelper : NSObject {
  NSMutableArray* destructionQueue;
  Semaphore* semaphore;
  NSThread* destructionThread;
  volatile BOOL threadsShouldRun;
}

+(FileManagerHelper*) defaultManager;
@property (class, readonly, retain) FileManagerHelper *defaultManager;

-(void) addSelfDestructingFile:(NSString*)path timeInterval:(NSTimeInterval)timeInterval;
-(void) addSelfDestructingFile:(NSString*)path dueDate:(NSDate*)dueDate;

@end
