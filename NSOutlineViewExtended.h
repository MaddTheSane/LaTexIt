//
//  NSOutlineViewExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/07/09.
//  Copyright 2005, 2006, 2007, 2008, 2009, 2010 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSOutlineView (Extended)

-(NSArray*) itemsAtRowIndexes:(NSIndexSet*)rowIndexes;
-(id)       selectedItem;
-(NSArray*) selectedItems;
-(void)     selectItem:(id)item byExtendingSelection:(BOOL)extend;
-(void)     selectItems:(NSArray*)item byExtendingSelection:(BOOL)extend;

@end
