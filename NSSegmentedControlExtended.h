//
//  NSSegmentedControlExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 18/04/09.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSSegmentedControl (Extended)

-(NSInteger) selectedSegmentTag;
-(void) sizeToFitWithSegmentWidth:(CGFloat)segmentWidth useSameSize:(BOOL)useSameSize;

@end
