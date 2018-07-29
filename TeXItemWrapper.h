//
//  TeXItemWrapper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/18.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LatexitEquation;

typedef NS_ENUM(NSInteger, TeXItemWrapperState) {
  TeXItemWrapperStateNotImported = 0,
  TeXItemWrapperStateImporting = 1,
  TeXItemWrapperStateImported = 2,
  TeXItemWrapperStateError = 3
};

@interface TeXItemWrapper : NSObject
{
  NSDictionary* data;
  NSString* title;
  BOOL enabled;
  BOOL checked;
  TeXItemWrapperState importState;//0 not imported, 1 importing, 2 imported, 3 error
  LatexitEquation* equation;
}

-(instancetype)init UNAVAILABLE_ATTRIBUTE;
-(instancetype) initWithItem:(NSDictionary*)aData NS_DESIGNATED_INITIALIZER;

@property (readonly, copy) NSString *title;
@property (readonly, copy) NSDictionary *data;
@property  BOOL enabled;
@property  BOOL checked;
@property  TeXItemWrapperState importState;
@property (strong) LatexitEquation *equation;

@end

