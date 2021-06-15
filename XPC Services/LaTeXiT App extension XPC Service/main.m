//
//  main.m
//  LaTeXiT App extension XPC Service
//
//  Created by Pierre Chatelier on 02/10/2020.
//

#import <Foundation/Foundation.h>

#import "LaTeXiT_XPC_Service.h"
#import "LaTeXiT_XPC_Service_Delegate.h"

int main(int argc, const char* argv[])
{
  NSXPCListener* listener = [NSXPCListener serviceListener];
  LaTeXiT_XPC_Service_Delegate* delegate = [[LaTeXiT_XPC_Service_Delegate alloc] init];
  listener.delegate = delegate;
  [listener resume];//does not return
  [delegate release];
  return 0;
}
//end main()
