//
//  NSPopUpButtonExtended.h
//  LaTeXiT-panther
//
//  Created by Pierre Chatelier on 27/12/05.
//  Copyright 2005, 2006, 2007 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSPopUpButton (Extended)

#ifdef PANTHER
-(void) selectItemWithTag:(int)tag;
#endif

@end
