//
//  PreamblesTableView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 08/08/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

extern NSString* PreamblesPboardType;

@interface PreamblesTableView : NSTableView {
}

-(IBAction) edit:(id)sender;

@end
