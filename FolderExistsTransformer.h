//
//  FolderExistsTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FolderExistsTransformer : NSValueTransformer {
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformer;
-(instancetype) init;

@end
