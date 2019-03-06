//
//  IsNotInTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsNotInTransformer : NSValueTransformer {
  NSArray* references;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithReferences:(id)references;
-(instancetype) initWithReferences:(id)references NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;

@end
