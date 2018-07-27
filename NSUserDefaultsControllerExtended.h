//
//  NSUserDefaultsControllerExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSUserDefaultsController (Extended)

+(NSString*) adaptedKeyPath:(NSString*)keyPath;
-(NSString*) adaptedKeyPath:(NSString*)keyPath;

@end
