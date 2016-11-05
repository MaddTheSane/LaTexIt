//
//  ArraySortingTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ArraySortingTransformer : NSValueTransformer {
  NSArray* descriptors;
}

+(NSString*) name;

+(instancetype) transformerWithDescriptors:(NSArray*)descriptors;
-(instancetype) initWithDescriptors:(NSArray*)descriptors;

@end
