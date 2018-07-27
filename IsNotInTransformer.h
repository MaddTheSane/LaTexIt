//
//  IsNotInTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 27/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface IsNotInTransformer : NSValueTransformer {
  NSArray* references;
}

+(NSString*) name;

+(id) transformerWithReferences:(id)references;
-(id) initWithReferences:(id)references;

@end
