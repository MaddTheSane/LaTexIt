//
//  MySplitView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 12/06/09.
//  Copyright 2005-2016 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MySplitView : NSSplitView {
  BOOL  isCustomThickness;
  CGFloat thickness;
}

@property CGFloat dividerThickness;

@end
