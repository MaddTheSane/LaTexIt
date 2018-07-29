//
//  TextViewWithPlaceHolder.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/02/13.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TextViewWithPlaceHolder : NSTextView {
  NSString* placeHolder;
  NSAttributedString* attributedPlaceHolder;
}

@property (copy) NSString *placeHolder;

@end
