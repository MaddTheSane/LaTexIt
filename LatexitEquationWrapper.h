//
//  LatexitEquationWrapper.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/10/09.
//  Copyright 2005-2014 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class LatexitEquation;

@interface LatexitEquationWrapper : NSManagedObject {
  LatexitEquation* equation;//seems needed on Tiger
}

-(LatexitEquation*) equation;
-(void) setEquation:(LatexitEquation*)value;

@end
