//
//  AdditionalFilesControllerÒ.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 05/05/09.
//  Copyright 2005-2018 Pierre Chatelier. All rights reserved.
//

#import "AdditionalFilesController.h"


@implementation AdditionalFilesController

-(void) removeSelection:(id)sender
{
  NSArray* selectedObjects = [self selectedObjects];
  [self removeSelectedObjects:selectedObjects];
  NSMutableArray* newArrangedObjects = [NSMutableArray arrayWithArray:[self arrangedObjects]];
  [newArrangedObjects removeObjectsInArray:selectedObjects];
  [self setContent:newArrangedObjects];
}
//end removeSelection:

@end
