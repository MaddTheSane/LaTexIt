//
//  DelegatingTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/07/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class DelegatingTransformer;
@protocol DelegatingTransformerDelegate
-(id) transformer:(DelegatingTransformer*)transformer reverse:(BOOL)reverse value:(id)value context:(id)context;
@end

@interface DelegatingTransformer : NSValueTransformer {
  BOOL allowsReverseTransformation;
  id<DelegatingTransformerDelegate> delegate;
  id context;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithDelegate:(id<DelegatingTransformerDelegate>)delegate context:(id)context;
-(instancetype) initWithDelegate:(id<DelegatingTransformerDelegate>)delegate context:(id)context NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;


@end
