//
//  IsEqualToTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsEqualToTransformer : NSValueTransformer {
  id reference;
}

+(NSString*) name;

+(id) transformerWithReference:(id)reference;
-(id) initWithReference:(id)reference;

@end