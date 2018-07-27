//
//  CompositionConfigurationTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface CompositionConfigurationTableView : NSTableView {
  NSMutableArray* cachedConfigurations;
}

-(IBAction) edit:(id)sender;

//sent through the first responder chain
-(IBAction) undo:(id)sender;
-(IBAction) redo:(id)sender;
-(BOOL) validateMenuItem:(NSMenuItem*)sender;

@end
