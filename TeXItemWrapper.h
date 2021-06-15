//
//  TeXItemWrapper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 10/03/18.
//  Copyright 2005-2021 Pierre Chatelier. All rights reserved.
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

-(NSString*) title;
-(NSDictionary*) data;
-(BOOL) enabled;
-(void) setEnabled:(BOOL)value;
-(BOOL) checked;
-(void) setChecked:(BOOL)value;
-(NSInteger) importState;
-(void) setImportState:(NSInteger)value;
-(LatexitEquation*) equation;
-(void) setEquation:(LatexitEquation*)value;

@end

