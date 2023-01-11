//
//  SystemTask.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
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
  NSDictionary<NSString*,NSString*>* environment;
  NSString*     launchPath;
  NSArray<NSString*>* arguments;
  BOOL          isUsingLoginShell;
  NSString*     currentDirectoryPath;
  NSLock*       runningLock;
  int           terminationStatus;
  BOOL          selfExited;
  NSString*     workingDirectory;
}

-(id)   init;//NSTemporaryDirectory() as workingDirectory
-(id)   initWithWorkingDirectory:(NSString*)workingDirectory;
@property (copy) NSDictionary<NSString*,NSString*>* environment;
@property (copy) NSArray<NSString*>* arguments;
@property (copy) NSString *currentDirectoryPath;
@property (copy) NSString *launchPath;
@property (getter=isUsingLoginShell) BOOL usingLoginShell;

-(void) setTimeOut:(NSTimeInterval)timeOut;
-(NSString*) equivalentLaunchCommand;
-(void) launch;
-(void) waitUntilExit;
@property (readonly) int terminationStatus;
-(void) setStdInputData:(NSData*)data;
@property (nonatomic, copy) NSData* dataForStdOutput;
@property (nonatomic, copy) NSData* dataForStdError;
@property (nonatomic, readonly) BOOL hasReachedTimeout;

@end
