//
//  NSMutableDictionaryExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/07/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSMutableDictionary<KeyType, ObjectType> (Extended)

-(void) replaceKey:(KeyType)oldKey withKey:(KeyType)newKey;

@end
