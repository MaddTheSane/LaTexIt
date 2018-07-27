//
//  EncapsulationController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/07/05.
//  Copyright 2005 Pierre Chatelier. All rights reserved.

//this class is the "encapsulation palette", see encaspulationManager for more details

#import <Cocoa/Cocoa.h>

@interface EncapsulationController : NSWindowController {
}

+(EncapsulationController*) encapsulationController;
-(IBAction) openHelp:(id)sender;

@end
