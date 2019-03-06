//
//  PropertyStorage.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/06/14.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface PropertyStorage : NSObject {
  NSMutableDictionary* dictionary;
}

-(instancetype) init;
-(instancetype) initWithDictionary:(nullable NSDictionary<NSString*,NSNumber*>*)aDictionary NS_DESIGNATED_INITIALIZER;
-(nullable NSNumber*) objectForKey:(NSString*)key;
-(void) setObject:(nullable NSNumber*)object forKey:(NSString*)key;

@property (copy, null_resettable) NSDictionary<NSString*,NSNumber*> *dictionary;

- (nullable NSNumber*)objectForKeyedSubscript:(NSString*)key;
- (void)setObject:(nullable NSNumber*)obj forKeyedSubscript:(NSString*)key;

@end

NS_ASSUME_NONNULL_END
