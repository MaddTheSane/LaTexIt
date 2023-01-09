//
//  SystemTask.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import "SystemTask.h"

#import "NSFileManagerExtended.h"
#import "NSStringExtended.h"
#import "NSWorkspaceExtended.h"

#import "Utils.h"

#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <crt_externs.h>

@implementation SystemTask

-(id) initWithWorkingDirectory:(NSString*)aWorkingDirectory
{
  if ((!(self = [super init])))
    return nil;
  NSString* localString = nil;
  self->workingDirectory = [aWorkingDirectory copy];
  self->tmpStdinFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-stdin.XXXXXXXX" extension:@"log"  outFilePath:&localString
                                                                workingDirectory:self->workingDirectory];
  self->tmpStdinFilePath = localString;
  #ifdef ARC_ENABLED
  #else
  [self->tmpStdinFileHandle retain];
  [self->tmpStdinFilePath   retain];
  #endif
  self->tmpStdoutFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-stdout.XXXXXXXX" extension:@"log"  outFilePath:&localString

                                                        workingDirectory:self->workingDirectory];
  self->tmpStdoutFilePath = localString;
  #ifdef ARC_ENABLED
  #else
  [self->tmpStdoutFileHandle retain];
  [self->tmpStdoutFilePath   retain];
  #endif
  self->tmpStderrFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-stderr.XXXXXXXX" extension:@"log"  outFilePath:&localString
                                                                workingDirectory:self->workingDirectory];
  self->tmpStderrFilePath = localString;
  #ifdef ARC_ENABLED
  #else
  [self->tmpStderrFileHandle retain];
  [self->tmpStderrFilePath   retain];
  #endif
  self->tmpScriptFileHandle = [[NSFileManager defaultManager] temporaryFileWithTemplate:@"latexit-task-script.XXXXXXXX" extension:@"sh"  outFilePath:&localString
                                                                workingDirectory:self->workingDirectory];
  self->tmpScriptFilePath = localString;
  #ifdef ARC_ENABLED
  #else
  [self->tmpScriptFileHandle retain];
  [self->tmpScriptFilePath   retain];
  #endif
  self->runningLock = [[NSLock alloc] init];
  return self;
}
//end initWithWorkingDirectory

-(id) init
{
  return [self initWithWorkingDirectory:NSTemporaryDirectory()];
}
//end init

-(void) dealloc
{
  #ifdef ARC_ENABLED
  #else
  [self->environment          release];
  [self->launchPath           release];
  [self->arguments            release];
  [self->currentDirectoryPath release];
  #endif
  if (DebugLogLevel < 1)
  {
    unlink([self->tmpStdinFilePath UTF8String]);
    unlink([self->tmpStdoutFilePath UTF8String]);
    unlink([self->tmpStderrFilePath UTF8String]);
    unlink([self->tmpScriptFilePath UTF8String]);
  }//end if (DebugLogLevel < 1)
  #ifdef ARC_ENABLED
  #else
  [self->tmpStdinFilePath   release];
  [self->tmpStdoutFilePath   release];
  [self->tmpStderrFilePath   release];
  [self->tmpScriptFilePath   release];
  [self->tmpStdinFileHandle release];
  [self->tmpStdoutFileHandle release];
  [self->tmpStderrFileHandle release];
  [self->tmpScriptFileHandle release];
  [self->runningLock release];
  [self->workingDirectory release];
  [super dealloc];
  #endif
}
//end dealloc

-(void) setEnvironment:(NSDictionary*)theEnvironment
{
  #ifdef ARC_ENABLED
  #else
  [theEnvironment retain];
  [self->environment release];
  #endif
  self->environment = theEnvironment;
}
//end setEnvironment:

-(void) setLaunchPath:(NSString*)path
{
  #ifdef ARC_ENABLED
  #else
  [path retain];
  [self->launchPath release];
  #endif
  self->launchPath = path;
}
//end setEnvironment:

-(void) setArguments:(NSArray*)args
{
  #ifdef ARC_ENABLED
  #else
  [args retain];
  [self->arguments release];
  #endif
  self->arguments = args;
}
//end setArguments:

-(void) setUsingLoginShell:(BOOL)value
{
  self->isUsingLoginShell = value;
}

-(void) setCurrentDirectoryPath:(NSString*)directoryPath
{
  #ifdef ARC_ENABLED
  #else
  [directoryPath retain];
  [self->currentDirectoryPath release];
  #endif
  self->currentDirectoryPath = directoryPath;
}
//end setCurrentDirectoryPath:

-(NSDictionary*) environment
{
  return self->environment;
}
//end environment

-(NSString*) launchPath
{
  return self->launchPath;
}
//end launchPath

-(NSArray*) arguments
{
  return self->arguments;
}
//end arguments

-(BOOL) isUsingLoginShell
{
  return self->isUsingLoginShell;
}
//end isUsingLoginShell

-(NSString*) currentDirectoryPath
{
  return self->currentDirectoryPath;
}
//end currentDirectoryPath

-(void) setTimeOut:(NSTimeInterval)value
{
  self->timeOutLimit = value;
}
//end setTimeOut:

-(int) terminationStatus
{
  return self->terminationStatus;
}
//end terminationStatus

-(NSString*) equivalentLaunchCommand
{
  NSMutableString* scriptContent = [NSMutableString stringWithString:@"#!/bin/sh\n"];
  //environment is now inherited with the call to bash -l
  if (self->environment && [self->environment count])
  {
    NSEnumerator* environmentEnumerator = [self->environment keyEnumerator];
    NSString* variable = nil;
    while((variable = [environmentEnumerator nextObject]))
    {
      BOOL isDoubleQuoted = ([variable length] >= 2) && [variable startsWith:@"\"" options:0] && [variable endsWith:@"\"" options:0];
      if ([variable length] && !isDoubleQuoted)
      {
        NSString* variableValue = [[environment objectForKey:variable] stringByReplacingOccurrencesOfRegex:@"\"" withString:@"\\\""];
        [scriptContent appendFormat:@"export %@=\"%@\" 1>/dev/null 2>&1 \n", variable, variableValue];
      }
    }
  }//end if (environment && [environment count])
  if (self->currentDirectoryPath)
    [scriptContent appendFormat:@"cd \"%@\"\n", currentDirectoryPath];
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
    if (!currentShell)
      currentShell = @"/bin/bash";
    NSString* option = ![currentShell isEqualToString:@"/bin/bash"] ? @"" :
                       self->isUsingLoginShell ? @"" : @"-l";
    int       intTimeOutLimit = (int)self->timeOutLimit;
    NSString* userScriptCall = [NSString stringWithFormat:@"%@ %@ \"%@\"", currentShell, option, tmpScriptFilePath];
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
    NSString* systemCall = [NSString stringWithFormat:@"/bin/sh \"%@\"", timeLimitedScriptPath];
    self->terminationStatus = system([systemCall UTF8String]);
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
  #ifdef ARC_ENABLED
  #else
  [data retain];
  [self->stdInputData release];
  #endif
  self->stdInputData = data;
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
