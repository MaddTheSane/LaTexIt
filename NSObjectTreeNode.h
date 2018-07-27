//
//  NSObjectTreeNode.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 03/04/09.
//  Copyright 2009 LAIC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSObject (NSTreeNode)

// There are better ways to compute this, but this implementation should be efficient for our app.
-(BOOL) isDescendantOfItemInArray:(NSArray*)items parentSelector:(SEL)parentSelector;
-(BOOL) isDescendantOfNode:(id)node strictly:(BOOL)strictly parentSelector:(SEL)parentSelector;
-(id)   nextBrotherWithParentSelector:(SEL)parentSelector childrenSelector:(SEL)childrenSelector rootNodes:(NSArray*)rootNodes;
-(id)   prevBrotherWithParentSelector:(SEL)parentSelector childrenSelector:(SEL)childrenSelector rootNodes:(NSArray*)rootNodes;
+(NSArray*) minimumNodeCoverFromItemsInArray:(NSArray*)allItems parentSelector:(SEL)parentSelector;

@end