//
//  LogicTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum {LOGIC_TRANSFORMER_OPERATOR_AND, LOGIC_TRANSFORMER_OPERATOR_OR} logic_transformer_operator_t;

@interface LogicTransformer : NSValueTransformer {
  NSArray* transformers;
  logic_transformer_operator_t logicOperator;
}
//end BoolTransformer

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithTransformers:(NSArray*)transformers logicOperator:(logic_transformer_operator_t)logicOperator;
-(instancetype) initWithTransformers:(NSArray*)transformers logicOperator:(logic_transformer_operator_t)logicOperator;

@end
