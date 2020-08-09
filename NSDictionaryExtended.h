//
//  NSDictionaryExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/10/07.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DeepCopying.h"

@interface NSDictionary<KeyType, ObjectType> (Extended) <DeepCopying, DeepMutableCopying>

-(NSDictionary<KeyType, ObjectType>*) dictionaryByAddingDictionary:(NSDictionary*)dictionary;
-(NSDictionary<KeyType, ObjectType>*) dictionaryByAddingObjectsAndKeys:(id)firstObject, ...;
-(NSDictionary<KeyType, ObjectType>*) subDictionaryWithKeys:(NSArray<KeyType>*)keys;

-(id) copyDeep;
-(id) copyDeepWithZone:(NSZone*)zone;
-(id) mutableCopyDeep;
-(id) mutableCopyDeepWithZone:(NSZone*)zone;

-(ObjectType) objectForKey:(KeyType)aKey withClass:(Class)class;

@end
