//
//  PropertyStorage.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/06/14.
//  Copyright 2014 __MyCompanyName__. All rights reserved.
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
