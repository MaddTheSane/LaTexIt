//
//  TooltipWindow.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 02/11/10.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface TooltipWindow : NSWindow
{
  id tooltipObject;
}
+(instancetype) tipWithString:(NSString*)tip frame:(NSRect)frame display:(BOOL)display;
+(instancetype) tipWithAttributedString:(NSAttributedString*)tip frame:(NSRect)frame display:(BOOL)display;

// returns the approximate window size needed to display the tooltip string.
+(NSSize) suggestedSizeForTooltip:(id)tooltip;

/// setting and getting the default duration.
@property (class) NSTimeInterval defaultDuration;

// setting and getting the default bgColor
@property (class, strong) NSColor *defaultBackgroundColor;

-(instancetype) init NS_DESIGNATED_INITIALIZER;

@property (nonatomic, copy) id tooltip;

-(void) orderFrontWithDuration:(NSTimeInterval)seconds;

@end
