//
//  IsEqualToTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsEqualToTransformer : NSValueTransformer {
  id reference;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithReference:(id)reference;
-(instancetype) initWithReference:(id)reference NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;

@end
