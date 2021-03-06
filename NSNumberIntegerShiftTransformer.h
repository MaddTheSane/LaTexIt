//
//  NSNumberIntegerShiftTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/10/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSNumberIntegerShiftTransformer : NSValueTransformer {
  NSNumber* shift;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithShift:(NSNumber*)shift;
-(instancetype) initWithShift:(NSNumber*)shift NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;

@end
