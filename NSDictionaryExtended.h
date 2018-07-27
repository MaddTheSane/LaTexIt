//
//  NSDictionaryExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/10/07.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSDictionary (Extended)

-(NSDictionary*) dictionaryByAddingDictionary:(NSDictionary*)dictionary;
-(NSDictionary*) dictionaryByAddingObjectsAndKeys:(id)firstObject, ...;
-(NSDictionary*) subDictionaryWithKeys:(NSArray*)keys;

-(id) deepCopy;
-(id) deepCopyWithZone:(NSZone*)zone;
-(id) deepMutableCopy;
-(id) deepMutableCopyWithZone:(NSZone*)zone;

-(id) objectForKey:(id)aKey withClass:(Class)class;

@end
