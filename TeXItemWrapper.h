//
//  TeXItemWrapper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/18.
//  Copyright 2005-2022 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LatexitEquation;

@interface TeXItemWrapper : NSObject
{
  NSDictionary* data;
  NSString* title;
  BOOL enabled;
  BOOL checked;
  NSInteger importState;//0 not imported, 1 importing, 2 imported, 3 error
  LatexitEquation* equation;
}

-(id) initWithItem:(NSDictionary*)aData;

@property (readonly, copy) NSString *title;
@property (readonly, retain) NSDictionary *data;
@property BOOL enabled;
@property BOOL checked;
@property NSInteger importState;
@property (retain) LatexitEquation *equation;

@end

