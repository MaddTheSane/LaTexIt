//
//  NSDictionaryExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/10/07.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DeepCopying.h"

@interface NSDictionary<KeyType, ObjectType> (Extended) <DeepCopying, DeepMutableCopying>

-(NSDictionary<KeyType, ObjectType>*) dictionaryByAddingDictionary:(NSDictionary*)dictionary;
-(NSDictionary<KeyType, ObjectType>*) dictionaryByAddingObjectsAndKeys:(id)firstObject, ...;
-(NSDictionary<KeyType, ObjectType>*) subDictionaryWithKeys:(NSArray<KeyType>*)keys;

-(id) deepCopy;
-(id) deepCopyWithZone:(NSZone*)zone;
-(id) deepMutableCopy;
-(id) deepMutableCopyWithZone:(NSZone*)zone;

-(ObjectType) objectForKey:(KeyType)aKey withClass:(Class)class;

@end
