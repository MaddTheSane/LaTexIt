//
//  SystemTask.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
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

-(instancetype)   init; ///< \c NSTemporaryDirectory() as workingDirectory
-(instancetype)   initWithWorkingDirectory:(NSString*)workingDirectory;
@property (copy)  NSDictionary<NSString *, NSString*> *environment;
@property (copy)  NSString *launchPath;
@property (copy)  NSArray<NSString *> *arguments;
@property (copy)  NSString *currentDirectoryPath;
@property (getter=isUsingLoginShell) BOOL usingLoginShell;

-(void) setTimeOut:(NSTimeInterval)timeOut;
-(NSString*) equivalentLaunchCommand;
-(void) launch;
-(void) waitUntilExit;
@property (readonly) int terminationStatus;
-(void) setStdInputData:(NSData*)data;
-(NSData*) dataForStdOutput;
-(NSData*) dataForStdError;
@property (readonly) BOOL hasReachedTimeout;

@end
