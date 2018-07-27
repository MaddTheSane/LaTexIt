//
//  SystemTask.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SystemTask : NSTask {
  NSTimeInterval timeOutLimit;
  NSString*     tmpStdinFilePath;
  NSString*     tmpStdoutFilePath;
  NSString*     tmpStderrFilePath;
  NSFileHandle* tmpStdinFileHandle;
  NSFileHandle* tmpStdoutFileHandle;
  NSFileHandle* tmpStderrFileHandle;
  NSData*       stdInputData;
  NSDictionary* environment;
  NSString*     launchPath;
  NSArray*      arguments;
  NSString*     currentDirectoryPath;
  NSLock*       runningLock;
  int           terminationStatus;
  BOOL          selfExited;
}

-(void) setEnvironment:(NSDictionary*)environment;
-(void) setLaunchPath:(NSString*)launchPath;
-(void) setArguments:(NSArray*)arguments;
-(void) setCurrentDirectoryPath:(NSString*)currentDirectoryPath;
-(NSDictionary*) environment;
-(NSString*)     launchPath;
-(NSArray*)      arguments;
-(NSString*)     currentDirectoryPath;

-(void) setTimeOut:(NSTimeInterval)timeOut;
-(NSString*) equivalentLaunchCommand;
-(void) launch;
-(void) waitUntilExit;
-(int) terminationStatus;
-(void) setStdInputData:(NSData*)data;
-(NSData*) dataForStdOutput;
-(NSData*) dataForStdError;
-(BOOL) hasReachedTimeout;

@end
