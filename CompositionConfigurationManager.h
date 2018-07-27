//
//  CompositionConfigurationManager.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 23/03/06.
//  Copyright 2006 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* CompositionConfigurationPboardType;
extern NSString* CompositionConfigurationsDidChangeNotification;

@interface CompositionConfigurationManager : NSObject {
  NSMutableArray* configurations; //the different configurations
  NSIndexSet*     draggedRowIndexes; //very volatile, used for drag'n drop of compositionConfigurationTableView rows
  NSUndoManager*  undoManager;
}

+(CompositionConfigurationManager*) sharedManager;
-(NSUndoManager*)                   undoManager;

-(void) newCompositionConfiguration;
-(void) removeCompositionConfigurationIndexes:(NSIndexSet*)indexes;//remove selected ones


@end
