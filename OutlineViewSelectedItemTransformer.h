//
//  OutlineViewSelectedItemTransformer.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/06/15.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OutlineViewSelectedItemTransformer : NSValueTransformer {
  NSOutlineView* outlineView;
  BOOL firstIfMultiple;
}

+(NSString*) name;

+(id) transformerWithOutlineView:(NSOutlineView*)outlineView firstIfMultiple:(BOOL)firstIfMultiple;
-(id) initWithOutlineView:(NSOutlineView*)outlineView firstIfMultiple:(BOOL)firstIfMultiple;

@end
