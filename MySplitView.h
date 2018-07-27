//
//  MySplitView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 12/06/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MySplitView : NSSplitView {
  BOOL  isCustomThickness;
  CGFloat thickness;
}

-(CGFloat) dividerThickness;
-(void)    setDividerThickness:(CGFloat)value;

@end
