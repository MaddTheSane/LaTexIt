//
//  MutableTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MutableTransformer : NSValueTransformer {

}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformer;

@end
