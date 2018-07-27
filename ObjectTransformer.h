//
//  ObjectTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ObjectTransformer : NSValueTransformer {
  NSDictionary* dictionary;
}

+(NSString*) name;

+(id) transformerWithDictionary:(NSDictionary*)dictionary;
-(id) initWithDictionary:(NSDictionary*)dictionary;

@end
