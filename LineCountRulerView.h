//
//  LineCountRulerView.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 20/03/05.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LineCountRulerView : NSRulerView {
  NSInteger lineShift;
}

//the shift allows to start the numeratation at another number than 1
@property (nonatomic) NSInteger lineShift;

//we can add/remove error markers
-(void) clearErrors;
-(void) setErrorAtLine:(NSInteger)lineIndex message:(NSString*)message;

@end
