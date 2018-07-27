//
//  MarginController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/07/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MarginController : NSWindowController {
 IBOutlet NSTextField* topMarginButton;
 IBOutlet NSTextField* leftMarginButton;
 IBOutlet NSTextField* rightMarginButton;
 IBOutlet NSTextField* bottomMarginButton;
}

-(float) topMargin;
-(float) leftMargin;
-(float) rightMargin;
-(float) bottomMargin;

-(IBAction) makeDefaultsMargins:(id)sender;
-(IBAction) showWindow:(id)sender;

@end
