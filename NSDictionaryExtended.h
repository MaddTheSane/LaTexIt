//
//  NSDictionaryExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/10/07.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSDictionary (Extended)

-(NSDictionary*) subDictionaryWithKeys:(NSArray*)keys;

-(id) deepCopy;
-(id) deepCopyWithZone:(NSZone*)zone;
-(id) deepMutableCopy;
-(id) deepMutableCopyWithZone:(NSZone*)zone;

@end
