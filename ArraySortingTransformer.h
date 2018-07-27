//
//  ArraySortingTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface ArraySortingTransformer : NSValueTransformer {
  NSArray* descriptors;
}

+(NSString*) name;

+(id) transformerWithDescriptors:(NSArray*)descriptors;
-(id) initWithDescriptors:(NSArray*)descriptors;

@end
