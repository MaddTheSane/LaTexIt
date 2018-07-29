//
//  main.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 19/03/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

#import "Utils.h"

int main(int argc, char *argv[])
{
  @autoreleasepool {
  
    int debugLogLevelShift = 0;
    BOOL shiftIsPressed = ((GetCurrentEventKeyModifiers() & shiftKey) != 0);
    if (shiftIsPressed)
    {
      NSLog(@"Shift key pressed during launch");
      debugLogLevelShift = 1;
    }
        
    int i = 0;
    for(i = 1 ; i<argc ; ++i)
    {
      if (!strcasecmp(argv[i], "-v"))
      {
        DebugLogLevel = 1;
        if (i+1 < argc)
        {
          char* endPtr = 0;
          long level = strtol(argv[i+1], &endPtr, 10);
          int error = (endPtr && (*endPtr != '\0'));
          DebugLogLevel = error ? DebugLogLevel : (int)level;
        }//end if -v something
      }//end if -v
    }//end for each arg
    DebugLogLevel += debugLogLevelShift;
    if (DebugLogLevel >= 1){
      NSLog(@"Launching with DebugLogLevel = %d", DebugLogLevel);
    }
      
    int result = NSApplicationMain(argc, (const char **) argv);
    
    
    return result;
  }
}
//end main()
