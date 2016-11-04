//
//  OutlineViewSelectedItemsTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2015 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OutlineViewSelectedItemsTransformer : NSValueTransformer {
  __strong NSOutlineView* outlineView;
}

+(NSString*) name;

+(instancetype) transformerWithOutlineView:(NSOutlineView*)outlineView;
-(instancetype) initWithOutlineView:(NSOutlineView*)outlineView;

@end
