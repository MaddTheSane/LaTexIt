//
//  SystemTask.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 25/05/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "SystemTask.h"

#import "Utils.h"

#include <sys/types.h>
#include <sys/wait.h>

@implementation SystemTask

-(id) init
{
  if (![super init])
    return nil;
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
  if (unlink([tmpStdoutFilePath UTF8String]))
    perror("unlink:");
  if (unlink([tmpStderrFilePath UTF8String]))
    perror("unlink:");
  [tmpStdoutFilePath   release];
  [tmpStderrFilePath   release];
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

-(void) setStandardInput:(id)object
{
  [object retain];
  [standardInput release];
  standardInput = object;
}
//end setStandardInput:

-(void) setStandardOutput:(id)object
{
  [object retain];
  [standardOutput release];
  standardOutput = object;
}
//end setStandardOutput:

-(void) setStandardError:(id)object
{
  [object retain];
  [standardError release];
  standardError = object;
}
//end setStandardError:

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
    [systemCommand appendFormat:@"cd %@ 1>|/dev/null 2>|1;", currentDirectoryPath];
  if (environment)
  {
    NSEnumerator* environmentEnumerator = [environment keyEnumerator];
    NSMutableString* exportedVariables = [NSMutableString string];
    NSString* variable = nil;
    while((variable = [environmentEnumerator nextObject]))
      [exportedVariables appendFormat:@" %@=\"%@\"", variable, [environment objectForKey:variable]];
    [systemCommand appendFormat:@"export %@ 1>|/dev/null 2>|1 || echo \"\" 1>|/dev/null 2>|1;", exportedVariables];
  }
  if (launchPath)
    [systemCommand appendFormat:@"%@", launchPath];
  if (arguments)
    [systemCommand appendFormat:@" %@", [arguments componentsJoinedByString:@" "]];
  if (tmpStdoutFilePath && tmpStderrFilePath)
    [systemCommand appendFormat:@" 1>|%@ 2>|%@ </dev/null", tmpStdoutFilePath, tmpStderrFilePath];
  return [NSString stringWithString:systemCommand];
}
//end equivalentLaunchCommand

-(void) launch
{
  NSString* systemCommand = [self equivalentLaunchCommand];

  if (!timeOutLimit)
  {
    [runningLock lock];
    terminationStatus = system([systemCommand UTF8String]);
    NSFileHandle* stdoutFileHandle =
      [standardOutput isKindOfClass:[NSFileHandle class]] ? standardOutput :
      [standardOutput isKindOfClass:[NSPipe class]] ? [standardOutput fileHandleForWriting] : nil;
    NSFileHandle* stderrFileHandle =
      [standardError isKindOfClass:[NSFileHandle class]] ? standardError :
      [standardError isKindOfClass:[NSPipe class]] ? [standardError fileHandleForWriting] : nil;
      
    [stdoutFileHandle writeData:[tmpStdoutFileHandle availableData]];
    [stderrFileHandle writeData:[tmpStderrFileHandle availableData]];
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
      NSFileHandle* stdoutFileHandle =
        [standardOutput isKindOfClass:[NSFileHandle class]] ? standardOutput :
        [standardOutput isKindOfClass:[NSPipe class]] ? [standardOutput fileHandleForWriting] : nil;
      NSFileHandle* stderrFileHandle =
        [standardError isKindOfClass:[NSFileHandle class]] ? standardError :
        [standardError isKindOfClass:[NSPipe class]] ? [standardError fileHandleForWriting] : nil;
      [stdoutFileHandle writeData:[tmpStdoutFileHandle availableData]];
      [stderrFileHandle writeData:[tmpStderrFileHandle availableData]];
      [stdoutFileHandle closeFile];
      [stderrFileHandle closeFile];
    }
    [runningLock unlock];
  }//end if timeOutLimit
}
//end launch

-(void) waitUntilExit
{
  [runningLock lock];
  [runningLock unlock];
}
//end waitUntilExit

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
