//
//  PluginsManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PluginsManager : NSObject {
  NSMutableArray* plugins;
}

+(PluginsManager*) sharedManager;

-(NSArray*) plugins;

@end
