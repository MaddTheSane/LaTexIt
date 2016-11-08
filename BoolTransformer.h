//
//  BoolTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface BoolTransformer : NSValueTransformer {
  id falseValue;
  id trueValue;
}
//end BoolTransformer

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithFalseValue:(id)falseValue trueValue:(id)trueValue;
-(instancetype) initWithFalseValue:(id)falseValue trueValue:(id)trueValue;

@end
