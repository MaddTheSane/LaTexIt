//
//  HistoryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/09.
//  Copyright 2005-2019 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HistoryController : NSArrayController

-(instancetype) initWithContent:(id)content;

-(void) addObject:(id)object;

@end
