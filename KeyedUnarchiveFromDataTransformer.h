//
//  KeyedUnarchiveFromDataTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/04/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KeyedUnarchiveFromDataTransformer : NSValueTransformer {
}

+(NSString*) name;
+(id) transformer;

@end
