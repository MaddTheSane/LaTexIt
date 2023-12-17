//
//  FolderExistsTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2023 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface FolderExistsTransformer : NSValueTransformer {
}

+(NSString*) name;

+(id) transformer;
-(id) init;

@end
