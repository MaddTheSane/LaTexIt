//
//  NSSegmentedControlExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 18/04/09.
//  Copyright 2005-2013 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSSegmentedControl (Extended)

-(int) selectedSegmentTag;
-(void) sizeToFitWithSegmentWidth:(CGFloat)segmentWidth useSameSize:(BOOL)useSameSize;

@end
