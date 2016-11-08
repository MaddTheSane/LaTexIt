//
//  IsNotEqualToTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsNotEqualToTransformer : NSValueTransformer {
  id reference;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithReference:(id)reference;
-(instancetype) initWithReference:(id)reference;

@end
