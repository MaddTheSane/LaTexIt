//
//  SystemTask.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import "SystemTask.h"

#import "DirectoryServiceHelper.h"
#import "NSFileManagerExtended.h"
#import "NSStringExtended.h"

#import "RegexKitLite.h"
#import "Utils.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <crt_externs.h>

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

@implementation SystemTask

-(instancetype) initWithWorkingDirectory:(NSString*)aWorkingDirectory
{
  if ((!(self = [super init])))
    return nil;
  NSString* localString = nil;
  self->workingDirectory = [aWorkingDirectory copy];
  self->tmpStdinFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-stdin.XXXXXXXX" extension:@"log"  outFilePath:&localString
                                                                workingDirectory:self->workingDirectory];
  self->tmpStdinFilePath = localString;
  self->tmpStdoutFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-stdout.XXXXXXXX" extension:@"log"  outFilePath:&localString

                                                        workingDirectory:self->workingDirectory];
  self->tmpStdoutFilePath = localString;
  self->tmpStderrFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-stderr.XXXXXXXX" extension:@"log"  outFilePath:&localString
                                                                workingDirectory:self->workingDirectory];
  self->tmpStderrFilePath = localString;
  self->tmpScriptFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-script.XXXXXXXX" extension:@"sh"  outFilePath:&localString
                                                                workingDirectory:self->workingDirectory];
  self->tmpScriptFilePath = localString;
  self->runningLock = [[NSLock alloc] init];
  return self;
}
//end initWithWorkingDirectory

-(instancetype) init
{
  return self = [self initWithWorkingDirectory:NSTemporaryDirectory()];
}
//end init

-(void) dealloc
{
  if (DebugLogLevel < 1)
  {
    unlink(self->tmpStdinFilePath.fileSystemRepresentation);
    unlink(self->tmpStdoutFilePath.fileSystemRepresentation);
    unlink(self->tmpStderrFilePath.fileSystemRepresentation);
    unlink(self->tmpScriptFilePath.fileSystemRepresentation);
  }//end if (DebugLogLevel < 1)
}
//end dealloc

@synthesize environment;
@synthesize launchPath;
@synthesize arguments = arguments;
@synthesize currentDirectoryPath;
@synthesize usingLoginShell = isUsingLoginShell;
@synthesize terminationStatus;

@synthesize timeOut=timeOutLimit;
//end setTimeOut:

-(NSString*) equivalentLaunchCommand
{
  NSMutableString* scriptContent = [NSMutableString stringWithString:@"#!/bin/sh\n"];
  //environment is now inherited with the call to bash -l
  if (self->environment && self->environment.count)
  {
    NSEnumerator* environmentEnumerator = [self->environment keyEnumerator];
    NSString* variable = nil;
    while((variable = [environmentEnumerator nextObject]))
    {
      BOOL isDoubleQuoted = (variable.length >= 2) && [variable startsWith:@"\"" options:0] && [variable endsWith:@"\"" options:0];
      if (variable.length && !isDoubleQuoted)
      {
        NSString* variableValue = [environment[variable] stringByReplacingOccurrencesOfRegex:@"\"" withString:@"\\\""];
        [scriptContent appendFormat:@"export %@=\"%@\" 1>/dev/null 2>&1 \n", variable, variableValue];
      }
    }
  }//end if (environment && [environment count])
  if (self->currentDirectoryPath)
    [scriptContent appendFormat:@"cd %@\n", currentDirectoryPath];
  if (self->launchPath)
  {
    [scriptContent appendFormat:@"%@", launchPath];
    if (self->arguments)
      [scriptContent appendFormat:@" %@", [self->arguments componentsJoinedByString:@" "]];
    if (self->tmpStdoutFilePath && self->tmpStderrFilePath)
      [scriptContent appendFormat:@" 1>|%@ 2>|%@ <%@\n", self->tmpStdoutFilePath, self->tmpStderrFilePath, (self->stdInputData ? self->tmpStdinFilePath : @"/dev/null")];
  }//end if (launchPath)
  return scriptContent;
}
//end equivalentLaunchCommand

-(void) launch
{
  NSError* error = nil;
  DebugLog(2, @"><%@>", [self equivalentLaunchCommand]);
  if (![[self equivalentLaunchCommand] writeToFile:self->tmpScriptFilePath atomically:YES encoding:NSUTF8StringEncoding error:&error])
    self->terminationStatus = -1;
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
    NSString* option = ![currentShell isEqualToString:@"/bin/bash"] ? @"" :
                       self->isUsingLoginShell ? @"" : @"-l";
    int       intTimeOutLimit = (int)self->timeOutLimit;
    NSString* userScriptCall = [NSString stringWithFormat:@"%@ %@ %@", currentShell, option, tmpScriptFilePath];
    [self->runningLock lock];
    NSString* timeLimitedScript = !intTimeOutLimit ?
      [NSString stringWithFormat:@"#!/bin/bash\n%@", userScriptCall] :
      [NSString stringWithFormat:
        @"#!/bin/bash\n"\
         "PID=$$\n"\
         "sleep %d && kill -9 \"$PID\" &\n"
         "KILLER=$!\n"\
         "(%@)\n"\
         "RETURNCODE=$?\n"\
         "kill -9 $KILLER\n"\
         "exit $RETURNCODE\n",
         intTimeOutLimit, userScriptCall];
    NSString* timeLimitedScriptPath = nil;
    [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-timelimited.XXXXXXXX" extension:@"script"
                                                  outFilePath:&timeLimitedScriptPath workingDirectory:self->workingDirectory];
    [timeLimitedScript writeToFile:timeLimitedScriptPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSString* systemCall = [NSString stringWithFormat:@"/bin/sh %@", timeLimitedScriptPath];
    self->terminationStatus = system(systemCall.UTF8String);
    /*pid_t pid = fork();
    if (!pid)
    {
      system([userScriptCall UTF8String]);
      exit(0);
    }
    else
    {
      waitpid(pid, &self->terminationStatus, WNOHANG);
      printf("r = %d\n", self->terminationStatus);
      while(self->terminationStatus == -1)
      {
        waitpid(pid, &self->terminationStatus, WNOHANG);
        printf("r = %d\n", self->terminationStatus);
      }
    }*/
    self->selfExited        = WIFEXITED(self->terminationStatus) && !WIFSIGNALED(self->terminationStatus);
    self->terminationStatus = WIFEXITED(self->terminationStatus) ? WEXITSTATUS(self->terminationStatus) : -1;
    [self->runningLock unlock];
    [[NSFileManager defaultManager] removeItemAtPath:timeLimitedScriptPath error:0];
  }//end if filePath
}
//end launch

-(void) waitUntilExit
{
  [self->runningLock lock];
  [self->runningLock unlock];
  DebugLog(2, @"<<%@>", [self equivalentLaunchCommand]);
}
//end waitUntilExit

-(void) setStdInputData:(NSData*)data
{
  self->stdInputData = [data copy];
  [self->stdInputData writeToFile:self->tmpStdinFilePath atomically:NO];
}
//end setStdInputData:

-(NSData*) dataForStdOutput
{
  NSData* result = [NSData dataWithContentsOfFile:self->tmpStdoutFilePath];
  return result;
}
//end dataForStdOutput

-(NSData*) dataForStdError
{
  NSData* result = [NSData dataWithContentsOfFile:self->tmpStderrFilePath];
  return result;
}
//end dataForStdError

-(BOOL) hasReachedTimeout
{
  return !self->selfExited;
}
//end hasReachedTimeout

@end
