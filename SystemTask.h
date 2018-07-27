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
  NSString*     tmpStdoutFilePath;
  NSString*     tmpStderrFilePath;
  NSFileHandle* tmpStdoutFileHandle;
  NSFileHandle* tmpStderrFileHandle;
  NSDictionary* environment;
  NSString*     launchPath;
  NSArray*      arguments;
  NSString*     currentDirectoryPath;
  id            standardInput;
  id            standardOutput;
  id            standardError;
  NSLock*       runningLock;
  int           terminationStatus;
  BOOL          selfExited;
}

-(void) setEnvironment:(NSDictionary*)environment;
-(void) setLaunchPath:(NSString*)launchPath;
-(void) setArguments:(NSArray*)arguments;
-(void) setCurrentDirectoryPath:(NSString*)currentDirectoryPath;
-(void) setStandardInput:(id)standardInput;
-(void) setStandardOutput:(id)standardOutput;
-(void) setStandardError:(id)standardError;
-(void) setTimeOut:(NSTimeInterval)timeOut;
-(NSString*) equivalentLaunchCommand;
-(void) launch;
-(void) waitUntilExit;
-(int) terminationStatus;
-(BOOL) hasReachedTimeout;

@end
