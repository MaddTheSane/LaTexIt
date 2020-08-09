//
//  OutlineViewSelectedItemTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OutlineViewSelectedItemTransformer : NSValueTransformer {
  NSOutlineView* outlineView;
  BOOL firstIfMultiple;
}

@property (class, readonly, copy) NSString *name;

+(instancetype) transformerWithOutlineView:(NSOutlineView*)outlineView firstIfMultiple:(BOOL)firstIfMultiple;
-(instancetype) initWithOutlineView:(NSOutlineView*)outlineView firstIfMultiple:(BOOL)firstIfMultiple NS_DESIGNATED_INITIALIZER;
-(instancetype)init UNAVAILABLE_ATTRIBUTE;

@end
