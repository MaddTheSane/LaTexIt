//
//  PreamblesTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/08/08.
//  Copyright 2005, 2006, 2007, 2008, 2009 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* PreamblesPboardType;

@interface PreamblesTableView : NSTableView {
}

-(IBAction) edit:(id)sender;

@end
