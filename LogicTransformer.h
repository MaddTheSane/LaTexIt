//
//  LogicTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef NS_ENUM(NSInteger, logic_transformer_operator_t) {
  LOGIC_TRANSFORMER_OPERATOR_AND,
  LOGIC_TRANSFORMER_OPERATOR_OR
};

@interface LogicTransformer : NSValueTransformer {
  NSArray* transformers;
  logic_transformer_operator_t logicOperator;
}
//end BoolTransformer

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithTransformers:(NSArray*)transformers logicOperator:(logic_transformer_operator_t)logicOperator;
-(instancetype) initWithTransformers:(NSArray*)transformers logicOperator:(logic_transformer_operator_t)logicOperator NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;

@end
