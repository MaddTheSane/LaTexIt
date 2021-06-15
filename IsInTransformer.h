//
//  IsInTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsInTransformer : NSValueTransformer {
  NSArray* references;
}

+(NSString*) name;

+(id) transformerWithReferences:(id)references;
-(id) initWithReferences:(id)references;

@end
