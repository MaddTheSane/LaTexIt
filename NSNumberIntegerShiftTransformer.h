//
//  NSNumberIntegerShiftTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/10/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSNumberIntegerShiftTransformer : NSValueTransformer {
  NSNumber* shift;
}

+(NSString*) name;

+(id) transformerWithShift:(NSNumber*)shift;
-(id) initWithShift:(NSNumber*)shift;

@end
