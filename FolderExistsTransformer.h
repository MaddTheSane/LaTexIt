//
//  FolderExistsTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FolderExistsTransformer : NSValueTransformer {
}

+(NSString*) name;

+(instancetype) transformer;
-(instancetype) init;

@end
