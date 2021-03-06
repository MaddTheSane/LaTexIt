//
//  TextViewWithPlaceHolder.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 01/02/13.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface TextViewWithPlaceHolder : NSTextView {
  NSString* placeHolder;
  NSAttributedString* attributedPlaceHolder;
}

@property (nonatomic, copy) NSString *placeHolder;

@end
