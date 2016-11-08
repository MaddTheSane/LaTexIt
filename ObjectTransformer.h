//
//  ObjectTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ObjectTransformer : NSValueTransformer {
  NSDictionary* dictionary;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithDictionary:(NSDictionary*)dictionary;
-(instancetype) initWithDictionary:(NSDictionary*)dictionary;

@end
