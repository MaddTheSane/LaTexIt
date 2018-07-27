//
//  LineCountRulerView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/03/05.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LineCountRulerView : NSRulerView {
  int lineShift;
}

//the shift allows to start the numeratation at another number than 1
-(int)  lineShift;
-(void) setLineShift:(int)aShift;

//we can add/remove error markers
-(void) clearErrors;
-(void) setErrorAtLine:(int)lineIndex message:(NSString*)message;

@end
