//
//  TextViewWithPlaceHolder.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/02/13.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TextViewWithPlaceHolder : NSTextView {
  NSString* placeHolder;
  NSAttributedString* attributedPlaceHolder;
}

-(NSString*) placeHolder;
-(void) setPlaceHolder:(NSString*)value;

@end
