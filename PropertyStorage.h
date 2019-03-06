//
//  PropertyStorage.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/06/14.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface PropertyStorage : NSObject {
  NSMutableDictionary* dictionary;
}

-(id) init;
-(id) initWithDictionary:(NSDictionary*)aDictionary;
-(id) objectForKey:(id)key;
-(void) setObject:(id)object forKey:(id)key;

-(void) setDictionary:(NSDictionary*)value;
-(NSDictionary*) dictionary;

@end
