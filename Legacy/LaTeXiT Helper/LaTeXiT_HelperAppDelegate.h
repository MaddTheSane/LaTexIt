//
//  LaTeXiT_HelperAppDelegate.h
//  LaTeXiT Helper
//
//  Created by Pierre Chatelier on 25/11/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <LinkBack/LinkBack.h>

@interface LaTeXiT_HelperAppDelegate : NSObject <LinkBackServerDelegate> {
}

//LinkBackServerDelegateProtocol
-(void) linkBackDidClose:(LinkBack*)link;
-(void) linkBackClientDidRequestEdit:(LinkBack*)link;

@end
