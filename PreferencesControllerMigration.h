//
//  PreferencesControllerMigration.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/07/09.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PreferencesController.h"

NS_ASSUME_NONNULL_BEGIN

extern NSString* const Old_CheckForNewVersionsKey;

@interface PreferencesController (Migration)

@property (class, readonly, copy) NSArray<NSString*> *oldKeys;
-(void) migratePreferences;
-(void) removeKey:(NSString*)key;
-(void) replaceKey:(NSString*)oldKey withKey:(NSString*)newKey;

@end

NS_ASSUME_NONNULL_END
