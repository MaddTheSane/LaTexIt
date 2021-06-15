//
//  NSMenuExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 21/05/10.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSMenu (Extended)

-(NSMenuItem*) addItemWithTitle:(NSString*)aString target:(id)target action:(SEL)aSelector
                  keyEquivalent:(NSString*)keyEquivalent keyEquivalentModifierMask:(NSInteger)keyEquivalentModifierMask
                  tag:(NSInteger)tag;

@end
