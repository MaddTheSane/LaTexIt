//
//  NSOutlineViewExtended.h
//  LaTeXiT
//
//  Created by Pierre Chatelier on 29/07/09.
//  Copyright 2005-2020 Pierre Chatelier. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSOutlineView (Extended)

-(NSArray*) itemsAtRowIndexes:(NSIndexSet*)rowIndexes;
@property (readonly, strong) id selectedItem;
@property (readonly, copy) NSArray *selectedItems;
-(void)     selectItem:(id)item byExtendingSelection:(BOOL)extend;
-(void)     selectItems:(NSArray*)item byExtendingSelection:(BOOL)extend;

@end
