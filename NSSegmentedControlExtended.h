//
//  NSSegmentedControlExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 18/04/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSSegmentedControl (Extended)

-(int) selectedSegmentTag;
-(void) sizeToFitWithSegmentWidth:(CGFloat)segmentWidth useSameSize:(BOOL)useSameSize;

@end
