//
//  SystemTask.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2005, 2006, 2007, 2008 Pierre Chatelier. All rights reserved.
//

#import "SystemTask.h"

#import "DirectoryServiceHelper.h"
#import "NSFileManagerExtended.h"
#import "NSStringExtended.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>

@implementation SystemTask

-(id) initWithWorkingDirectory:(NSString*)workingDirectory
{
  if (![super init])
    return nil;
  tmpStdinFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-stdin.XXXXXXXXX" extension:@"log"  outFilePath:&tmpStdinFilePath
                                                                workingDirectory:workingDirectory];
  [tmpStdinFileHandle retain];
  [tmpStdinFilePath   retain];
  tmpStdoutFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-stdout.XXXXXXXXX" extension:@"log"  outFilePath:&tmpStdoutFilePath
                                                                workingDirectory:workingDirectory];
  [tmpStdoutFileHandle retain];
  [tmpStdoutFilePath   retain];
  tmpStderrFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-stderr.XXXXXXXXX" extension:@"log"  outFilePath:&tmpStderrFilePath
                                                                workingDirectory:workingDirectory];
  [tmpStderrFileHandle retain];
  [tmpStderrFilePath   retain];
  tmpScriptFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-script.XXXXXXXXX" extension:@"sh"  outFilePath:&tmpScriptFilePath
                                                                workingDirectory:workingDirectory];
  [tmpScriptFileHandle retain];
  [tmpScriptFilePath   retain];
  runningLock = [[NSLock alloc] init];
  return self;
}
//end initWithWorkingDirectory

-(id) init
{
  if (![self initWithWorkingDirectory:NSTemporaryDirectory()])
    return nil;
  return self;
}
//end init

-(void) dealloc
{
  [environment          release];
  [launchPath           release];
  [arguments            release];
  [currentDirectoryPath release];
  unlink([tmpStdinFilePath UTF8String]);
  unlink([tmpStdoutFilePath UTF8String]);
  unlink([tmpStderrFilePath UTF8String]);
  unlink([tmpScriptFilePath UTF8String]);
  [tmpStdinFilePath   release];
  [tmpStdoutFilePath   release];
  [tmpStderrFilePath   release];
  [tmpScriptFilePath   release];
  [tmpStdinFileHandle release];
  [tmpStdoutFileHandle release];
  [tmpStderrFileHandle release];
  [tmpScriptFileHandle release];
  [runningLock release];
  [super dealloc];
}
//end dealloc

-(void) setEnvironment:(NSDictionary*)theEnvironment
{
  [theEnvironment retain];
  [environment release];
  environment = theEnvironment;
}
//end setEnvironment:

-(void) setLaunchPath:(NSString*)path
{
  [path retain];
  [launchPath release];
  launchPath = path;
}
//end setEnvironment:

-(void) setArguments:(NSArray*)args
{
  [args retain];
  [arguments release];
  arguments = args;
}
//end setArguments:

-(void) setUsingLoginShell:(BOOL)value
{
  isUsingLoginShell = value;
}

-(void) setCurrentDirectoryPath:(NSString*)directoryPath
{
  [directoryPath retain];
  [currentDirectoryPath release];
  currentDirectoryPath = directoryPath;
}
//end setCurrentDirectoryPath:

-(NSDictionary*) environment
{
  return environment;
}
//end environment

-(NSString*) launchPath
{
  return launchPath;
}
//end launchPath

-(NSArray*) arguments
{
  return arguments;
}
//end arguments

-(BOOL) isUsingLoginShell
{
  return isUsingLoginShell;
}
//end isUsingLoginShell

-(NSString*) currentDirectoryPath
{
  return currentDirectoryPath;
}
//end currentDirectoryPath

-(void) setTimeOut:(NSTimeInterval)value
{
  timeOutLimit = value;
}
//end setTimeOut:

-(int) terminationStatus
{
  return terminationStatus;
}
//end terminationStatus

