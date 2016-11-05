//
//  IsNotInTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsNotInTransformer : NSValueTransformer {
  NSArray* references;
}

+(NSString*) name;

+(instancetype) transformerWithReferences:(id)references;
-(instancetype) initWithReferences:(id)references;

@end
