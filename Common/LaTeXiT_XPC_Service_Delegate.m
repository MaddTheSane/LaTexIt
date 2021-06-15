//
//  LaTeXiT_XPC_Service_Delegate.m
//  LaTeXiT-10_9+
//
//  Created by Pierre Chatelier on 07/10/2020.
//

#import <Foundation/Foundation.h>

#import "LaTeXiT_XPC_Service_Delegate.h"

#import "LaTeXiT_XPC_Service.h"
#import "LaTeXiT_XPC_Service_Protocol.h"

@implementation LaTeXiT_XPC_Service_Delegate

-(BOOL) listener:(NSXPCListener*)listener shouldAcceptNewConnection:(NSXPCConnection*)newConnection
{
  newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(LaTeXiT_XPC_Service_Protocol)];
  LaTeXiT_XPC_Service* exportedObject = [[LaTeXiT_XPC_Service alloc] init];
  newConnection.exportedObject = exportedObject;
  [newConnection resume];
  [exportedObject release];
  return YES;
}
//end listener:shouldAcceptNewConnection:

@end
