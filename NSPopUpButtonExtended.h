//
//  NSPopUpButtonExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/05/10.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSPopUpButton (Extended)

-(id) addItemWithTitle:(NSString*)title tag:(int)tag;
-(NSMenuItem*) addItemWithTitle:(NSString*)aString target:(id)target action:(SEL)aSelector tag:(int)tag;

@end
