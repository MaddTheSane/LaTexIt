//
//  IsNotEqualToTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 26/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsNotEqualToTransformer : NSValueTransformer {
  id reference;
}

+(NSString*) name;

+(id) transformerWithReference:(id)reference;
-(id) initWithReference:(id)reference;

@end
