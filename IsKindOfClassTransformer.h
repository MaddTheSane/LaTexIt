//
//  IsKindOfClassTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsKindOfClassTransformer : NSValueTransformer {
  Class theClass;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithClass:(Class)aClass;
-(instancetype) initWithClass:(Class)aClass NS_DESIGNATED_INITIALIZER;

@end
