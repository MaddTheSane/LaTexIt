//
//  IsKindOfClassTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2015 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsKindOfClassTransformer : NSValueTransformer {
  Class theClass;
}

+(NSString*) name;

+(instancetype) transformerWithClass:(Class)aClass;
-(instancetype) initWithClass:(Class)aClass;

@end
