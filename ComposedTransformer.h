//
//  ComposedTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ComposedTransformer : NSValueTransformer {
  NSValueTransformer* valueTransformer;
  NSValueTransformer* additionalValueTransformer;
  NSString* additionalKeyPath;
}

+(NSString*) name;

+(id) transformerWithValueTransformer:(NSValueTransformer*)valueTransformer
           additionalValueTransformer:(NSValueTransformer*)additionalValueTransformer additionalKeyPath:(NSString*)additionalKeyPath;
-(id) initWithValueTransformer:(NSValueTransformer*)valueTransformer
    additionalValueTransformer:(NSValueTransformer*)additionalValueTransformer additionalKeyPath:(NSString*)additionalKeyPath;

@end
