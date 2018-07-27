//
//  SystemTask.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SystemTask.h"

#import "NSStringExtended.h"
#import "Utils.h"

#include <sys/types.h>
#include <sys/wait.h>

@implementation SystemTask

-(id) init
{
  if (![super init])
    return nil;
  tmpStdinFileHandle = [Utils temporaryFileWithTemplate:@"latexit-task-stdin.XXXXXXXXX" extension:@"log"  outFilePath:&tmpStdinFilePath];
  [tmpStdinFileHandle retain];
  [tmpStdinFilePath   retain];
  tmpStdoutFileHandle = [Utils temporaryFileWithTemplate:@"latexit-task-stdout.XXXXXXXXX" extension:@"log"  outFilePath:&tmpStdoutFilePath];
  [tmpStdoutFileHandle retain];
  [tmpStdoutFilePath   retain];
  tmpStderrFileHandle = [Utils temporaryFileWithTemplate:@"latexit-task-stderr.XXXXXXXXX" extension:@"log"  outFilePath:&tmpStderrFilePath];
  [tmpStderrFileHandle retain];
  [tmpStderrFilePath   retain];
  runningLock = [[NSLock alloc] init];
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
  [tmpStdinFilePath   release];
  [tmpStdoutFilePath   release];
  [tmpStderrFilePath   release];
  [tmpStdinFileHandle release];
  [tmpStdoutFileHandle release];
  [tmpStderrFileHandle release];
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
//end arguments;

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
  NSMutableString* systemCommand = [NSMutableString string];
  if (currentDirectoryPath)
    [systemCommand appendFormat:@"cd %@ 1>|/dev/null 2>&1;", currentDirectoryPath];
  if (environment)
  {
    NSEnumerator* environmentEnumerator = [environment keyEnumerator];
    NSMutableString* exportedVariables = [NSMutableString string];
    NSString* variable = nil;
    while((variable = [environmentEnumerator nextObject]))
    {
      if ([[environment objectForKey:variable] startsWith:@"'" options:0] && [[environment objectForKey:variable] endsWith:@"'" options:0])
        [exportedVariables appendFormat:@" %@=%@", variable, [environment objectForKey:variable]];
      else if ([[environment objectForKey:variable] startsWith:@"\"" options:0] && [[environment objectForKey:variable] endsWith:@"\"" options:0])
        [exportedVariables appendFormat:@" %@=%@", variable, [environment objectForKey:variable]];
      else
        [exportedVariables appendFormat:@" %@=\"%@\"", variable, [environment objectForKey:variable]];
    }
    [systemCommand appendFormat:@"export %@ 1>|/dev/null 2>&1 || echo \"\" 1>|/dev/null 2>&1;", exportedVariables];
  }
  if (launchPath)
    [systemCommand appendFormat:@"%@", launchPath];
  if (arguments)
    [systemCommand appendFormat:@" %@", [arguments componentsJoinedByString:@" "]];
  if (tmpStdoutFilePath && tmpStderrFilePath)
    [systemCommand appendFormat:@" 1>|%@ 2>|%@ <%@", tmpStdoutFilePath, tmpStderrFilePath, (stdInputData ? tmpStdinFilePath : @"/dev/null")];
  return [NSString stringWithString:systemCommand];
}
//end equivalentLaunchCommand

-(void) launch
{
  NSString* filePath = nil;
  [Utils temporaryFileWithTemplate:@"latexit-command-XXXXXXXXX" extension:@"sh" outFilePath:&filePath];
  if (!filePath || ![[self equivalentLaunchCommand] writeToFile:filePath atomically:YES])
    terminationStatus = -1;
  else
  {
    NSString* systemCommand = [NSString stringWithFormat:@"/bin/bash -l %@", filePath];

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
    
    if (filePath)
      unlink([filePath UTF8String]);
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
