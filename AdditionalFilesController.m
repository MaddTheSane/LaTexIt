//
//  AdditionalFilesControllerÒ.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 05/05/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import "AdditionalFilesController.h"

#if !__has_feature(objc_arc)
#error this file needs to be compiled with Automatic Reference Counting (ARC)
#endif

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
