//
//  CompositionConfigurationController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 24/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CompositionConfigurationController : NSWindowController {
  IBOutlet NSPopUpButton* compositionConfigurationsPopUpButton;
}

-(IBAction) changeCompositionConfiguration:(id)sender;

@end
