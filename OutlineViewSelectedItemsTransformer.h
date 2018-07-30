//
//  OutlineViewSelectedItemsTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OutlineViewSelectedItemsTransformer : NSValueTransformer {
  __strong NSOutlineView* outlineView;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithOutlineView:(NSOutlineView*)outlineView;
-(instancetype) initWithOutlineView:(NSOutlineView*)outlineView NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;
@end
