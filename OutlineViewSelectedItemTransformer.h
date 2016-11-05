//
//  OutlineViewSelectedItemTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2015 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OutlineViewSelectedItemTransformer : NSValueTransformer {
  NSOutlineView* outlineView;
  BOOL firstIfMultiple;
}

+(NSString*) name;

+(instancetype) transformerWithOutlineView:(NSOutlineView*)outlineView firstIfMultiple:(BOOL)firstIfMultiple;
-(instancetype) initWithOutlineView:(NSOutlineView*)outlineView firstIfMultiple:(BOOL)firstIfMultiple;

@end
