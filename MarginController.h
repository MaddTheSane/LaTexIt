//
//  MarginController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/07/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MarginController : NSWindowController {
 IBOutlet NSTextField* topMarginButton;
 IBOutlet NSTextField* leftMarginButton;
 IBOutlet NSTextField* rightMarginButton;
 IBOutlet NSTextField* bottomMarginButton;
}

+(void) updateWithUserDefaults;
-(void) updateWithUserDefaults;

+(float) topMargin;
+(float) leftMargin;
+(float) rightMargin;
+(float) bottomMargin;

@end
