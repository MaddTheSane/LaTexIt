//
//  NSSegmentedControlExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 04/07/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.

//this file is an extension of the NSSegmentedControl class
//It is only useful to compile LaTeXiT for Panther

#import <Cocoa/Cocoa.h>

@interface NSSegmentedControl (Extended)

#ifdef PANTHER
-(BOOL) selectSegmentWithTag:(int)tag; //does exist in MacOS 10.4
#endif

@end
