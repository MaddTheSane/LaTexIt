//
//  AdditionalFilesTableView.m
//  LaTeXiT
//
//  Created by Pierre Chatelier on 22/08/08.
//  Copyright 2008 LAIC. All rights reserved.
//

#import "AdditionalFilesTableView.h"

#import "AdditionalFilesController.h"

@implementation AdditionalFilesTableView

-(void) awakeFromNib
{
  [self setDelegate:self];
  [self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
}
//end awakeFromNib

-(void) tableView:(NSTableView*)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn*)aTableColumn row:(int)rowIndex
{
  NSString* filepath = [[(AdditionalFilesController*)[aTableView dataSource] filepaths] objectAtIndex:rowIndex];
  [aCell setImage:[[NSWorkspace sharedWorkspace] iconForFile:filepath]];
  BOOL ok = [[NSFileManager defaultManager] isReadableFileAtPath:filepath];
  if (!ok)
    [aCell setTextColor:[NSColor redColor]];
  else if ([aCell isHighlighted])
    [aCell setTextColor:[NSColor whiteColor]];
  else
    [aCell setTextColor:[NSColor blackColor]];
}
//end tableView:willDisplayCell:forTableColumn:row:

@end
