//
//  ObjectTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ObjectTransformer : NSValueTransformer {
  NSDictionary* dictionary;
}

+(NSString*) name;

+(id) transformerWithDictionary:(NSDictionary*)dictionary;
-(id) initWithDictionary:(NSDictionary*)dictionary;

@end
