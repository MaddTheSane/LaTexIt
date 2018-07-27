//
//  HistoryController.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/05/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HistoryController : NSArrayController {

}

-(id) initWithContent:(id)content;

-(void) addObject:(id)object;

@end
