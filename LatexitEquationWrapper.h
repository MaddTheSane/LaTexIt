//
//  LatexitEquationWrapper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/10/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010, 2011 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class LatexitEquation;

@interface LatexitEquationWrapper : NSManagedObject {
  LatexitEquation* equation;//seems needed on Tiger
}

-(LatexitEquation*) equation;
-(void) setEquation:(LatexitEquation*)value;

@end
