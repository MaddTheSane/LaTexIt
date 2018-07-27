//
//  SystemTask.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SystemTask : NSTask {
  NSTimeInterval timeOutLimit;
  NSString*     tmpStdinFilePath;
  NSString*     tmpStdoutFilePath;
  NSString*     tmpStderrFilePath;
  NSString*     tmpScriptFilePath;
  NSFileHandle* tmpStdinFileHandle;
  NSFileHandle* tmpStdoutFileHandle;
  NSFileHandle* tmpStderrFileHandle;
  NSFileHandle* tmpScriptFileHandle;
  NSData*       stdInputData;
  NSDictionary* environment;
  NSString*     launchPath;
  NSArray*      arguments;
  BOOL          isUsingLoginShell;
  NSString*     currentDirectoryPath;
  NSLock*       runningLock;
  int           terminationStatus;
  BOOL          selfExited;
  NSString*     workingDirectory;
}

-(id)   init;//NSTemporaryDirectory() as workingDirectory
-(id)   initWithWorkingDirectory:(NSString*)workingDirectory;
-(void) setEnvironment:(NSDictionary*)environment;
-(void) setLaunchPath:(NSString*)launchPath;
-(void) setArguments:(NSArray*)arguments;
-(void) setCurrentDirectoryPath:(NSString*)currentDirectoryPath;
-(NSDictionary*) environment;
-(NSString*)     launchPath;
-(NSArray*)      arguments;
-(NSString*)     currentDirectoryPath;
-(BOOL) isUsingLoginShell;
-(void) setUsingLoginShell:(BOOL)value;

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
