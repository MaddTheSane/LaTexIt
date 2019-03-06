//
//  CompositionConfigurationsAdditionalScriptsController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 28/04/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface CompositionConfigurationsAdditionalScriptsController : NSArrayController {
}

@property (readonly, strong) id selection;//redefined to avoid proxy objects

@end
