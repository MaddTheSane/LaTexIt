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

+(id) defaultManager;

-(void) addSelfDestructingFile:(NSString*)path timeInterval:(double)timeInterval;
-(void) addSelfDestructingFile:(NSString*)path dueDate:(NSDate*)dueDate;

@end
