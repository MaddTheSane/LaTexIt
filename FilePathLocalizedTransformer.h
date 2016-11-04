//
//  FilePathLocalizedTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/06/14.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FilePathLocalizedTransformer : NSValueTransformer {

}

+(NSString*) name;

+(id) transformer;
-(id) init;

@end
