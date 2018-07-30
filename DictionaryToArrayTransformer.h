//
//  DictionaryToArrayTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DictionaryToArrayTransformer : NSValueTransformer {
  NSArray* descriptors;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithDescriptors:(NSArray*)descriptors;
-(instancetype) initWithDescriptors:(NSArray*)descriptors NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;

@end
