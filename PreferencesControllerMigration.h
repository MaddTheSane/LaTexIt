//
//  PreferencesControllerMigration.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PreferencesController.h"

extern NSString* Old_CheckForNewVersionsKey;

@interface PreferencesController (Migration)

+(NSArray*) oldKeys;
-(void) migratePreferences;
-(void) removeKey:(NSString*)key;
-(void) replaceKey:(NSString*)oldKey withKey:(NSString*)newKey;

@end
