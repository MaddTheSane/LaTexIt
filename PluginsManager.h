//
//  PluginsManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Plugin.h"

@interface PluginsManager : NSObject {
  NSMutableArray<Plugin*>* plugins;
}

+(PluginsManager*) sharedManager;
@property (class, readonly, retain) PluginsManager *sharedManager;

@property (readonly, copy) NSArray<Plugin*>*plugins;

@end
