//
//  PluginsManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Plugin;

@interface PluginsManager : NSObject {
  NSMutableArray<Plugin*>* plugins;
}

@property (class, readonly, retain, nonnull) PluginsManager *sharedManager;

@property (readonly, copy, nonnull) NSArray<Plugin*> *plugins;

@end
