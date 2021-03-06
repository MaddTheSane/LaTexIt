//
//  ArraySortingTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ArraySortingTransformer : NSValueTransformer {
  NSArray<NSSortDescriptor*>* descriptors;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithDescriptors:(nullable NSArray<NSSortDescriptor*>*)descriptors;
-(instancetype) initWithDescriptors:(nullable NSArray<NSSortDescriptor*>*)descriptors NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END
