//
//  MarginsWindowController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/07/05.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MarginsWindowController : NSWindowController {
 IBOutlet NSTextField* topMarginButton;
 IBOutlet NSTextField* leftMarginButton;
 IBOutlet NSTextField* rightMarginButton;
 IBOutlet NSTextField* bottomMarginButton;
 IBOutlet NSButton*    saveAsDefaultButton;
 IBOutlet NSNumberFormatter* pointSizeFormatter;
}

@property (readonly) CGFloat topMargin;
@property (readonly) CGFloat leftMargin;
@property (readonly) CGFloat rightMargin;
@property (readonly) CGFloat bottomMargin;

-(IBAction) makeDefaultsMargins:(id)sender;
-(IBAction) showWindow:(id)sender;

@end
