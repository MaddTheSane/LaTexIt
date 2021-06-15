//
//  NSDictionaryExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/10/07.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSDictionary (Extended)

-(NSDictionary*) dictionaryByAddingDictionary:(NSDictionary*)dictionary;
-(NSDictionary*) dictionaryByAddingObjectsAndKeys:(id)firstObject, ...;
-(NSDictionary*) subDictionaryWithKeys:(NSArray*)keys;

-(id) copyDeep;
-(id) copyDeepWithZone:(NSZone*)zone;
-(id) mutableCopyDeep;
-(id) mutableCopyDeepWithZone:(NSZone*)zone;

-(id) objectForKey:(id)aKey withClass:(Class)class;

@end
