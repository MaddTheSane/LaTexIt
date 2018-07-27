//
//  OutlineViewSelectedItemsTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OutlineViewSelectedItemsTransformer : NSValueTransformer {
  NSOutlineView* outlineView;
}

+(NSString*) name;

+(id) transformerWithOutlineView:(NSOutlineView*)outlineView;
-(id) initWithOutlineView:(NSOutlineView*)outlineView;

@end
