//
//  MutableTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 06/05/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MutableTransformer : NSValueTransformer {

}

+(NSString*) name;

+(id) transformer;

@end
