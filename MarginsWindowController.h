//
//  MarginsWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/07/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MarginsWindowController : NSWindowController {
 IBOutlet NSTextField* topMarginButton;
 IBOutlet NSTextField* leftMarginButton;
 IBOutlet NSTextField* rightMarginButton;
 IBOutlet NSTextField* bottomMarginButton;
 IBOutlet NSButton*    saveAsDefaultButton;
}

-(CGFloat) topMargin;
-(CGFloat) leftMargin;
-(CGFloat) rightMargin;
-(CGFloat) bottomMargin;

-(IBAction) makeDefaultsMargins:(id)sender;
-(IBAction) showWindow:(id)sender;

@end