-(NSString*) equivalentLaunchCommand
{
  NSMutableString* scriptContent = [NSMutableString stringWithString:@"#!/bin/sh\n"];
  //environment is now inherited with the call to bash -l
  /*
  if (environment && [environment count])
  {
    NSEnumerator* environmentEnumerator = [environment keyEnumerator];
    NSString* variable = nil;
    while((variable = [environmentEnumerator nextObject]))
      [scriptContent appendFormat:@"export %@=%@ 1>/dev/null 2>&1 \n", variable, [environment objectForKey:variable]];
  }//end if (environment && [environment count])*/
  if (currentDirectoryPath)
    [scriptContent appendFormat:@"cd %@\n", currentDirectoryPath];
  if (launchPath)
  {
    [scriptContent appendFormat:@"%@", launchPath];
    if (arguments)
      [scriptContent appendFormat:@" %@", [arguments componentsJoinedByString:@" "]];
    if (tmpStdoutFilePath && tmpStderrFilePath)
      [scriptContent appendFormat:@" 1>|%@ 2>|%@ <%@\n", tmpStdoutFilePath, tmpStderrFilePath, (stdInputData ? tmpStdinFilePath : @"/dev/null")];
  }//end if (launchPath)
  return scriptContent;
}
//end equivalentLaunchCommand

-(void) launch
{
  NSError* error = nil;
  if (![[self equivalentLaunchCommand] writeToFile:tmpScriptFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error])
    terminationStatus = -1;
  else
  {
    NSString* currentShell = nil;
    #warning fix bugs with TCSH first
    /*if (isUsingLoginShell)
    {
      DirectoryServiceHelper* directoryServiceHelper = [[DirectoryServiceHelper alloc] init];
      currentShell = [directoryServiceHelper valueForKey:kDS1AttrUserShell andUser:NSUserName()];
      [directoryServiceHelper release];
    }*/
    if (!currentShell)
      currentShell = @"/bin/bash";
    NSString* option = (isUsingLoginShell && [currentShell isEqualToString:@"/bin/bash"]) ? @"-l" : @"";
    NSString* systemCommand = [NSString stringWithFormat:@"%@ %@ %@", currentShell, option, tmpScriptFilePath];

    if (!timeOutLimit)
    {
      [runningLock lock];
      terminationStatus = system([systemCommand UTF8String]);
      [runningLock unlock];
    }
    else //if timeOutLimit
    {
      [runningLock lock];
      pid_t pid = fork();
      if (!pid)//in the child
      {
        [NSApplication detachDrawingThread:@selector(threadTimeoutSignal:) toTarget:self
                                withObject:[NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:getpid()] forKey:@"pid"]];
        terminationStatus = system([systemCommand UTF8String]);
        terminationStatus = WIFEXITED(terminationStatus) ? WEXITSTATUS(terminationStatus) : -1;
        exit(terminationStatus);
      }
      else
      {
        int status = 0;
        wait(&status);
        selfExited = WIFEXITED(status) && !WIFSIGNALED(status);
        terminationStatus = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
      }
      [runningLock unlock];
    }//end if timeOutLimit
  }//end if filePath
}
//end launch

-(void) waitUntilExit
{
  [runningLock lock];
  [runningLock unlock];
}
//end waitUntilExit

-(void) setStdInputData:(NSData*)data
{
  [data retain];
  [stdInputData release];
  stdInputData = data;
  [stdInputData writeToFile:tmpStdinFilePath atomically:NO];
}
//end setStdInputData:

-(NSData*) dataForStdOutput
{
  return [NSData dataWithContentsOfFile:tmpStdoutFilePath];
}
//end dataForStdOutput

-(NSData*) dataForStdError
{
  return [NSData dataWithContentsOfFile:tmpStderrFilePath];
}
//end dataForStdError

-(BOOL) hasReachedTimeout
{
  return !selfExited;
}
//end hasReachedTimeout

-(void) threadTimeoutSignal:(id)object
{
  [NSThread sleepUntilDate:[[NSDate date] addTimeInterval:timeOutLimit]];
  kill([[object valueForKey:@"pid"] unsignedIntValue], SIGKILL);
}
//end threadTimeoutSignal:

@end
