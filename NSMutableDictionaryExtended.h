//
//  NSMutableDictionaryExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/07/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSMutableDictionary (Extended)

-(void) replaceKey:(id)oldKey withKey:(id)newKey;

@end