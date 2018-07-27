//
//  PluginsManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/09/10.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PluginsManager : NSObject {
  NSMutableArray* plugins;
}

+(PluginsManager*) sharedManager;

-(NSArray*) plugins;

@end
