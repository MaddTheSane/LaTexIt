//
//  SystemTask.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
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

-(instancetype)   init;///<NSTemporaryDirectory() as workingDirectory
-(instancetype)   initWithWorkingDirectory:(NSString*)workingDirectory;
-(void) setEnvironment:(NSDictionary*)environment;
-(void) setLaunchPath:(NSString*)launchPath;
-(void) setArguments:(NSArray*)arguments;
-(void) setCurrentDirectoryPath:(NSString*)currentDirectoryPath;
-(NSDictionary*) environment;
-(NSString*)     launchPath;
-(NSArray*)      arguments;
-(NSString*)     currentDirectoryPath;
@property (getter=isUsingLoginShell) BOOL usingLoginShell;

-(void) setTimeOut:(NSTimeInterval)timeOut;
-(NSString*) equivalentLaunchCommand;
-(void) launch;
-(void) waitUntilExit;
-(int) terminationStatus;
-(void) setStdInputData:(NSData*)data;
-(NSData*) dataForStdOutput;
-(NSData*) dataForStdError;
@property (readonly) BOOL hasReachedTimeout;

@end
